from __future__ import annotations

import csv
import importlib.util
import json
import sqlite3
import zipfile
from pathlib import Path

import pytest

SCRIPT = Path(__file__).parents[1] / "assets/backup_to_tigris.py"
SPEC = importlib.util.spec_from_file_location("backup_to_tigris", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
backup = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(backup)

BOOTSTRAP_SCRIPT = Path(__file__).parents[1] / "assets/bootstrap_pilot.py"
BOOTSTRAP_SPEC = importlib.util.spec_from_file_location(
    "bootstrap_pilot", BOOTSTRAP_SCRIPT
)
assert BOOTSTRAP_SPEC is not None and BOOTSTRAP_SPEC.loader is not None
bootstrap = importlib.util.module_from_spec(BOOTSTRAP_SPEC)
BOOTSTRAP_SPEC.loader.exec_module(bootstrap)


def test_archive_and_restored_inventory_match(tmp_path: Path) -> None:
    home = tmp_path / "hermes"
    paths = {
        "sessions/session-1.json": "{}\n",
        "data/workout_attachments/2026-08-27/photo.txt": "attachment\n",
        "skills/health/trainer/SKILL.md": "# Trainer\n",
        "memories/profile.txt": "memory\n",
        "cron/jobs.json": json.dumps({"jobs": []}) + "\n",
    }
    for relative_path, content in paths.items():
        path = home / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    workout_log = home / "data/workout_log.csv"
    with workout_log.open("w", newline="") as workout_file:
        writer = csv.writer(workout_file)
        writer.writerow(["date", "exercise"])
        writer.writerow(["2026-08-27", "deadlift"])

    database = home / "state.db"
    connection = sqlite3.connect(database)
    connection.execute("CREATE TABLE messages (id INTEGER PRIMARY KEY, body TEXT)")
    connection.execute("INSERT INTO messages (body) VALUES ('done')")
    connection.commit()
    connection.close()

    archive = tmp_path / "backup.zip"
    with zipfile.ZipFile(archive, "w") as backup_zip:
        for path in home.rglob("*"):
            if path.is_file():
                backup_zip.write(path, path.relative_to(home))

    expected = backup.inventory_archive(archive)
    actual = backup.inventory_home(home, expected["databases"])

    assert actual == expected
    assert actual["message_rows"] == 1
    assert actual["workout_rows"] == 1
    assert actual["workout_log_sha256"] == backup._sha256(workout_log)
    assert actual["attachments"] == 1


def test_migration_archive_removes_local_runtime_and_direct_email(
    tmp_path: Path,
) -> None:
    source = tmp_path / "source.zip"
    destination = tmp_path / "sanitized.zip"
    config = {
        "email": {"address": "coach@example.com", "password": "remove-me"},
        "platforms": {"email": {"enabled": True}, "signal": {"enabled": True}},
    }
    cron = {
        "jobs": [
            {"name": "Email Gateway Watchdog"},
            {"name": "keep this job"},
        ]
    }
    database = tmp_path / "state.db"
    sqlite3.connect(database).close()
    with zipfile.ZipFile(source, "w") as archive:
        archive.writestr("auth.json", "{}\n")
        archive.write(database, "state.db")
        archive.writestr("config.yaml", backup.yaml.safe_dump(config))
        archive.writestr(
            ".env",
            "MODEL_TOKEN=keep-me\nEMAIL_PASSWORD=remove-me\nEMAIL_SMTP_HOST=remove-me\n",
        )
        archive.writestr("cron/jobs.json", json.dumps(cron))
        archive.writestr("cache/catalog.json", "{}\n")
        archive.writestr("node/bin/node", "rebuild\n")
        archive.writestr("plugins/email/adapter.py", "replace\n")
        archive.writestr("state-snapshots/old/state.db", "stale\n")
        archive.writestr("gateway_state.json", "{}\n")
        archive.writestr("data/workout_log.csv", "date,exercise\n")

    backup.sanitize_migration_archive(source, destination)

    with zipfile.ZipFile(destination) as archive:
        names = set(archive.namelist())
        assert "data/workout_log.csv" in names
        assert "cache/catalog.json" not in names
        assert "node/bin/node" not in names
        assert "plugins/email/adapter.py" not in names
        assert "state-snapshots/old/state.db" not in names
        assert "gateway_state.json" not in names
        assert archive.read(".env") == b""
        sanitized_config = backup.yaml.safe_load(archive.read("config.yaml"))
        assert sanitized_config["email"] == {"address": "coach@example.com"}
        assert sanitized_config["platforms"] == {"email": {"enabled": True}}
        sanitized_cron = json.loads(archive.read("cron/jobs.json"))
        assert sanitized_cron["jobs"] == [{"name": "keep this job"}]
    assert destination.stat().st_mode & 0o777 == 0o600


def test_bootstrap_env_contains_only_pilot_secrets(tmp_path: Path, monkeypatch) -> None:
    bootstrap.HERMES_HOME = tmp_path
    (tmp_path / ".env").write_text(
        "EMAIL_PASSWORD=remove-me\nSIGNAL_ACCOUNT=remove-me\nMODEL_TOKEN=remove-me\n"
    )
    for name in bootstrap.PERSISTED_ENV:
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setenv("BRIDGE_URL", "https://bridge.example.com")
    monkeypatch.setenv("BUCKET_NAME", "backup-bucket")

    bootstrap._write_env()

    assert (tmp_path / ".env").read_text().splitlines() == [
        'BRIDGE_URL="https://bridge.example.com"',
        'BUCKET_NAME="backup-bucket"',
    ]
    assert (tmp_path / ".env").stat().st_mode & 0o777 == 0o600


def test_bootstrap_removes_direct_email_and_legacy_plugin_aliases(
    tmp_path: Path,
) -> None:
    bootstrap.HERMES_HOME = tmp_path
    config = {
        "model": {
            "default": "openai/gpt-5.6-sol",
            "provider": "nous",
            "base_url": "https://inference-api.nousresearch.com/v1",
            "api_key": "remove",
            "api_mode": "remove",
        },
        "email": {"address": "keep", "imap_password": "remove"},
        "platforms": {"email": {}, "signal": {}},
        "plugins": {
            "enabled": ["keep", "email-platform", "platforms/email"],
            "disabled": ["keep-disabled", "email-platform", "platforms/email"],
            "entries": {
                "keep": {"allow_tool_override": False},
                "email-platform": {},
                "platforms/email": {},
            },
        },
    }
    (tmp_path / "config.yaml").write_text(bootstrap.yaml.safe_dump(config))

    bootstrap._sanitize_config()

    sanitized = bootstrap.yaml.safe_load((tmp_path / "config.yaml").read_text())
    assert sanitized["model"] == {
        "default": "gpt-5.6-sol",
        "provider": "openai-codex",
        "base_url": "https://chatgpt.com/backend-api/codex",
    }
    assert sanitized["email"] == {"address": "keep"}
    assert sanitized["platforms"] == {"email": {}}
    assert sanitized["plugins"] == {
        "enabled": ["keep"],
        "disabled": ["keep-disabled", "platforms/email"],
        "entries": {"keep": {"allow_tool_override": False}},
    }


def test_bootstrap_migrates_training_state_source_guard(tmp_path: Path) -> None:
    bootstrap.HERMES_HOME = tmp_path
    state_path = tmp_path / "data/training_reminder_state.json"
    state_path.parent.mkdir(parents=True)
    state_path.write_text(json.dumps({"schema_version": 1, "revision": 7}))

    bootstrap._migrate_training_state()

    state = json.loads(state_path.read_text())
    assert state == {
        "schema_version": 2,
        "revision": 7,
        "last_action_source_id": None,
    }
    assert state_path.stat().st_mode & 0o777 == 0o600


def test_upload_rejects_backup_missing_required_files(tmp_path: Path) -> None:
    archive_path = tmp_path / "incomplete.zip"
    with zipfile.ZipFile(archive_path, "w") as archive:
        archive.writestr("state.db", "")

    with pytest.raises(
        RuntimeError, match="backup is missing required files: auth.json, config.yaml"
    ):
        backup.upload(archive_path)


def test_production_backup_requires_existing_pilot_data(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    home = tmp_path / "home"
    home.mkdir()
    (home / "data").mkdir()
    (home / "data/training_reminder_state.json").write_text("{}")

    def fake_backup(command: list[str], *, check: bool) -> None:
        assert check
        archive_path = Path(command[-1])
        archive_path.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive_path, "w") as archive:
            for name in backup.MIGRATION_REQUIRED_FILES:
                archive.writestr(name, "")

    monkeypatch.setattr(backup, "HERMES_HOME", home)
    monkeypatch.setattr(backup.subprocess, "run", fake_backup)

    with pytest.raises(
        RuntimeError,
        match="backup is missing required files: data/training_reminder_state.json",
    ):
        backup._create_backup()
