from __future__ import annotations

import importlib.util
import json
import sys
import threading
from copy import deepcopy
from datetime import date, datetime
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

import pytest

SCRIPT = Path(__file__).parents[1] / "assets/training_reminder_dispatcher.py"
SPEC = importlib.util.spec_from_file_location("training_reminder_dispatcher", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
dispatcher = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(dispatcher)
sys.modules["training_reminder_dispatcher"] = dispatcher
CHECKIN_SCRIPT = Path(__file__).parents[1] / "assets/send_migration_checkin.py"
CHECKIN_SPEC = importlib.util.spec_from_file_location(
    "send_migration_checkin", CHECKIN_SCRIPT
)
assert CHECKIN_SPEC is not None and CHECKIN_SPEC.loader is not None
checkin = importlib.util.module_from_spec(CHECKIN_SPEC)
CHECKIN_SPEC.loader.exec_module(checkin)
PACIFIC = ZoneInfo("America/Los_Angeles")


def at(day: int, hour: int = 5) -> datetime:
    return datetime(2026, 9, day, hour, tzinfo=PACIFIC)


def scheduled(tmp_path: Path, *, day: int = 10) -> Any:
    store = dispatcher.StateStore(tmp_path / "state.json")
    dispatcher.schedule(
        store,
        planned_date=date(2026, 9, day),
        lift="deadlift",
        subject="Deadlift Training Day",
        prescription="Deadlift prescription",
        plan_id="plan-1",
        now=at(1),
    )
    return store


def test_future_plan_stays_silent(tmp_path: Path) -> None:
    store = scheduled(tmp_path)
    sent: list[dict[str, str]] = []

    state, acted = dispatcher.reconcile(
        store,
        lambda payload: sent.append(payload) or "out-1",
        recipient="user@example.com",
        now=at(9),
    )

    assert not acted
    assert sent == []
    assert state["phase"] == "planned"


def test_due_plan_sends_once_and_awaits_completion(tmp_path: Path) -> None:
    store = scheduled(tmp_path)
    sent: list[dict[str, str]] = []

    def sender(payload: dict[str, str]) -> str:
        sent.append(payload)
        return "out-1"

    first, first_acted = dispatcher.reconcile(
        store, sender, recipient="user@example.com", now=at(10)
    )
    second, second_acted = dispatcher.reconcile(
        store, sender, recipient="user@example.com", now=at(10, 6)
    )

    assert first_acted
    assert not second_acted
    assert len(sent) == 1
    assert sent[0]["body"] == "Deadlift prescription"
    assert sent[0]["idempotency_key"] == "training:prescription:plan-1:2"
    assert first["phase"] == second["phase"] == "awaiting_completion"
    assert first["bridge_outbound_id"] == "out-1"


def test_missed_plan_sends_one_checkin_then_waits(tmp_path: Path) -> None:
    store = scheduled(tmp_path, day=10)
    sent: list[dict[str, str]] = []

    def sender(payload: dict[str, str]) -> str:
        sent.append(payload)
        return "out-checkin"

    first, _ = dispatcher.reconcile(
        store, sender, recipient="user@example.com", now=at(11)
    )
    second, acted = dispatcher.reconcile(
        store, sender, recipient="user@example.com", now=at(20)
    )

    assert len(sent) == 1
    assert sent[0]["idempotency_key"] == "training:checkin:plan-1:2"
    assert first["phase"] == second["phase"] == "awaiting_reply"
    assert not acted


def test_following_morning_checks_in_after_delivered_workout(tmp_path: Path) -> None:
    store = scheduled(tmp_path)
    dispatcher.reconcile(
        store, lambda _: "out-1", recipient="user@example.com", now=at(10)
    )
    sent: list[dict[str, str]] = []

    state, acted = dispatcher.reconcile(
        store,
        lambda payload: sent.append(payload) or "out-2",
        recipient="user@example.com",
        now=at(11),
    )

    assert acted
    assert state["phase"] == "awaiting_reply"
    assert sent[0]["idempotency_key"] == "training:checkin:plan-1:4"


def test_outbox_survives_failure_and_retries_same_key(tmp_path: Path) -> None:
    store = scheduled(tmp_path)
    attempted: list[str] = []

    def fail(payload: dict[str, str]) -> str:
        attempted.append(payload["idempotency_key"])
        raise RuntimeError("bridge unavailable")

    with pytest.raises(RuntimeError, match="bridge unavailable"):
        dispatcher.reconcile(store, fail, recipient="user@example.com", now=at(10))

    pending = store.load()
    assert pending["phase"] == "outbound_pending"
    state, acted = dispatcher.reconcile(
        store,
        lambda payload: (
            attempted.append(payload["idempotency_key"]) or "same-outbound-id"
        ),
        recipient="user@example.com",
        now=at(10, 6),
    )

    assert acted
    assert attempted == [
        "training:prescription:plan-1:2",
        "training:prescription:plan-1:2",
    ]
    assert state["bridge_outbound_id"] == "same-outbound-id"


def test_reschedule_increments_revision_and_invalidates_pending(tmp_path: Path) -> None:
    store = scheduled(tmp_path)
    with pytest.raises(RuntimeError):
        dispatcher.reconcile(
            store,
            lambda _: (_ for _ in ()).throw(RuntimeError("offline")),
            recipient="user@example.com",
            now=at(10),
        )
    pending_revision = store.load()["revision"]

    state = dispatcher.schedule(
        store,
        planned_date=date(2026, 9, 14),
        lift="bench",
        subject="Bench Training Day",
        prescription="Bench prescription",
        expected_revision=pending_revision,
        plan_id="plan-2",
        now=at(10, 7),
    )

    assert state["revision"] == pending_revision + 1
    assert state["phase"] == "planned"
    assert state["pending_idempotency_key"] is None


def test_revision_conflict_is_atomic(tmp_path: Path) -> None:
    store = scheduled(tmp_path)
    before = store.load()

    with pytest.raises(dispatcher.RevisionConflict):
        dispatcher.pause(store, reason="stale update", expected_revision=0, now=at(2))

    assert store.load() == before


def test_replayed_source_does_not_advance_plan(tmp_path: Path) -> None:
    store = dispatcher.StateStore(tmp_path / "state.json")
    first = dispatcher.schedule(
        store,
        planned_date=date(2026, 9, 10),
        lift="deadlift",
        subject="Deadlift Training Day",
        prescription="Deadlift prescription",
        expected_revision=0,
        plan_id="plan-1",
        source_id="inbound-1",
        now=at(1),
    )

    replay = dispatcher.schedule(
        store,
        planned_date=date(2026, 9, 12),
        lift="bench",
        subject="Wrong replay plan",
        prescription="Wrong replay prescription",
        expected_revision=first["revision"],
        plan_id="plan-2",
        source_id="inbound-1",
        now=at(2),
    )

    assert replay == first
    assert store.load() == first


def test_pause_is_idempotent_and_stays_silent(tmp_path: Path) -> None:
    store = scheduled(tmp_path)
    paused = dispatcher.pause(
        store,
        reason="Waiting for a safe date",
        expected_revision=1,
        source_id="inbound-pause",
        now=at(2),
    )
    replayed = dispatcher.pause(
        store,
        reason="Different replay reason",
        expected_revision=paused["revision"],
        source_id="inbound-pause",
        now=at(3),
    )
    sent: list[dict[str, str]] = []
    reconciled, acted = dispatcher.reconcile(
        store,
        lambda payload: sent.append(payload) or "out-1",
        recipient="user@example.com",
        now=at(20),
    )

    assert replayed == paused == reconciled
    assert not acted
    assert sent == []


def test_malformed_state_fails_closed_without_sending(tmp_path: Path) -> None:
    path = tmp_path / "state.json"
    path.write_text('{"schema_version": 1, "revision": "bad"}\n')
    store = dispatcher.StateStore(path)
    sent: list[dict[str, str]] = []

    with pytest.raises(dispatcher.StateError):
        dispatcher.reconcile(
            store,
            lambda payload: sent.append(payload) or "out-1",
            recipient="user@example.com",
            now=at(10),
        )

    assert sent == []
    assert json.loads(path.read_text())["revision"] == "bad"


def test_semantically_malformed_state_is_rejected(tmp_path: Path) -> None:
    valid = scheduled(tmp_path).load()
    corruptions = []
    for field, value in (
        ("schema_version", True),
        ("revision", True),
        ("rotation_position", 1),
        ("checkin_body", {"unsafe": "body"}),
    ):
        corrupted = deepcopy(valid)
        corrupted[field] = value
        corruptions.append(corrupted)
    pending = deepcopy(valid)
    pending.update(
        {
            "revision": 2,
            "phase": "outbound_pending",
            "pending_email_body": "Deadlift prescription",
            "pending_idempotency_key": "training:checkin:wrong:2",
            "intended_next_phase": "awaiting_completion",
        }
    )
    corruptions.append(pending)

    for corrupted in corruptions:
        with pytest.raises(dispatcher.StateError):
            dispatcher.validate_state(corrupted)


def test_concurrent_update_is_not_overwritten_by_reconcile(tmp_path: Path) -> None:
    store = scheduled(tmp_path)
    submitting = threading.Event()
    release = threading.Event()

    def sender(_: dict[str, str]) -> str:
        submitting.set()
        assert release.wait(timeout=5)
        return "old-outbound"

    thread = threading.Thread(
        target=dispatcher.reconcile,
        args=(store, sender),
        kwargs={"recipient": "user@example.com", "now": at(10)},
    )
    thread.start()
    assert submitting.wait(timeout=5)
    pending_revision = store.load()["revision"]
    dispatcher.schedule(
        store,
        planned_date=date(2026, 9, 15),
        lift="bench",
        subject="Bench Training Day",
        prescription="New prescription",
        expected_revision=pending_revision,
        plan_id="plan-2",
        now=at(10, 6),
    )
    release.set()
    thread.join(timeout=5)

    state = store.load()
    assert not thread.is_alive()
    assert state["active_plan_id"] == "plan-2"
    assert state["phase"] == "planned"
    assert state["bridge_outbound_id"] is None


def test_concurrent_reconcile_submits_the_same_outbox_key(tmp_path: Path) -> None:
    store = scheduled(tmp_path)
    senders_ready = threading.Barrier(2)
    keys: list[str] = []

    def sender(payload: dict[str, str]) -> str:
        keys.append(payload["idempotency_key"])
        senders_ready.wait(timeout=5)
        return "same-outbound"

    threads = [
        threading.Thread(
            target=dispatcher.reconcile,
            args=(store, sender),
            kwargs={"recipient": "user@example.com", "now": at(10)},
        )
        for _ in range(2)
    ]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=5)

    assert all(not thread.is_alive() for thread in threads)
    assert keys == ["training:prescription:plan-1:2"] * 2
    assert store.load()["phase"] == "awaiting_completion"


def test_delivered_on_demand_records_awaiting_completion(tmp_path: Path) -> None:
    store = dispatcher.StateStore(tmp_path / "state.json")

    state = dispatcher.schedule(
        store,
        planned_date=date(2026, 9, 10),
        lift="squat",
        subject="Squat Training Day",
        prescription="Immediate squat session",
        delivered=True,
        now=at(10),
    )

    assert state["phase"] == "awaiting_completion"


def test_due_plan_waits_until_five(tmp_path: Path) -> None:
    store = scheduled(tmp_path)
    sent: list[dict[str, str]] = []

    state, acted = dispatcher.reconcile(
        store,
        lambda payload: sent.append(payload) or "out-1",
        recipient="user@example.com",
        now=at(10, 4),
    )

    assert not acted
    assert state["phase"] == "planned"
    assert sent == []


def test_default_state_path_uses_hermes_home(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("HERMES_HOME", "/opt/data")

    assert dispatcher.default_state_path() == Path(
        "/opt/data/data/training_reminder_state.json"
    )


def test_migration_checkin_remains_one_time_after_state_advances(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    state_path = tmp_path / "training_reminder_state.json"
    sent: list[dict[str, str]] = []
    monkeypatch.setattr(checkin, "default_state_path", lambda: state_path)
    monkeypatch.setattr(
        checkin,
        "bridge_sender",
        lambda: (lambda payload: sent.append(payload) or "out-1", "user@example.com"),
    )

    checkin.main(at(1, 4))
    marker = tmp_path / "cloud_migration_checkin_sent"
    assert marker.read_text() == "cloud-migration-v1\n"
    assert marker.stat().st_mode & 0o777 == 0o600
    assert len(sent) == 1

    marker.unlink()
    checkin.main(at(1, 4))
    assert marker.exists()
    assert len(sent) == 1

    state = dispatcher.StateStore(state_path).load()
    dispatcher.schedule(
        dispatcher.StateStore(state_path),
        planned_date=date(2026, 9, 20),
        lift="bench",
        subject="Bench Training Day",
        prescription="Bench prescription",
        expected_revision=state["revision"],
        plan_id="next-plan",
        now=at(12),
    )
    checkin.main(at(12, 4))

    assert len(sent) == 1
