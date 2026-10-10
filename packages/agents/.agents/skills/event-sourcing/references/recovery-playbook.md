# Truncate-and-Replay Recovery Playbook

The single recovery primitive in event sourcing: throw the projection away, fix the projector, replay every event from the start. Tens of thousands of events typically replay in seconds-to-minutes; subscribed UIs refill in real time as broadcasts flow.

This file is a runbook. Read it before recommending or executing a projection rebuild.

## When to use it

| Symptom | Use replay? |
|---|---|
| A projector silently dropped events for some window | Yes — fix projector, replay |
| You want to add a new column derivable from past events | Yes — change schema, replay |
| A read table's shape no longer fits the screen | Yes — build new projection version, replay, cut over |
| A feature flag changed how events were projected, and toggling it off didn't migrate rows | Yes — rebuild the projection cleanly |
| The event log itself is wrong (you wrote a bad event) | **No** — events are immutable; emit a corrective event instead |
| Side-effect handler (Slack, email) misfired in the past | **No** — those are gone; do not "replay" handlers that hit external systems |

The third row is the most common in practice. Schema changes that would be a migration + backfill in CRUD become "new projection version + replay" in event sourcing.

## Pre-flight checks

Before truncating anything in production:

1. **Confirm the projector is the bug, not the event payload.** If the data was never in the event, no replay will conjure it. Read the raw event stream first.
2. **Confirm only projectors write to the projection.** If anything else (a manual SQL backfill, a different service) writes to the read table, you'll wipe that data too.
3. **Estimate replay duration.** Time = events × per-event projection cost. For a few thousand events, seconds. For millions, plan for minutes-to-hours and consider building the new version side-by-side instead of in-place.
4. **Check what depends on the projection.** LiveViews subscribed to PubSub will refresh as events stream through. APIs reading the table directly will see partial data during the rebuild. If that matters, see "Side-by-side rebuild" below.
5. **Have the projector cursor reset command ready.** Whatever library or table you use to track "last consumed event," you need a clean reset.

## In-place rebuild (small projections)

For projections small enough that downtime during replay is acceptable:

```sql
-- 1. Stop the projector process so it doesn't race with you.

-- 2. Truncate the projection.
TRUNCATE TABLE membership_activity_v2;

-- 3. Reset the projector's cursor (exact mechanism depends on your event store).
UPDATE projector_state SET last_event_id = 0
  WHERE projector_name = 'MembershipActivityV2Projector';

-- 4. Restart the projector.
```

The projector reads from event 0 forward. Broadcasts to subscribed UIs continue normally — they see the rebuild happen in real time.

## Side-by-side rebuild (the V2 → V3 pattern)

The standard pattern at scale: version event types and projectors aggressively (events suffixed `V2`, `V3`, `V4`), and run new versions alongside old until cutover. A small "trigger replay per service / stream / handler" admin tool pays for itself fast.

For larger projections or when downtime isn't acceptable, version the projector and table:

1. Build `MembershipActivityV3Projector` writing to `membership_activity_v3`.
2. Start it from event 0; it replays the whole log into the new table while V2 keeps serving reads.
3. When V3 catches up to the live tail (its cursor matches the latest event ID), cut over reads:
   - LiveViews and queries point at `membership_activity_v3`.
   - Stop and remove `MembershipActivityV2Projector`.
   - Drop `membership_activity_v2` after a safety window.

This is also the pattern for shape changes that aren't strictly bug fixes — adding columns, splitting rows, denormalizing further. Versioned projector names (`MembershipActivityV2Projector`) are a strong signal you should reach for this pattern routinely, not just on emergencies.

## Rules during replay

- **Side-effect handlers must not fire on replay.** A `SlackHandler` configured to start at event 0 will message the team about every historical purchase. Configure side-effect handlers to start at the current cursor when first registered, and never reset their cursor.
- **Chain handlers (workflow steps) generally also start at "now."** If you replay a `CategorizeHandler` from event 0, it will re-categorize every file ever uploaded — and re-emit `FileCategorized` events, which will trigger `ReviewHandler`, which will hit external services. Replay only state-building projectors.
- **PubSub broadcasts during replay are usually fine.** Subscribers just see the projection refill. If you have side effects that listen on PubSub topics, gate them by event timestamp.

## Forward-only fixes are still legitimate

You don't always have to replay. Sometimes the right move is:

1. Fix the bug going forward.
2. Add regression tests.
3. Decide that historical correctness isn't worth the rebuild.

That's how a CRUD app would have to handle it — the difference is event sourcing gives you the *option* to do better.

## What this does not fix

- **Bad events.** If `%PurchaseCompleted{amount: 1000}` was written when the real amount was $100, you cannot edit the event. Emit a corrective event (`%PurchaseAmountCorrected{purchase_id:, correct_amount:}`) and project both. The history shows what happened, including the correction.
- **Lost external side effects.** A Slack message that didn't get sent in the past won't be sent by replaying. Decide whether to manually re-trigger or note the gap.
- **Logic bugs in the writer.** If the action that emits events has the bug (wrong event type, missing field), replay won't help — the event log is already wrong. Fix the writer; emit corrective events for the affected window if needed.

## Build the debug page early

The single most useful tool when something goes wrong is a page that reads the raw event stream by aggregate ID, ordered by timestamp. Your app usually does not read from the event store directly, but for debugging you need to. Build it before you need it. Filter by event type, by aggregate ID, by time range. Real production debugging of silent projector failures starts here.
