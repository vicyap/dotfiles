#!/usr/bin/env python3
"""Queue the one-time cloud migration coaching check-in."""

from __future__ import annotations

import os
import tempfile
from datetime import datetime, timedelta
from pathlib import Path

from training_reminder_dispatcher import (
    PACIFIC,
    StateStore,
    bridge_sender,
    default_state_path,
    reconcile,
    schedule,
)

PLAN_ID = "cloud-migration-v1"
BODY = (
    "Cloud migration is complete. Where does training currently stand? Reply with your most "
    "recent workout, anything missed, current recovery or pain, and the next days that work. "
    "I'll use that to propose the next date and prepare the next session."
)


def _marker_path() -> Path:
    return default_state_path().with_name("cloud_migration_checkin_sent")


def _mark_sent() -> None:
    path = _marker_path()
    descriptor, temporary_name = tempfile.mkstemp(
        dir=path.parent, prefix=f".{path.name}."
    )
    try:
        with os.fdopen(descriptor, "w") as marker:
            marker.write(f"{PLAN_ID}\n")
            marker.flush()
            os.fsync(marker.fileno())
        os.chmod(temporary_name, 0o600)
        os.replace(temporary_name, path)
        directory_descriptor = os.open(path.parent, os.O_DIRECTORY)
        try:
            os.fsync(directory_descriptor)
        finally:
            os.close(directory_descriptor)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


def main(now: datetime | None = None) -> None:
    marker = _marker_path()
    if marker.exists():
        if marker.read_text() != f"{PLAN_ID}\n":
            raise RuntimeError(f"invalid migration marker: {marker}")
        return
    now = now or datetime.now(PACIFIC)
    store = StateStore(default_state_path())
    with store.locked() as state:
        revision = state["revision"]
        if state["active_plan_id"] == PLAN_ID and state["phase"] == "awaiting_reply":
            _mark_sent()
            return
        is_pending = state["active_plan_id"] == PLAN_ID and state["phase"] in {
            "planned",
            "outbound_pending",
        }
    if not is_pending:
        schedule(
            store,
            planned_date=(now - timedelta(days=1)).date(),
            lift="deadlift",
            subject="Training check-in",
            prescription="Migration check-in only; prepare the next workout after the reply.",
            checkin_body=BODY,
            expected_revision=revision,
            plan_id=PLAN_ID,
            now=now,
        )
    sender, recipient = bridge_sender()
    state, acted = reconcile(
        store, sender, recipient=recipient, now=now, allow_before_5=True
    )
    if acted or (
        state["active_plan_id"] == PLAN_ID and state["phase"] == "awaiting_reply"
    ):
        _mark_sent()


if __name__ == "__main__":
    main()
