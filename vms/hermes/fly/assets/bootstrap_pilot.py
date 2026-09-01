#!/usr/bin/env python3
"""Converge a restored Hermes home onto the email-only cloud pilot."""

from __future__ import annotations

import json
import os
import shutil
import tempfile
from pathlib import Path
from typing import Any

import yaml

HERMES_HOME = Path(os.environ.get("HERMES_HOME", "/opt/data"))
PERSISTED_ENV = (
    "BRIDGE_URL",
    "BRIDGE_API_TOKEN",
    "EMAIL_ADDRESS",
    "EMAIL_ALLOWED_USERS",
    "EMAIL_HOME_ADDRESS",
    "BUCKET_NAME",
    "AWS_ENDPOINT_URL_S3",
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
    "AWS_REGION",
)
DIRECT_EMAIL_CONFIG = {
    "login",
    "password",
    "poll_interval",
    "imap_host",
    "imap_port",
    "imap_mailbox",
    "imap_user",
    "imap_password",
    "smtp_host",
    "smtp_port",
    "smtp_user",
    "smtp_password",
}
OBSOLETE_JOBS = {"Email Gateway Watchdog", "Training Reminder Dispatcher"}
OBSOLETE_PATHS = (
    "scripts/bench_accessory_completion_reminder.py",
    "scripts/email_gateway_watchdog.sh",
    "scripts/training_reminder_config.json",
    "state-snapshots/email-plugin-backups",
)
TRAINING_STATE_SCHEMA = 2
CODEX_MODEL = "gpt-5.6-sol"
CODEX_PROVIDER = "openai-codex"
CODEX_BASE_URL = "https://chatgpt.com/backend-api/codex"


def _atomic_text(path: Path, content: str, mode: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        dir=path.parent, prefix=f".{path.name}."
    )
    try:
        with os.fdopen(descriptor, "w") as temporary_file:
            temporary_file.write(content)
            temporary_file.flush()
            os.fsync(temporary_file.fileno())
        os.chmod(temporary_name, mode)
        os.replace(temporary_name, path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


def _write_env() -> None:
    path = HERMES_HOME / ".env"
    existing = {}
    for name in PERSISTED_ENV:
        value = os.environ.get(name)
        if value:
            existing[name] = value
    lines = [f"{key}={json.dumps(value)}" for key, value in sorted(existing.items())]
    _atomic_text(path, "\n".join(lines) + "\n", 0o600)


def _sanitize_config() -> None:
    path = HERMES_HOME / "config.yaml"
    if not path.exists():
        return
    data = yaml.safe_load(path.read_text()) or {}
    if not isinstance(data, dict):
        raise TypeError("config.yaml must contain a mapping")
    model = data.get("model")
    model_config = dict(model) if isinstance(model, dict) else {}
    model_config.pop("api_key", None)
    model_config.pop("api", None)
    model_config.pop("api_mode", None)
    model_config.update(
        {
            "default": CODEX_MODEL,
            "provider": CODEX_PROVIDER,
            "base_url": CODEX_BASE_URL,
        }
    )
    data["model"] = model_config
    email = data.get("email")
    if isinstance(email, dict):
        data["email"] = {
            key: value for key, value in email.items() if key not in DIRECT_EMAIL_CONFIG
        }
    plugins = data.get("plugins")
    if isinstance(plugins, dict):
        enabled = plugins.get("enabled")
        if isinstance(enabled, list):
            plugins["enabled"] = [
                name
                for name in enabled
                if name not in {"email-platform", "platforms/email"}
            ]
        disabled = plugins.get("disabled")
        if isinstance(disabled, list):
            plugins["disabled"] = [
                name for name in disabled if name != "email-platform"
            ]
        entries = plugins.get("entries")
        if isinstance(entries, dict):
            entries.pop("email-platform", None)
            entries.pop("platforms/email", None)
    platforms = data.get("platforms")
    email_platform: dict[str, Any] = {}
    if isinstance(platforms, dict) and isinstance(platforms.get("email"), dict):
        email_platform = platforms["email"]
    data["platforms"] = {"email": email_platform}
    _atomic_text(path, yaml.safe_dump(data, sort_keys=False), 0o600)


def _remove_obsolete_jobs() -> None:
    path = HERMES_HOME / "cron/jobs.json"
    if not path.exists():
        return
    data = json.loads(path.read_text())
    if not isinstance(data, dict) or not isinstance(data.get("jobs"), list):
        raise TypeError("cron/jobs.json has an unsupported shape")
    data["jobs"] = [job for job in data["jobs"] if job.get("name") not in OBSOLETE_JOBS]
    _atomic_text(path, json.dumps(data, indent=2, sort_keys=True) + "\n", 0o600)


def _remove_obsolete_paths() -> None:
    for relative_path in OBSOLETE_PATHS:
        path = HERMES_HOME / relative_path
        if path.is_dir():
            shutil.rmtree(path)
        else:
            path.unlink(missing_ok=True)


def _migrate_training_state() -> None:
    path = HERMES_HOME / "data/training_reminder_state.json"
    if not path.exists():
        return
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise TypeError("training_reminder_state.json must contain a mapping")
    schema_version = data.get("schema_version")
    if type(schema_version) is not int:
        raise ValueError(f"unsupported training state schema: {schema_version!r}")
    if schema_version == TRAINING_STATE_SCHEMA:
        return
    if schema_version != 1:
        raise ValueError(f"unsupported training state schema: {schema_version!r}")
    data["schema_version"] = TRAINING_STATE_SCHEMA
    data["last_action_source_id"] = None
    _atomic_text(path, json.dumps(data, indent=2, sort_keys=True) + "\n", 0o600)


def main() -> None:
    if HERMES_HOME.resolve() != Path("/opt/data"):
        raise RuntimeError("pilot bootstrap requires HERMES_HOME=/opt/data")
    _write_env()
    _sanitize_config()
    _remove_obsolete_jobs()
    _remove_obsolete_paths()
    _migrate_training_state()


if __name__ == "__main__":
    main()
