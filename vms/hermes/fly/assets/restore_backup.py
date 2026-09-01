#!/usr/bin/env python3
"""Restore one Tigris backup into an empty drill volume and verify its inventory."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Any

import boto3
from backup_to_tigris import inventory_home

HERMES_HOME = Path(os.environ.get("HERMES_HOME", "/opt/data"))


def _client() -> Any:
    return boto3.client(
        "s3",
        endpoint_url=os.environ.get("AWS_ENDPOINT_URL_S3", "https://t3.storage.dev"),
        region_name=os.environ.get("AWS_REGION", "auto"),
    )


def _bucket() -> str:
    bucket = os.environ.get("BUCKET_NAME", "").strip()
    if not bucket:
        raise RuntimeError("BUCKET_NAME is required")
    return bucket


def _latest_key(client: Any, bucket: str) -> str:
    paginator = client.get_paginator("list_objects_v2")
    backups = [
        item
        for page in paginator.paginate(Bucket=bucket, Prefix="backups/")
        for item in page.get("Contents", [])
        if item["Key"].endswith(".zip")
    ]
    if not backups:
        raise RuntimeError("no Hermes backups found")
    return str(max(backups, key=lambda item: item["LastModified"])["Key"])


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as backup_file:
        for block in iter(lambda: backup_file.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--key")
    args = parser.parse_args()
    if HERMES_HOME.resolve() != Path("/opt/data"):
        raise RuntimeError("restore drill requires HERMES_HOME=/opt/data")
    if any(path.name != "lost+found" for path in HERMES_HOME.iterdir()):
        raise RuntimeError("restore drill volume is not empty")

    client = _client()
    bucket = _bucket()
    key = args.key or _latest_key(client, bucket)
    with tempfile.TemporaryDirectory() as temporary_directory:
        backup_path = Path(temporary_directory) / "hermes-backup.zip"
        manifest_path = Path(temporary_directory) / "manifest.json"
        client.download_file(bucket, key, str(backup_path))
        client.download_file(bucket, f"{key}.manifest.json", str(manifest_path))
        manifest = json.loads(manifest_path.read_text())
        if _sha256(backup_path) != manifest.get("sha256"):
            raise RuntimeError("backup checksum does not match its manifest")
        subprocess.run(["hermes", "import", "--force", str(backup_path)], check=True)

    expected = manifest["inventory"]
    actual = inventory_home(HERMES_HOME, expected["databases"])
    if actual != expected:
        print(
            json.dumps(
                {"expected": expected, "actual": actual}, indent=2, sort_keys=True
            )
        )
        raise RuntimeError("restored Hermes inventory does not match the backup")
    print(
        json.dumps(
            {
                "backup": key,
                "integrity": "ok",
                "inventory": actual,
            },
            indent=2,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
