---
name: posthog-cli
description: >
  Query PostHog analytics and manage resources (insights, dashboards, cohorts, session replays)
  using the PostHog CLI and REST API -- no MCP plugin needed, zero idle context cost.
  ALWAYS use this skill when the user mentions PostHog, analytics dashboards, insights, cohorts,
  session replays, HogQL, event queries, user segments, or anything related to PostHog data.
  Also trigger when the user asks about pageviews, funnels, retention, conversion rates,
  or "how many users did X" questions that clearly target PostHog.
---

# PostHog CLI Skill

Interact with PostHog via the CLI (`posthog-cli`) for HogQL queries and `curl` for the REST API.
This replaces the PostHog MCP plugin with zero idle context overhead.

## Setup & Auto-Install

Before any PostHog operation, ensure the CLI is available:

```bash
# Check and auto-install posthog-cli if missing
if ! command -v posthog-cli &>/dev/null; then
  if [ -f "$HOME/.posthog/env" ]; then
    source "$HOME/.posthog/env"
  fi
  if ! command -v posthog-cli &>/dev/null; then
    echo "Installing posthog-cli..."
    curl --proto '=https' --tlsv1.2 -LsSf \
      https://github.com/PostHog/posthog/releases/latest/download/posthog-cli-installer.sh | sh
    source "$HOME/.posthog/env"
  fi
fi
```

After install, if not yet authenticated, run `posthog-cli login` (opens browser for token setup).

## Authentication

Two auth methods, checked in order:

### 1. PostHog CLI (preferred for HogQL queries)

The CLI stores credentials locally after `posthog-cli login`.
CLI env vars (for CI or overrides): `POSTHOG_CLI_API_KEY`, `POSTHOG_CLI_PROJECT_ID`, `POSTHOG_CLI_HOST`.

### 2. REST API env vars (for curl-based operations)

- `POSTHOG_API_KEY` -- Personal API key (starts with `phx_`)
- `POSTHOG_PROJECT_ID` -- Project/environment ID (numeric, e.g. `270137`)
- `POSTHOG_HOST` -- Optional, defaults to `https://us.posthog.com`

If neither auth method is available, ask the user to run `posthog-cli login` or set env vars.

## Auth Detection

At the start of any PostHog task, source the CLI env and resolve credentials.
The CLI stores credentials in `~/.posthog/credentials.json` after `posthog-cli login`.
Curl operations fall back to this file when `POSTHOG_API_KEY` env var isn't set.

```bash
source "$HOME/.posthog/env" 2>/dev/null
# Resolve credentials: env vars take priority, then CLI credentials file
PH_HOST="${POSTHOG_HOST:-$(jq -r '.host // empty' ~/.posthog/credentials.json 2>/dev/null)}"
PH_HOST="${PH_HOST:-https://us.posthog.com}"
PH_KEY="${POSTHOG_API_KEY:-$(jq -r '.token // empty' ~/.posthog/credentials.json 2>/dev/null)}"
PH_PROJECT="${POSTHOG_PROJECT_ID:-$(jq -r '.env_id // empty' ~/.posthog/credentials.json 2>/dev/null)}"
echo "HOST=$PH_HOST PROJECT=$PH_PROJECT KEY=${PH_KEY:+set}"
```

## Curl Pattern

All REST API calls follow this pattern. The `PH_HOST`, `PH_KEY`, and `PH_PROJECT` variables
are resolved by the auth detection step above.

```bash
curl -s "$PH_HOST/api/projects/$PH_PROJECT/<endpoint>/" \
  -H "Authorization: Bearer $PH_KEY" \
  -H "Content-Type: application/json" | jq .
```

For write operations (POST/PATCH), add `-X POST` or `-X PATCH` and `-d '<json>'`.

Pagination: responses include `count`, `next`, `previous`, `results`. Follow `next` URL for more pages.

## URL Parsing

PostHog URLs contain project ID and resource IDs. Parse them to extract context:

```
https://us.posthog.com/project/{project_id}/replay/{recording_id}
https://us.posthog.com/project/{project_id}/dashboard/{dashboard_id}
https://us.posthog.com/project/{project_id}/cohorts/{cohort_id}
https://us.posthog.com/project/{project_id}/saved_insights/{short_id}
```

When the user pastes a PostHog URL, extract the project ID and resource ID from the path.

## HogQL Queries

The CLI query command is experimental: `posthog-cli exp query run`. For programmatic use, prefer the REST API (returns JSON).

```bash
# Via CLI (JSON lines to stdout)
source "$HOME/.posthog/env" 2>/dev/null
posthog-cli exp query run "SELECT event, count() FROM events GROUP BY event ORDER BY count() DESC LIMIT 10"

# Via REST API (structured JSON, preferred for parsing)
curl -s "$PH_HOST/api/projects/$PH_PROJECT/query/" \
  -H "Authorization: Bearer $PH_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": {"kind": "HogQLQuery", "query": "SELECT event, count() FROM events GROUP BY event ORDER BY count() DESC LIMIT 10"}}' | jq .
```

### HogQL Tips

- Common tables: `events`, `persons`, `sessions`, `groups`
- Event properties: `properties.$property_name`
- Person properties: `person.properties.$property_name`
- Session properties: `$session_duration`, `$entry_current_url`
- Time filters: `WHERE timestamp > now() - INTERVAL 7 DAY`
- Filter by session: `WHERE $session_id = '{session_id}'`
- Always include `LIMIT` to avoid huge result sets

## Session Replay Events

To get events that occurred during a session replay, use HogQL (not the recordings REST API):

```bash
# Get all events for a specific session
posthog-cli exp query run "SELECT event, timestamp, properties.\$current_url, properties.\$browser FROM events WHERE \$session_id = '019d2247-2694-7852-8e03-4ec51bbd6c3a' ORDER BY timestamp LIMIT 100"

# Via REST API
curl -s "$PH_HOST/api/projects/$PH_PROJECT/query/" \
  -H "Authorization: Bearer $PH_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "kind": "HogQLQuery",
      "query": "SELECT event, timestamp, properties.$current_url, properties.$browser FROM events WHERE $session_id = '\''019d2247-2694-7852-8e03-4ec51bbd6c3a'\'' ORDER BY timestamp LIMIT 100"
    }
  }' | jq .
```

The session recording metadata endpoint (`/api/projects/{id}/session_recordings/{recording_id}/`) returns duration, click counts, console error counts, person info, and start URL -- but NOT the raw replay data or event list. Use HogQL for events.

## API Endpoints Reference

Read `references/api-endpoints.md` for the complete endpoint reference with examples.
The file is organized by resource: Insights, Dashboards, Cohorts, Session Replays, Organizations/Projects.

## Quick Reference (most common operations)

| Operation | Method | Path |
|-----------|--------|------|
| List insights | GET | `/api/projects/{id}/insights/` |
| Get insight | GET | `/api/projects/{id}/insights/{insight_id}/` |
| Create insight | POST | `/api/projects/{id}/insights/` |
| Update insight | PATCH | `/api/projects/{id}/insights/{insight_id}/` |
| Delete insight | DELETE | `/api/projects/{id}/insights/{insight_id}/` |
| List dashboards | GET | `/api/projects/{id}/dashboards/` |
| Get dashboard | GET | `/api/projects/{id}/dashboards/{dashboard_id}/` |
| Create dashboard | POST | `/api/projects/{id}/dashboards/` |
| Update dashboard | PATCH | `/api/projects/{id}/dashboards/{dashboard_id}/` |
| Delete dashboard | PATCH | `/api/projects/{id}/dashboards/{dashboard_id}/` (set `deleted: true`) |
| List cohorts | GET | `/api/projects/{id}/cohorts/` |
| Get cohort | GET | `/api/projects/{id}/cohorts/{cohort_id}/` |
| Create cohort | POST | `/api/projects/{id}/cohorts/` |
| Update cohort | PATCH | `/api/projects/{id}/cohorts/{cohort_id}/` |
| Delete cohort | PATCH | `/api/projects/{id}/cohorts/{cohort_id}/` (set `deleted: true`) |
| List recordings | GET | `/api/projects/{id}/session_recordings/` |
| Get recording | GET | `/api/projects/{id}/session_recordings/{recording_id}/` |
| Recording events | HogQL | `SELECT ... FROM events WHERE $session_id = '{id}' ...` |
| List orgs | GET | `/api/organizations/` |
| List projects | GET | `/api/organizations/{org_id}/projects/` |
| Current user | GET | `/api/users/@me/` |

Note: Dashboards and cohorts use soft delete (PATCH with `"deleted": true`), not HTTP DELETE.

## Output Formatting

- Pipe curl output through `jq` for readability
- For list operations, show a summary table (id, name, key fields) rather than raw JSON
- For large result sets, default to showing the first 10 items and mentioning the total count
- When the user asks a question (not CRUD), prefer HogQL over the REST API -- it's more flexible

## Error Handling

- 401: API key is invalid or expired. Ask user to check `POSTHOG_API_KEY`.
- 403: Key lacks required scope. Inform user which scope is needed.
- 404: Resource not found or wrong project ID.
- 429: Rate limited (240/min for analytics, 480/min for CRUD). Wait and retry.
