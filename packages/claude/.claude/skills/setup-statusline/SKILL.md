---
name: setup-statusline
description: Configure Claude Code statusline to display Anthropic API rate limit usage (5-hour and 7-day utilization with time remaining). Integrates with the user's existing statusline script without replacing it.
disable-model-invocation: true
metadata:
  author: victor
  version: "1.0.0"
  argument-hint: "[uninstall]"
---

# Setup Statusline Rate Limits

Configure the Claude Code statusline to display real-time Anthropic API rate limit usage, appended to the user's existing statusline output.

## What it displays

Appended to the existing statusline:
- 5-hour rolling window utilization (%) with time remaining until reset
- 7-day rolling window utilization (%) with time remaining until reset
- Color-coded by severity: green (<50%), yellow (50-74%), red (75-89%), bold red (>=90%)
- Time remaining in Go-style duration format (e.g., `5d 3h 24m`)

Example output segment: `5h: 45% (2h 15m) 7d: 23% (5d 3h 24m)`

## Arguments

- No argument: install or update the rate limit statusline segment
- `uninstall`: remove the rate limit segment from the statusline

## Prerequisites

Before starting, verify these are met:
1. `jq` is installed (`which jq`)
2. `curl` is installed (`which curl`)
3. Claude Code OAuth credentials exist at `~/.claude/.credentials.json`
4. The credentials file contains a `claudeAiOauth.accessToken` field

If any prerequisite is missing, inform the user and stop.

## Install Steps

Follow these steps in order.

### Step 1: Install the usage segment script

Copy the reference script from this skill's directory to the user's scripts directory:

- Source: `!realpath reference/usage-segment.sh`
- Destination: `~/.claude/scripts/usage-segment.sh`

Create `~/.claude/scripts/` if it doesn't exist. Make the script executable (`chmod +x`).

### Step 2: Ensure cache directory exists

Create `${XDG_CACHE_DIR:-$HOME/.cache}/claude-code/` if it doesn't exist.

### Step 3: Read the existing statusline script

Read `~/.claude/settings.json` to find the current `statusLine.command` value. Then read that script file.

If no statusline is configured at all, create a minimal `~/.claude/statusline.sh`:

```bash
#!/bin/bash
input=$(cat)
```

And set `statusLine` in `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

### Step 4: Integrate the usage segment

Check if the statusline script already contains the marker comment `# --- Claude Code rate limit usage`. If it does, the segment is already installed — inform the user and skip to Step 5.

If not present, append the following integration block at the very end of the statusline script:

```bash

# --- Claude Code rate limit usage (managed by /setup-statusline) ---
usage_segment=$("$HOME/.claude/scripts/usage-segment.sh" 2>/dev/null)
if [ -n "$usage_segment" ]; then
    printf ' %s' "$usage_segment"
fi
# --- end rate limit usage ---
```

### Step 5: Verify

Run the usage segment script directly to confirm it produces output:

```bash
~/.claude/scripts/usage-segment.sh
```

If it produces output, the setup is complete. Show the user the raw output.

If it produces no output, check:
- Are the credentials valid and not expired?
- Does the API endpoint respond?
- Run with `bash -x` to debug: `bash -x ~/.claude/scripts/usage-segment.sh`

Inform the user of the result. Remind them that the statusline updates after each assistant message, so they'll see it on the next interaction.

## Uninstall Steps

If the argument is `uninstall`:

1. Remove the integration block from the statusline script (everything between `# --- Claude Code rate limit usage` and `# --- end rate limit usage ---`, inclusive)
2. Delete `~/.claude/scripts/usage-segment.sh`
3. Optionally delete the cache: `~/.cache/claude-code/usage.json`
4. Inform the user that the rate limit display has been removed

## Implementation Notes

- The usage segment script is designed to be a standalone executable. It reads credentials, manages its own cache, and outputs a formatted string. This keeps the integration with the main statusline minimal (just a function call and printf).
- Cache TTL is 60 seconds. The API is only called when the cache is stale.
- On any error (missing credentials, expired token, API failure, malformed response), the script exits silently with no output. The statusline degrades gracefully — the rate limit segment simply doesn't appear.
- The script uses GNU coreutils (`date -d`, `stat -c`). It will not work on macOS without adaptation.
