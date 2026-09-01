#!/usr/bin/env python3
"""Create, inventory, upload, and retain full Hermes backups in Tigris."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import sqlite3
import subprocess
import tempfile
import zipfile
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import TYPE_CHECKING, Any

import boto3
import yaml

if TYPE_CHECKING:
    from collections.abc import Callable, Iterable

HERMES_HOME = Path(os.environ.get("HERMES_HOME", "/opt/data"))
RETENTION_DAYS = 30
DIRECT_EMAIL_CONFIG = {
    "imap_host",
    "imap_mailbox",
    "imap_password",
    "imap_port",
    "imap_user",
    "login",
    "password",
    "poll_interval",
    "smtp_host",
    "smtp_password",
    "smtp_port",
    "smtp_user",
}
MIGRATION_EXCLUDED_PREFIXES = (
    "bin/",
    "cache/",
    "logs/",
    "lsp/",
    "node/",
    "platforms/signal/",
    "plugins/email/",
    "state-snapshots/",
)
MIGRATION_EXCLUDED_FILES = {
    ".hermes_history",
    ".update_check",
    "auth.lock",
    "channel_directory.json",
    "context_length_cache.yaml",
    "gateway.lock",
    "gateway_state.json",
    "interrupt_debug.log",
    "kanban.db.dispatch.lock",
    "kanban.db.init.lock",
    "models_dev_cache.json",
    "ollama_cloud_models_cache.json",
    "processes.json",
    "provider_models_cache.json",
    "scripts/bench_accessory_completion_reminder.py",
    "scripts/email_gateway_watchdog.sh",
    "scripts/training_reminder_config.json",
    "scripts/training_reminder_dispatcher.py",
}
MIGRATION_REQUIRED_FILES = {"auth.json", "config.yaml", "state.db"}
PILOT_DURABLE_FILES = {
    "data/training_reminder_state.json",
    "data/workout_log.csv",
}
OBSOLETE_JOBS = {"Email Gateway Watchdog", "Training Reminder Dispatcher"}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as backup_file:
        for block in iter(lambda: backup_file.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _database_inventory(path: Path) -> dict[str, Any]:
    connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        integrity = str(connection.execute("PRAGMA integrity_check").fetchone()[0])
        tables = [
            str(row[0])
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
            )
        ]
        rows = {
            table: int(
                connection.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
            )
            for table in sorted(tables)
            if '"' not in table
        }
    finally:
        connection.close()
    return {"integrity": integrity, "rows": rows}


def _category_files(paths: Iterable[str]) -> dict[str, list[str]]:
    normalized = [Path(path) for path in paths]
    return {
        "sessions": [
            path.as_posix() for path in normalized if path.parts[:1] == ("sessions",)
        ],
        "attachments": [
            path.as_posix()
            for path in normalized
            if path.parts[:2] == ("data", "workout_attachments")
        ],
        "skills": [
            path.as_posix()
            for path in normalized
            if path.parts[:1] == ("skills",) and path.name == "SKILL.md"
        ],
        "memories": [
            path.as_posix()
            for path in normalized
            if path.parts[:1] in {("memory",), ("memories",)}
        ],
    }


def _categorize(paths: Iterable[str]) -> dict[str, int]:
    categories = _category_files(paths)
    return {
        "session_files": len(categories["sessions"]),
        "attachments": len(categories["attachments"]),
        "skill_files": len(categories["skills"]),
        "memory_files": len(categories["memories"]),
    }


def _category_hashes(
    paths: Iterable[str], reader: Callable[[str], bytes]
) -> dict[str, str | None]:
    hashes: dict[str, str | None] = {}
    for category, names in _category_files(paths).items():
        if not names:
            hashes[f"{category}_sha256"] = None
            continue
        digest = hashlib.sha256()
        for name in sorted(names):
            name_bytes = name.encode()
            content = reader(name)
            digest.update(len(name_bytes).to_bytes(8, "big"))
            digest.update(name_bytes)
            digest.update(len(content).to_bytes(8, "big"))
            digest.update(content)
        hashes[f"{category}_sha256"] = digest.hexdigest()
    return hashes


def inventory_archive(path: Path) -> dict[str, Any]:
    with (
        zipfile.ZipFile(path) as archive,
        tempfile.TemporaryDirectory() as temporary_directory,
    ):
        files = [name for name in archive.namelist() if not name.endswith("/")]
        inventory: dict[str, Any] = _categorize(files)
        inventory.update(_category_hashes(files, archive.read))
        inventory["workout_rows"] = 0
        inventory["workout_log_sha256"] = None
        inventory["cron_jobs_sha256"] = None
        inventory["databases"] = {}
        for name in files:
            member = Path(name)
            if member == Path("data/workout_log.csv"):
                content = archive.read(name)
                with archive.open(name) as workout_file:
                    rows = list(
                        csv.reader(
                            line.decode(errors="replace") for line in workout_file
                        )
                    )
                inventory["workout_rows"] = max(0, len(rows) - 1)
                inventory["workout_log_sha256"] = hashlib.sha256(content).hexdigest()
            elif member == Path("cron/jobs.json"):
                inventory["cron_jobs_sha256"] = hashlib.sha256(
                    archive.read(name)
                ).hexdigest()
            elif member.suffix == ".db":
                extracted = Path(temporary_directory) / member.name
                extracted.write_bytes(archive.read(name))
                inventory["databases"][name] = _database_inventory(extracted)
        inventory["message_rows"] = sum(
            count
            for database in inventory["databases"].values()
            for table, count in database["rows"].items()
            if "message" in table.lower()
        )
        return inventory


def inventory_home(root: Path, database_names: Iterable[str]) -> dict[str, Any]:
    files = [
        path.relative_to(root).as_posix() for path in root.rglob("*") if path.is_file()
    ]
    inventory: dict[str, Any] = _categorize(files)
    inventory.update(_category_hashes(files, lambda name: (root / name).read_bytes()))
    workout_log = root / "data/workout_log.csv"
    inventory["workout_rows"] = 0
    inventory["workout_log_sha256"] = None
    if workout_log.exists():
        with workout_log.open(newline="") as workout_file:
            inventory["workout_rows"] = max(
                0, sum(1 for _ in csv.reader(workout_file)) - 1
            )
        inventory["workout_log_sha256"] = _sha256(workout_log)
    cron_jobs = root / "cron/jobs.json"
    inventory["cron_jobs_sha256"] = _sha256(cron_jobs) if cron_jobs.exists() else None
    inventory["databases"] = {}
    for name in database_names:
        database = root / name
        if database.exists():
            inventory["databases"][name] = _database_inventory(database)
    inventory["message_rows"] = sum(
        count
        for database in inventory["databases"].values()
        for table, count in database["rows"].items()
        if "message" in table.lower()
    )
    return inventory


def _migration_member_allowed(name: str) -> bool:
    member = Path(name)
    if member.is_absolute() or ".." in member.parts:
        raise RuntimeError(f"unsafe backup member: {name}")
    normalized = member.as_posix().rstrip("/")
    if normalized in MIGRATION_EXCLUDED_FILES:
        return False
    if normalized.startswith(("config.yaml.bak.", ".gateway_state_")):
        return False
    return not any(
        normalized == prefix.rstrip("/") or normalized.startswith(prefix)
        for prefix in MIGRATION_EXCLUDED_PREFIXES
    )


def _sanitize_config(content: bytes) -> bytes:
    data = yaml.safe_load(content) or {}
    if not isinstance(data, dict):
        raise TypeError("config.yaml must contain a mapping")
    email = data.get("email")
    if isinstance(email, dict):
        data["email"] = {
            key: value for key, value in email.items() if key not in DIRECT_EMAIL_CONFIG
        }
    platforms = data.get("platforms")
    email_platform: dict[str, Any] = {}
    if isinstance(platforms, dict) and isinstance(platforms.get("email"), dict):
        email_platform = platforms["email"]
    data["platforms"] = {"email": email_platform}
    return yaml.safe_dump(data, sort_keys=False).encode()


def _sanitize_cron(content: bytes) -> bytes:
    data = json.loads(content)
    if not isinstance(data, dict) or not isinstance(data.get("jobs"), list):
        raise TypeError("cron/jobs.json has an unsupported shape")
    data["jobs"] = [job for job in data["jobs"] if job.get("name") not in OBSOLETE_JOBS]
    return (json.dumps(data, indent=2, sort_keys=True) + "\n").encode()


def sanitize_migration_archive(source: Path, destination: Path) -> None:
    if not source.is_file() or not zipfile.is_zipfile(source):
        raise RuntimeError(f"not a Hermes backup zip: {source}")
    retained = set()
    with (
        zipfile.ZipFile(source) as original,
        zipfile.ZipFile(destination, "w") as sanitized,
    ):
        sanitized.comment = original.comment
        for member in original.infolist():
            if not _migration_member_allowed(member.filename):
                continue
            content = original.read(member)
            if member.filename == ".env":
                content = b""
            elif member.filename == "config.yaml":
                content = _sanitize_config(content)
            elif member.filename == "cron/jobs.json":
                content = _sanitize_cron(content)
            sanitized.writestr(member, content)
            if not member.is_dir():
                retained.add(member.filename)
    missing = sorted(MIGRATION_REQUIRED_FILES - retained)
    if missing:
        destination.unlink(missing_ok=True)
        raise RuntimeError(
            f"migration backup is missing required files: {', '.join(missing)}"
        )
    destination.chmod(0o600)


def _client() -> Any:
    endpoint = os.environ.get("AWS_ENDPOINT_URL_S3", "https://t3.storage.dev")
    return boto3.client(
        "s3", endpoint_url=endpoint, region_name=os.environ.get("AWS_REGION", "auto")
    )


def _bucket() -> str:
    bucket = os.environ.get("BUCKET_NAME", "").strip()
    if not bucket:
        raise RuntimeError("BUCKET_NAME is required")
    return bucket


def _create_backup() -> Path:
    backup_directory = HERMES_HOME / "backups/cloud"
    backup_directory.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(UTC).strftime("%Y-%m-%d-%H%M%S")
    path = backup_directory / f"hermes-backup-{stamp}.zip"
    subprocess.run(["hermes", "backup", "--output", str(path)], check=True)
    if not path.is_file() or not zipfile.is_zipfile(path):
        raise RuntimeError("hermes backup did not create a valid zip archive")
    required = MIGRATION_REQUIRED_FILES | {
        name for name in PILOT_DURABLE_FILES if (HERMES_HOME / name).is_file()
    }
    _require_archive_files(path, required)
    return path


def _prune(client: Any, bucket: str, now: datetime) -> None:
    cutoff = now - timedelta(days=RETENTION_DAYS)
    paginator = client.get_paginator("list_objects_v2")
    stale = []
    for page in paginator.paginate(Bucket=bucket, Prefix="backups/"):
        stale.extend(
            {"Key": item["Key"]}
            for item in page.get("Contents", [])
            if item["LastModified"] < cutoff
        )
    for offset in range(0, len(stale), 1000):
        client.delete_objects(
            Bucket=bucket, Delete={"Objects": stale[offset : offset + 1000]}
        )


def _require_archive_files(path: Path, required: set[str]) -> None:
    with zipfile.ZipFile(path) as archive:
        missing = sorted(required - set(archive.namelist()))
    if missing:
        raise RuntimeError(f"backup is missing required files: {', '.join(missing)}")


def upload(path: Path, key: str | None = None) -> str:
    if not path.is_file() or not zipfile.is_zipfile(path):
        raise RuntimeError(f"not a Hermes backup zip: {path}")
    _require_archive_files(path, MIGRATION_REQUIRED_FILES)
    now = datetime.now(UTC)
    object_key = key or f"backups/{now:%Y-%m-%d}/{path.name}"
    manifest = {
        "schema_version": 1,
        "created_at": now.isoformat(),
        "object_key": object_key,
        "sha256": _sha256(path),
        "size": path.stat().st_size,
        "hermes_revision": "7426c09beee73bdff94d916015bac71384f6bc92",
        "inventory": inventory_archive(path),
    }
    manifest_path = path.with_suffix(path.suffix + ".manifest.json")
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    client = _client()
    bucket = _bucket()
    try:
        client.upload_file(str(path), bucket, object_key)
        client.upload_file(str(manifest_path), bucket, f"{object_key}.manifest.json")
        _prune(client, bucket, now)
    finally:
        manifest_path.unlink(missing_ok=True)
    return object_key


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--key")
    parser.add_argument("--sanitize-source", type=Path)
    parser.add_argument("--sanitize-destination", type=Path)
    args = parser.parse_args()
    if args.sanitize_source is not None or args.sanitize_destination is not None:
        if args.sanitize_source is None or args.sanitize_destination is None:
            parser.error(
                "--sanitize-source and --sanitize-destination are required together"
            )
        sanitize_migration_archive(
            args.sanitize_source.resolve(), args.sanitize_destination.resolve()
        )
        print(args.sanitize_destination)
        return
    if args.source is not None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            backup_path = Path(temporary_directory) / "hermes-migration.zip"
            sanitize_migration_archive(args.source.resolve(), backup_path)
            key = upload(backup_path, args.key)
    else:
        backup_path = _create_backup()
        try:
            key = upload(backup_path, args.key)
        finally:
            backup_path.unlink(missing_ok=True)
    print(key)


if __name__ == "__main__":
    main()
