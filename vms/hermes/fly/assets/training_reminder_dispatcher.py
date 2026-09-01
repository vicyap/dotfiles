#!/usr/bin/env python3
"""Durable adaptive training schedule and bridge outbox."""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import uuid
from contextlib import contextmanager
from datetime import date, datetime
from pathlib import Path
from typing import TYPE_CHECKING, Any
from zoneinfo import ZoneInfo

if TYPE_CHECKING:
    from collections.abc import Callable, Iterator

SCHEMA_VERSION = 2
PACIFIC = ZoneInfo("America/Los_Angeles")
ROTATION = ["deadlift", "bench", "squat"]
PHASES = {
    "planned",
    "outbound_pending",
    "awaiting_completion",
    "awaiting_reply",
    "paused",
}
SECRET_NAMES = ("BRIDGE_URL", "BRIDGE_API_TOKEN", "EMAIL_HOME_ADDRESS")


class StateError(RuntimeError):
    """The durable schedule state is missing or invalid."""


class RevisionConflict(StateError):
    """The caller tried to update a stale state revision."""


def default_state_path() -> Path:
    return (
        Path(os.environ.get("HERMES_HOME", "/opt/data"))
        / "data/training_reminder_state.json"
    )


def _empty_state() -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "revision": 0,
        "active_program_id": "deadlift-bench-squat",
        "active_plan_id": None,
        "rotation": ROTATION,
        "rotation_position": 0,
        "planned_date": None,
        "lift": None,
        "subject": None,
        "prepared_prescription": None,
        "checkin_body": None,
        "phase": "paused",
        "pending_email_body": None,
        "pending_idempotency_key": None,
        "intended_next_phase": None,
        "bridge_outbound_id": None,
        "last_action_source_id": None,
        "pause_reason": "No workout scheduled",
        "updated_at": None,
    }


def _parse_date(value: Any, field: str) -> date:
    if not isinstance(value, str):
        raise StateError(f"{field} must be an ISO date")
    try:
        return date.fromisoformat(value)
    except ValueError as error:
        raise StateError(f"{field} must be an ISO date") from error


def validate_state(state: Any) -> dict[str, Any]:
    if not isinstance(state, dict):
        raise StateError("training state must be a JSON object")
    required = set(_empty_state())
    missing = required - state.keys()
    if missing:
        raise StateError(
            f"training state is missing fields: {', '.join(sorted(missing))}"
        )
    if (
        type(state["schema_version"]) is not int
        or state["schema_version"] != SCHEMA_VERSION
    ):
        raise StateError(
            f"unsupported training state schema: {state['schema_version']!r}"
        )
    if type(state["revision"]) is not int or state["revision"] < 0:
        raise StateError("revision must be a non-negative integer")
    if state["phase"] not in PHASES:
        raise StateError(f"invalid training phase: {state['phase']!r}")
    if state["rotation"] != ROTATION:
        raise StateError("unsupported training rotation")
    if type(state["rotation_position"]) is not int or state[
        "rotation_position"
    ] not in range(len(ROTATION)):
        raise StateError("rotation_position is out of range")

    optional_strings = (
        "active_plan_id",
        "planned_date",
        "lift",
        "subject",
        "prepared_prescription",
        "checkin_body",
        "pending_email_body",
        "pending_idempotency_key",
        "intended_next_phase",
        "bridge_outbound_id",
        "last_action_source_id",
        "pause_reason",
        "updated_at",
    )
    for field in optional_strings:
        value = state[field]
        if value is not None and (not isinstance(value, str) or not value.strip()):
            raise StateError(f"{field} must be a non-empty string or null")
    if (
        not isinstance(state["active_program_id"], str)
        or not state["active_program_id"].strip()
    ):
        raise StateError("active_program_id must be a non-empty string")
    if state["planned_date"] is not None:
        _parse_date(state["planned_date"], "planned_date")
    if state["lift"] is not None:
        if state["lift"] not in ROTATION:
            raise StateError(f"unsupported lift: {state['lift']!r}")
        if state["rotation_position"] != ROTATION.index(state["lift"]):
            raise StateError("lift does not match rotation_position")
    if state["updated_at"] is not None:
        try:
            datetime.fromisoformat(state["updated_at"])
        except ValueError as error:
            raise StateError("updated_at must be an ISO datetime") from error

    phase = state["phase"]
    if phase != "paused":
        for field in ("active_plan_id", "planned_date", "lift", "subject"):
            if not isinstance(state[field], str) or not state[field].strip():
                raise StateError(f"{field} is required while {phase}")
    if phase in {"planned", "awaiting_completion"} and not isinstance(
        state["prepared_prescription"], str
    ):
        raise StateError(f"prepared_prescription is required while {phase}")
    if phase == "outbound_pending":
        for field in (
            "pending_email_body",
            "pending_idempotency_key",
            "intended_next_phase",
        ):
            if not isinstance(state[field], str) or not state[field]:
                raise StateError(f"{field} is required while outbound_pending")
        if state["intended_next_phase"] not in {
            "awaiting_completion",
            "awaiting_reply",
        }:
            raise StateError("invalid intended_next_phase")
        kind = (
            "prescription"
            if state["intended_next_phase"] == "awaiting_completion"
            else "checkin"
        )
        expected_key = f"training:{kind}:{state['active_plan_id']}:{state['revision']}"
        if state["pending_idempotency_key"] != expected_key:
            raise StateError("pending_idempotency_key does not match pending action")
        if state["bridge_outbound_id"] is not None:
            raise StateError("bridge_outbound_id must be null while outbound_pending")
    elif any(
        state[field] is not None
        for field in (
            "pending_email_body",
            "pending_idempotency_key",
            "intended_next_phase",
        )
    ):
        raise StateError("pending outbox fields require outbound_pending phase")
    if phase == "paused" and state["pause_reason"] is None:
        raise StateError("pause_reason is required while paused")
    return state


class StateStore:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.lock_path = path.with_suffix(path.suffix + ".lock")

    @contextmanager
    def locked(self) -> Iterator[dict[str, Any]]:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.lock_path.open("a+") as lock_file:
            fcntl.flock(lock_file, fcntl.LOCK_EX)
            state = self.load()
            yield state

    def load(self) -> dict[str, Any]:
        if not self.path.exists():
            return _empty_state()
        try:
            state = json.loads(self.path.read_text())
        except (OSError, json.JSONDecodeError) as error:
            raise StateError(f"unable to read training state: {error}") from error
        return validate_state(state)

    def write(self, state: dict[str, Any]) -> None:
        validate_state(state)
        payload = json.dumps(state, indent=2, sort_keys=True) + "\n"
        descriptor, temporary_name = tempfile.mkstemp(
            dir=self.path.parent,
            prefix=f".{self.path.name}.",
        )
        try:
            with os.fdopen(descriptor, "w") as temporary_file:
                temporary_file.write(payload)
                temporary_file.flush()
                os.fsync(temporary_file.fileno())
            os.chmod(temporary_name, 0o600)
            os.replace(temporary_name, self.path)
            directory_descriptor = os.open(self.path.parent, os.O_DIRECTORY)
            try:
                os.fsync(directory_descriptor)
            finally:
                os.close(directory_descriptor)
        finally:
            if os.path.exists(temporary_name):
                os.unlink(temporary_name)


def _check_revision(state: dict[str, Any], expected_revision: int | None) -> None:
    if expected_revision is not None and state["revision"] != expected_revision:
        raise RevisionConflict(
            f"revision conflict: expected {expected_revision}, found {state['revision']}"
        )


def _updated(state: dict[str, Any], now: datetime) -> dict[str, Any]:
    state["revision"] += 1
    state["updated_at"] = now.isoformat()
    return state


def schedule(
    store: StateStore,
    *,
    planned_date: date,
    lift: str,
    subject: str,
    prescription: str,
    checkin_body: str | None = None,
    expected_revision: int | None = None,
    program_id: str = "deadlift-bench-squat",
    plan_id: str | None = None,
    source_id: str | None = None,
    delivered: bool = False,
    now: datetime | None = None,
) -> dict[str, Any]:
    if lift not in ROTATION:
        raise StateError(f"unsupported lift: {lift!r}")
    if not subject.strip() or not prescription.strip():
        raise StateError("subject and prescription cannot be empty")
    if source_id is not None and not source_id.strip():
        raise StateError("source_id cannot be empty")
    current_time = now or datetime.now(PACIFIC)
    with store.locked() as state:
        if source_id is not None and state["last_action_source_id"] == source_id:
            return state.copy()
        _check_revision(state, expected_revision)
        state.update(
            {
                "active_program_id": program_id,
                "active_plan_id": plan_id or uuid.uuid4().hex,
                "rotation_position": ROTATION.index(lift),
                "planned_date": planned_date.isoformat(),
                "lift": lift,
                "subject": subject.strip(),
                "prepared_prescription": prescription.strip(),
                "checkin_body": checkin_body.strip() if checkin_body else None,
                "phase": "awaiting_completion" if delivered else "planned",
                "pending_email_body": None,
                "pending_idempotency_key": None,
                "intended_next_phase": None,
                "bridge_outbound_id": None,
                "last_action_source_id": source_id,
                "pause_reason": None,
            }
        )
        store.write(_updated(state, current_time))
        return state.copy()


def pause(
    store: StateStore,
    *,
    reason: str,
    expected_revision: int | None = None,
    source_id: str | None = None,
    now: datetime | None = None,
) -> dict[str, Any]:
    if source_id is not None and not source_id.strip():
        raise StateError("source_id cannot be empty")
    current_time = now or datetime.now(PACIFIC)
    with store.locked() as state:
        if source_id is not None and state["last_action_source_id"] == source_id:
            return state.copy()
        _check_revision(state, expected_revision)
        state.update(
            {
                "phase": "paused",
                "pending_email_body": None,
                "pending_idempotency_key": None,
                "intended_next_phase": None,
                "bridge_outbound_id": None,
                "last_action_source_id": source_id,
                "pause_reason": reason.strip() or "Paused",
            }
        )
        store.write(_updated(state, current_time))
        return state.copy()


def _checkin_body(state: dict[str, Any]) -> str:
    if state["checkin_body"]:
        return str(state["checkin_body"])
    lift = str(state["lift"]).capitalize()
    return (
        f"I had {lift} planned for {state['planned_date']} and haven't seen a completion "
        "report yet. How did training go, or what got in the way? Reply with whatever "
        "happened and we'll adjust the next date and session."
    )


def _stage_action(
    state: dict[str, Any], now: datetime, *, allow_before_5: bool = False
) -> bool:
    if state["phase"] in {"paused", "awaiting_reply", "outbound_pending"}:
        return False
    local_now = now.astimezone(PACIFIC)
    if local_now.hour < 5 and not allow_before_5:
        return False
    planned = _parse_date(state["planned_date"], "planned_date")
    if planned > local_now.date():
        return False
    if state["phase"] == "awaiting_completion" and planned == local_now.date():
        return False

    if state["phase"] == "planned" and planned == local_now.date():
        body = str(state["prepared_prescription"])
        intended_phase = "awaiting_completion"
        kind = "prescription"
    else:
        body = _checkin_body(state)
        intended_phase = "awaiting_reply"
        kind = "checkin"

    next_revision = state["revision"] + 1
    state.update(
        {
            "revision": next_revision,
            "phase": "outbound_pending",
            "pending_email_body": body,
            "pending_idempotency_key": (
                f"training:{kind}:{state['active_plan_id']}:{next_revision}"
            ),
            "intended_next_phase": intended_phase,
            "bridge_outbound_id": None,
            "updated_at": local_now.isoformat(),
        }
    )
    return True


def reconcile(
    store: StateStore,
    sender: Callable[[dict[str, str]], str],
    *,
    recipient: str,
    now: datetime | None = None,
    allow_before_5: bool = False,
) -> tuple[dict[str, Any], bool]:
    current_time = now or datetime.now(PACIFIC)
    with store.locked() as state:
        staged = _stage_action(state, current_time, allow_before_5=allow_before_5)
        if staged:
            store.write(state)
        if state["phase"] != "outbound_pending":
            return state.copy(), False
        pending_key = str(state["pending_idempotency_key"])
        pending_revision = int(state["revision"])
        payload = {
            "recipient": recipient,
            "idempotency_key": pending_key,
            "subject": str(state["subject"]),
            "body": str(state["pending_email_body"]),
        }

    outbound_id = sender(payload)

    with store.locked() as state:
        if (
            state["phase"] != "outbound_pending"
            or state["revision"] != pending_revision
            or state["pending_idempotency_key"] != pending_key
        ):
            return state.copy(), True
        state.update(
            {
                "phase": state["intended_next_phase"],
                "pending_email_body": None,
                "pending_idempotency_key": None,
                "intended_next_phase": None,
                "bridge_outbound_id": outbound_id,
            }
        )
        store.write(_updated(state, current_time))
        return state.copy(), True


def _load_script_env() -> dict[str, str]:
    values = {name: os.environ.get(name, "").strip() for name in SECRET_NAMES}
    env_path = Path(os.environ.get("HERMES_HOME", "/opt/data")) / ".env"
    if env_path.exists():
        for raw_line in env_path.read_text().splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, raw_value = line.split("=", 1)
            if key not in values or values[key]:
                continue
            value = raw_value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
                value = value[1:-1]
            values[key] = value
    missing = [name for name, value in values.items() if not value]
    if missing:
        raise StateError(f"missing script environment: {', '.join(missing)}")
    return values


def bridge_sender() -> tuple[Callable[[dict[str, str]], str], str]:
    values = _load_script_env()
    bridge_url = values["BRIDGE_URL"].rstrip("/")
    if urllib.parse.urlparse(bridge_url).scheme != "https":
        raise StateError("BRIDGE_URL must use HTTPS")

    def send(payload: dict[str, str]) -> str:
        request = urllib.request.Request(
            f"{bridge_url}/v1/outbound",
            data=json.dumps(payload).encode(),
            headers={
                "Authorization": f"Bearer {values['BRIDGE_API_TOKEN']}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=40) as response:
                result = json.load(response)
        except (OSError, urllib.error.HTTPError, json.JSONDecodeError) as error:
            raise StateError(f"bridge submission failed: {error}") from error
        outbound_id = result.get("outbound_id") if isinstance(result, dict) else None
        if not isinstance(outbound_id, str) or not outbound_id:
            raise StateError("bridge response did not contain an outbound_id")
        return outbound_id

    return send, values["EMAIL_HOME_ADDRESS"]


def _read_body(path: str) -> str:
    return sys.stdin.read() if path == "-" else Path(path).read_text()


def _parse_now(value: str | None) -> datetime | None:
    if value is None:
        return None
    parsed = datetime.fromisoformat(value)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=PACIFIC)
    return parsed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", type=Path, default=None)
    commands = parser.add_subparsers(dest="command", required=True)

    commands.add_parser("show")

    schedule_parser = commands.add_parser("schedule")
    schedule_parser.add_argument("--date", required=True, type=date.fromisoformat)
    schedule_parser.add_argument("--lift", required=True, choices=ROTATION)
    schedule_parser.add_argument("--subject", required=True)
    schedule_parser.add_argument("--prescription-file", required=True)
    schedule_parser.add_argument("--checkin-body-file")
    schedule_parser.add_argument("--expected-revision", type=int)
    schedule_parser.add_argument("--program-id", default="deadlift-bench-squat")
    schedule_parser.add_argument("--plan-id")
    schedule_parser.add_argument("--source-id")
    schedule_parser.add_argument("--delivered", action="store_true")
    schedule_parser.add_argument("--now")

    pause_parser = commands.add_parser("pause")
    pause_parser.add_argument("--reason", required=True)
    pause_parser.add_argument("--expected-revision", type=int)
    pause_parser.add_argument("--source-id")
    pause_parser.add_argument("--now")

    reconcile_parser = commands.add_parser("reconcile")
    reconcile_parser.add_argument("--now")
    reconcile_parser.add_argument("--quiet", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    store = StateStore(args.state or default_state_path())
    if args.command == "show":
        with store.locked() as state:
            print(json.dumps(state, indent=2, sort_keys=True))
        return 0
    if args.command == "schedule":
        state = schedule(
            store,
            planned_date=args.date,
            lift=args.lift,
            subject=args.subject,
            prescription=_read_body(args.prescription_file),
            checkin_body=(
                _read_body(args.checkin_body_file) if args.checkin_body_file else None
            ),
            expected_revision=args.expected_revision,
            program_id=args.program_id,
            plan_id=args.plan_id,
            source_id=args.source_id,
            delivered=args.delivered,
            now=_parse_now(args.now),
        )
        print(json.dumps(state, indent=2, sort_keys=True))
        return 0
    if args.command == "pause":
        state = pause(
            store,
            reason=args.reason,
            expected_revision=args.expected_revision,
            source_id=args.source_id,
            now=_parse_now(args.now),
        )
        print(json.dumps(state, indent=2, sort_keys=True))
        return 0

    sender, recipient = bridge_sender()
    state, acted = reconcile(
        store, sender, recipient=recipient, now=_parse_now(args.now)
    )
    if acted and not args.quiet:
        print(json.dumps(state, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, StateError, ValueError) as error:
        print(f"training reminder error: {error}", file=sys.stderr)
        raise SystemExit(1) from error
