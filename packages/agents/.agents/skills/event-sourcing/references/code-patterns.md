# Code Patterns (Pseudocode)

Language-agnostic skeletons for the patterns described in SKILL.md. Translate into your stack of choice — the structure transfers directly.

Production teams typically build these on Postgres with a thin custom event-store library (no heavy CQRS framework). The patterns are simple enough that a 200-line library is usually clearer than a heavyweight framework.

## 1. Event store: append with optimistic concurrency

```
function append(stream_id, expected_version, events):
  begin transaction
    current_version = SELECT MAX(seq) FROM events WHERE stream_id = ?
    if current_version != expected_version:
      raise ConcurrencyError                -- caller retries from step 2 of command flow
    for i, event in enumerate(events, start = current_version + 1):
      INSERT INTO events (stream_id, seq, type, payload, metadata, occurred_at)
        VALUES (?, ?, ?, ?, ?, now())
        -- unique constraint on (stream_id, seq) catches the race
  commit
```

Schema:

```
events (
  stream_id     text         not null,
  seq           bigint       not null,
  event_type    text         not null,
  payload       jsonb        not null,
  metadata      jsonb        not null,
  occurred_at   timestamptz  not null default now(),
  primary key (stream_id, seq)
)
index events_global on (occurred_at, stream_id, seq)   -- for projector subscriptions
```

Per-stream `seq` is monotonic; the global index supports forward subscriptions across all streams.

## 2. Command handler

```
function handle_command(command):
  events  = event_store.load(command.aggregate_id)
  state   = events.fold(initial_state, apply_event)
  if not valid(command, state):
    return Error(reason)
  new_events = decide(command, state)        -- pure function: state + command -> [event]
  event_store.append(command.aggregate_id, len(events), new_events)
  return Ok
```

`decide` is pure. `apply_event` is pure. The only I/O is at the boundary (load + append). The action returns once events are appended; it does **not** wait for projectors. Callers learn the result via PubSub.

## 3. Projector

```
loop:
  events = event_store.read_after(my_cursor, batch_size = 100)
  for event in events:
    handle(event)             -- writes to read model
    advance(my_cursor)
```

For each event type:

```
function handle(InternalNoteCreated event):
  begin transaction
    note = read_model.notes.get(event.internal_note_id)
    if note is null:
      log.error("InternalNoteNotFound", event_id = event.id, ...)
      return Error               -- DO NOT return Ok; fail loud, halt the cursor
    read_model.activity.insert({
      content:        note.content,
      event_type:     "internal_note_created",
      membership_id:  event.membership_id,
      occurred_at:    event.created_at,
      user_id:        event.author_id,
    })
  commit
  pubsub.publish("activity:" + event.membership_id, {kind: "row_inserted", row: ...})
```

Critical: the error path returns an error, **not** "ok with nothing written." A silently `:ok`'d error is the classic projector bug — events appear consumed, the read model is broken, and nobody finds out until users do. The outbox should refuse to advance past an event the projector failed to handle.

## 4. Projection versioning (V2 → V3 cutover)

```
register MembershipActivityV3Projector with cursor = 0      -- replays from origin
  (V2 keeps serving reads in parallel)

when V3.cursor reaches latest_event_id:
  flip readers from V2 to V3                                 -- can be a feature flag
  stop V3-shaped writes from V2
  drop membership_activity_v2 table after a safety window
```

This is the standard schema-evolution flow. Both projections coexist while the new one catches up; readers cut over atomically; the old one retires.

## 5. Side-effect handler

Same shape as a projector, but does I/O instead of writing the read model. Configure to start at the **current** cursor on first registration so historical events don't re-fire.

```
register SlackHandler with start_from = :current

function handle(PurchaseCompleted event):
  msg = "New purchase: $" + event.amount + " from user " + event.user_id
  slack.send_message("#sales", msg)
  return Ok
```

`start_from = :current` is the difference from a state-building projector. The first time the handler boots in any environment, its cursor is set to the latest event ID. Only state-building projectors replay from origin.

## 6. Async workflow chain

Each step is a handler subscribed to the previous step's event; finishing emits the next event. The DAG is encoded in subscriptions, not in branching code.

```
register CategorizeHandler with start_from = :current

function CategorizeHandler.handle(FileUploaded event):
  category = categorizer.classify(event.file_url)
  event_store.append("file:" + event.file_id, expected_version = ?, [
    FileCategorized { file_id: event.file_id, category: category }
  ])
  return Ok


register ReviewHandler with start_from = :current

function ReviewHandler.handle(FileCategorized event):
  if event.category == :policy:
    event_store.append(..., [PolicyAnalyzed { file_id: ..., analysis: ... }])
  else if event.category == :address_doc:
    event_store.append(..., [AddressIdentified { file_id: ..., address: ... }])
  return Ok
```

Adding a step is a new handler subscribed to the right event. Existing handlers don't change.

## 7. Saga aggregate

A saga is an aggregate that orchestrates a multi-step process. Its event stream is short-lived: born when the parent business event fires, dies when the process completes or compensates.

```
on TransferInitiated event:
  start saga with stream_id = "saga:execute:" + event.transfer_id
  saga emits ScreeningRequested

on ScreeningPassed for that saga:
  saga emits FundsReservationRequested

on FundsReserved for that saga:
  saga emits PostingRequested

on TransactionPosted for that saga:
  saga emits TransferCompleted          -- terminal; saga retires

on any failure event for that saga:
  saga emits compensating events to unwind upstream state
```

Sagas have their own event stream so their state is inspectable and their failures are debuggable like any business aggregate. Common saga aggregate types: `Execute`, `Reversal`, `Cancellation` — one per orchestration shape, not one per business domain.

## 8. Outbox (watermark per stream)

Tracks the high-watermark per stream, not per event. No row-level locks. Multiple instances safely process disjoint sets of streams via consistent hashing.

```
outbox_cursor (
  consumer_name  text         not null,
  stream_id      text         not null,
  last_seq       bigint       not null,
  updated_at     timestamptz  not null default now(),
  primary key (consumer_name, stream_id)
)
```

```
loop every N ms:
  for each stream in my_partition (consistent hashing across instances):
    cursor      = SELECT last_seq FROM outbox_cursor
                  WHERE consumer_name = ? AND stream_id = ?
    new_events  = SELECT * FROM events
                  WHERE stream_id = ? AND seq > cursor
                  ORDER BY seq
                  LIMIT batch_size
    for event in new_events:
      handle(event)
      UPDATE outbox_cursor SET last_seq = event.seq, updated_at = now()
        WHERE consumer_name = ? AND stream_id = ?
```

Reasonable intervals: ~100ms for latency-critical services, 1–3s for non-critical projections. **Do not** use `SELECT FOR UPDATE` row locks per event — under load you get lock congestion, long-held transactions, and queue buildup.

## 9. Snapshotting (long-lived aggregates)

For aggregates where streams grow into the thousands of events (accounts, customers, anything that lives years), write a snapshot every N events. Load the most recent snapshot, then ≤N events on top.

```
snapshots (
  stream_id    text         not null,
  seq          bigint       not null,
  state        jsonb        not null,
  taken_at     timestamptz  not null default now(),
  primary key (stream_id, seq)
)
```

```
function load_aggregate(stream_id):
  snapshot     = SELECT * FROM snapshots
                 WHERE stream_id = ? ORDER BY seq DESC LIMIT 1
  events_after = SELECT * FROM events
                 WHERE stream_id = ? AND seq > snapshot.seq
                 ORDER BY seq
  state = snapshot.state
  for event in events_after:
    state = apply(state, event)
  return state, snapshot.seq + len(events_after)
```

Snapshot writer (separate process, **NOT** in the write transaction):

```
on every Nth event for a stream:
  state = load_aggregate(stream_id)
  INSERT INTO snapshots (stream_id, seq, state) VALUES (?, ?, ?)
```

Reasonable cadence: every ~100 events. The snapshot is a derived view; rebuild it asynchronously so projection performance never blocks the critical write path.

## 10. Crypto-shredding for GDPR

Encrypt PII fields with per-user keys at write time. Destroy the key on erasure request.

```
PII_FIELDS = ["name", "email", "address", "phone", "free_text"]    -- per event type

function append_event_with_pii(stream_id, event):
  user_id = event.user_id
  key     = kms.get_or_create_key("user:" + user_id)
  for field in PII_FIELDS:
    if event.has(field):
      event[field] = encrypt(event[field], key)
  event_store.append(stream_id, event)
```

```
function read_event(raw_event):
  user_id = raw_event.user_id
  key     = kms.get_key("user:" + user_id)
  if key is null:
    return raw_event.with(forgotten = true)        -- key destroyed; PII stays as ciphertext
  for field in PII_FIELDS:
    if raw_event.has(field):
      raw_event[field] = decrypt(raw_event[field], key)
  return raw_event
```

```
function forget(user_id):
  kms.destroy_key("user:" + user_id)
  audit_log.record(user_id, "key_destroyed", at = now())
```

Per-user keys, not per-event or global. Per-event would require deleting events; global would mean forgetting one user destroys all data. See [`gdpr-and-deletion.md`](gdpr-and-deletion.md) for the full menu of techniques and when to choose which.

## 11. UI subscription pattern

After the projector commits, broadcast on a topic. UI clients subscribed to relevant topics receive the push.

```
-- in the projector
on_commit(activity_row):
  pubsub.publish("activity:" + activity_row.membership_id,
                 {kind: "row_inserted", row: activity_row})


-- in the UI / LiveView / WebSocket handler
on_mount(membership_id):
  subscribe("activity:" + membership_id)
  initial_rows = read_model.activity.where(membership_id = ?).order_by(occurred_at desc)
  render(initial_rows)

on_message({kind: "row_inserted", row}):
  prepend_to_view(row)
```

Both the user who triggered the action and any other observer of the same data receive the same push. There's no special path for "the writer" — everyone gets updates the same way.

## Notes on tooling

The patterns here don't depend on a CQRS framework. SKILL.md recommends a default to reach for when you need one (Postgres + DIY for most things; EventStoreDB / Kurrent when you need clustering + subscriptions out of the box). Other options as of 2026:

- **[EventStoreDB / Kurrent](https://kurrent.io)** (cross-language) — purpose-built event store, client SDKs in most languages.
- **[Marten](https://martendb.io)** (.NET / Postgres) — used by the Critter Stack; pairs ES with `Ecto.Multi`-style transaction composition.
- **[Commanded](https://github.com/commanded/commanded)** (Elixir) — most mature option in the BEAM ecosystem.
- **[Axon Framework](https://www.axoniq.io)** (Java) — commercial, mature; introduced "Dynamic Consistency Boundary" in v5 to make aggregate-shape decisions less permanent.
- **[Emmett](https://github.com/event-driven-io/emmett)** (Node.js) — lightweight TypeScript event-sourcing library; opinionated, fits well alongside Postgres.
