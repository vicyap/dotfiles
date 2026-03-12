---
name: time-machine-prune
description: List local Time Machine APFS snapshots, compare against the latest external backup, identify redundant snapshots, and generate a one-liner to delete them.
metadata:
  author: victor
  version: "1.0.0"
---

# Time Machine Prune

Identify and help the user remove local Time Machine APFS snapshots that are redundant because a more recent backup exists on the external Time Machine drive.

## Steps

Follow these steps in order.

### Step 1: Gather data

Run these three commands in parallel:

1. `diskutil list` — to identify drives
2. `tmutil listlocalsnapshots /` — to list local snapshots
3. `tmutil latestbackup 2>/dev/null` — to get the latest external backup timestamp

### Step 2: Parse the latest backup timestamp

Extract the backup timestamp from the `tmutil latestbackup` output. The path contains a timestamp in `YYYY-MM-DD-HHMMSS` format.

If `tmutil latestbackup` fails or returns no output, inform the user that no external Time Machine backup destination was found and stop.

### Step 3: Identify redundant snapshots

From the `tmutil listlocalsnapshots /` output:

- Only consider snapshots prefixed with `com.apple.TimeMachine.` — ignore all others (e.g., `com.apple.os.update` system snapshots).
- Extract the timestamp from each Time Machine snapshot name (format: `YYYY-MM-DD-HHMMSS`).
- A snapshot is **redundant** if its timestamp is less than or equal to the latest external backup timestamp.

### Step 4: Present findings

Display a summary table of all Time Machine local snapshots showing:
- Snapshot timestamp
- Status: "Redundant" (older than or equal to latest backup) or "Newer than backup" (created after latest backup)

State the latest external backup timestamp for context.

### Step 5: Generate delete command or exit

If there are **no redundant snapshots**, say so and stop.

If there are redundant snapshots, generate a single one-liner command for the user to run in their terminal:

```
for s in <timestamp1> <timestamp2> ...; do sudo tmutil deletelocalsnapshots $s; done
```

Explain that `sudo` is required and they will be prompted for their password once.
