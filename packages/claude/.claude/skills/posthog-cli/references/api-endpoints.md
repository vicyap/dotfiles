# PostHog REST API Endpoints Reference

Base URL: `${POSTHOG_HOST:-https://us.posthog.com}`
Auth header: `Authorization: Bearer $POSTHOG_API_KEY`

All project-scoped endpoints use `/api/projects/{project_id}/` prefix.

---

## Insights

### List insights
```
GET /api/projects/{project_id}/insights/
```
Query params: `limit`, `offset`, `short_id`, `basic` (boolean, lighter response), `format` (json|csv)
Response: `{ count, next, previous, results: [{ id, short_id, name, derived_name, description, query, created_at, created_by, last_refresh, dashboards }] }`

### Get insight
```
GET /api/projects/{project_id}/insights/{insight_id}/
```
Returns full insight with query definition and results.

### Create insight
```
POST /api/projects/{project_id}/insights/
Content-Type: application/json
```
Body:
```json
{
  "name": "My Insight",
  "description": "optional",
  "query": {
    "kind": "InsightVizNode",
    "source": {
      "kind": "TrendsQuery",
      "series": [{"kind": "EventsNode", "event": "$pageview"}],
      "dateRange": {"date_from": "-7d"},
      "interval": "day"
    }
  },
  "dashboards": [1]
}
```

### Update insight
```
PATCH /api/projects/{project_id}/insights/{insight_id}/
Content-Type: application/json
```
Body: any subset of create fields (name, description, query, dashboards, etc.)

### Delete insight
```
DELETE /api/projects/{project_id}/insights/{insight_id}/
```

---

## Dashboards

### List dashboards
```
GET /api/projects/{project_id}/dashboards/
```
Query params: `limit`, `offset`
Response: `{ count, next, previous, results: [{ id, name, description, pinned, created_at, created_by, tags, deleted }] }`

### Get dashboard
```
GET /api/projects/{project_id}/dashboards/{dashboard_id}/
```
Returns full dashboard with tiles (each tile contains an insight).

### Create dashboard
```
POST /api/projects/{project_id}/dashboards/
Content-Type: application/json
```
Body:
```json
{
  "name": "My Dashboard",
  "description": "optional",
  "pinned": false,
  "tags": ["tag1"]
}
```

### Update dashboard
```
PATCH /api/projects/{project_id}/dashboards/{dashboard_id}/
Content-Type: application/json
```
Body: any subset of create fields.

### Delete dashboard (soft delete)
```
PATCH /api/projects/{project_id}/dashboards/{dashboard_id}/
Content-Type: application/json
```
Body: `{"deleted": true}`

Hard DELETE is not supported. Use PATCH with `deleted: true`.

---

## Cohorts

### List cohorts
```
GET /api/projects/{project_id}/cohorts/
```
Query params: `limit`, `offset`
Response: `{ count, next, previous, results: [{ id, name, description, count, is_static, is_calculating, created_at, created_by, last_calculation, groups, filters }] }`

### Get cohort
```
GET /api/projects/{project_id}/cohorts/{cohort_id}/
```

### Create cohort
```
POST /api/projects/{project_id}/cohorts/
Content-Type: application/json
```
Body for dynamic cohort:
```json
{
  "name": "Power Users",
  "description": "Users with 10+ sessions",
  "filters": {
    "properties": {
      "type": "AND",
      "values": [{
        "type": "behavioral",
        "key": "session_count",
        "value": 10,
        "operator": "gte"
      }]
    }
  }
}
```
Body for static cohort: `{"name": "My Cohort", "is_static": true}`

### Update cohort
```
PATCH /api/projects/{project_id}/cohorts/{cohort_id}/
Content-Type: application/json
```

### Delete cohort (soft delete)
```
PATCH /api/projects/{project_id}/cohorts/{cohort_id}/
Content-Type: application/json
```
Body: `{"deleted": true}`

### Get cohort persons
```
GET /api/projects/{project_id}/cohorts/{cohort_id}/persons/
```

---

## Session Recordings

Note: The REST API provides metadata about recordings, not the raw replay JSON.
To get raw replay data, use "Export as JSON" in the PostHog UI.

### List recordings
```
GET /api/projects/{project_id}/session_recordings/
```
Query params: `limit`, `offset`, `person_uuid`, `date_from`, `date_to`, `duration_type_filter` (duration|active_seconds|inactive_seconds), `session_recording_duration` (JSON filter)
Response: `{ count, next, previous, results: [{ id, distinct_id, viewed, recording_duration, active_seconds, inactive_seconds, start_time, end_time, click_count, keypress_count, console_error_count, start_url, person, activity_score }] }`

### Get recording
```
GET /api/projects/{project_id}/session_recordings/{recording_id}/
```
Returns full recording metadata including person info and snapshot source.

### Update recording (e.g., pin/unpin)
```
PATCH /api/projects/{project_id}/session_recordings/{recording_id}/
Content-Type: application/json
```

### Delete recording
```
DELETE /api/projects/{project_id}/session_recordings/{recording_id}/
```

---

## Organizations & Projects

### Get current user (includes org and project info)
```
GET /api/users/@me/
```
Returns user info including `organization.id` and `team.id` (team = project).

### List organizations
```
GET /api/organizations/
```
Response: `{ count, results: [{ id, name, slug, created_at }] }`

### List projects in organization
```
GET /api/organizations/{org_id}/projects/
```
Response: `{ count, results: [{ id, name, uuid, organization, api_token, created_at }] }`

---

## HogQL Query (REST API fallback)

When `posthog-cli` is not installed, run HogQL via the API:

```
POST /api/projects/{project_id}/query/
Content-Type: application/json
```
Body:
```json
{
  "query": {
    "kind": "HogQLQuery",
    "query": "SELECT event, count() FROM events WHERE timestamp > now() - INTERVAL 7 DAY GROUP BY event ORDER BY count() DESC LIMIT 10"
  }
}
```
Response: `{ results: [[value, value], ...], columns: ["event", "count()"], types: ["String", "UInt64"] }`

For trends-style queries:
```json
{
  "query": {
    "kind": "TrendsQuery",
    "series": [{"kind": "EventsNode", "event": "$pageview"}],
    "dateRange": {"date_from": "-7d"},
    "interval": "day"
  }
}
```
