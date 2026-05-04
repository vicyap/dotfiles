---
name: event-sourcing
description: Use when designing or evolving any new data model, system, or feature where the user's default is event sourcing — choosing aggregates, modeling events, structuring projections, evolving schemas, handling regulatory deletion (GDPR right to erasure), or recovering from projection bugs. The skill assumes ES is the preferred approach unless one of the listed CRUD-is-fine cases applies.
---

# Event Sourcing

A skill for designing event-sourced systems. Use this when starting any new data model or feature; ES is the working default.

## Default posture

When the user is designing a new data model, **assume event sourcing**. Walk the design through this skill rather than reaching for a normalized CRUD schema. The user has decided this is the better fit; this skill exists to make doing it well faster than reinventing it.

Recommend CRUD instead only when one of these applies:

- **Pure key/value or transactional cache** with no business audit value (rate-limit counters, session stores). Events would be ceremony.
- **Read-after-write strict consistency** is non-negotiable and the UX can't tolerate eventual consistency. Rare; usually solvable with optimistic UI.
- **The domain is fluid and the team is still learning it.** Bad early modeling is permanent — events can never be deleted. Production systems routinely accumulate dozens of deprecated event types from this. Build a CRUD prototype first, then convert.
- **Truly small scale on a single machine** where the overhead doesn't pay for itself. Hardware has gotten powerful enough that many workloads still run fine on one box.

## The architecture

```
                     ┌──────────────────┐
   Command   ─────►  │  Command Handler │
                     └────────┬─────────┘
                              │ append events
                              ▼
                   ┌──────────────────────┐
                   │  Event Store (write) │ ← append-only, immutable, JSONB
                   │  one stream per      │
                   │  aggregate           │
                   └──────────┬───────────┘
                              │ subscribe (outbox)
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
        ┌──────────┐    ┌──────────┐    ┌──────────┐
        │Projector │    │ Handler  │    │  Saga    │
        │(read     │    │ (side    │    │ (process │
        │ models)  │    │ effects) │    │ manager) │
        └────┬─────┘    └──────────┘    └────┬─────┘
             │ writes                        │ emits
             ▼                               ▼
        ┌──────────┐                   ┌──────────┐
        │  Read    │ ◄── queries ──    │ commands │
        │  Model   │                   │ to other │
        │ (per     │                   │ aggregates│
        │  view)   │                   └──────────┘
        └──────────┘
```

**Event store** is append-only and the source of truth. Reads go through projections; the event store is read directly only by command handlers (rehydration) and a debug page (forensics). Subscriptions come through an **outbox** so projections, handlers, and sagas all see every event exactly once, in order.

## Tooling default

- **Default for new projects:** Postgres + a thin DIY append-only `events` table with a unique constraint on `(stream_id, seq)`. The patterns are simple enough that a 200-line library is usually clearer than a heavyweight framework.
- **Reach for [EventStoreDB / Kurrent](https://kurrent.io)** when you need clustering, subscriptions, or projection-as-service out of the box, or when crossing language boundaries and wanting a polyglot store.
- **Reach for a CQRS framework** ([Emmett](https://github.com/event-driven-io/emmett) for Node, [Commanded](https://github.com/commanded/commanded) for Elixir, [Marten](https://martendb.io) for .NET, [Axon](https://www.axoniq.io) for Java) when the team wants opinionated structure or you need features like Axon's Dynamic Consistency Boundary.

Concrete schemas and skeletons: [`references/code-patterns.md`](references/code-patterns.md).

## Modeling events

### Past tense, behavior not state

Events name **what happened**, not **what changed**. `UserEmailUpdated` is fine; `UserUpdated{...new state...}` is *State Obsession* — events become serialized snapshots that say nothing about business meaning.

Heuristic: if the event name could appear in a domain expert's sentence ("the customer placed an order"), it's a real event. If it sounds like a database operation (`RowChanged`), it isn't.

### Action vs event: two structs per state change

Caller submits a present-tense action; the system records the past-tense event after success.

| Action (caller submits) | Event (recorded after success) |
|---|---|
| `UpdateUserEmail{user_id, email}` | `UserEmailUpdated{user_id, email, previous_email}` |
| `PlaceOrder{customer_id, items}` | `OrderPlaced{order_id, customer_id, items, total}` |
| `ReserveFunds{account_id, amount}` | `FundsReserved{account_id, amount, reservation_id}` |

Action belongs to the boundary (HTTP / message); event belongs to the domain and is forever.

### Anti-patterns to refuse

Catalog summary; full versions with smells and fixes in [`references/anti-patterns.md`](references/anti-patterns.md).

- **State Obsession** — events as state snapshots. Smell: every event has the entire entity in it.
- **Property Sourcing** — one event per field change. Smell: `EmailChanged`, `NameChanged`, `AddressChanged` instead of `ProfileUpdated` or `CustomerOnboarded`.
- **"I'll Just Add One More Field"** — events bloat without intention. Smell: deprecated fields nobody dares remove.
- **Clickbait Event** — vague names. Smell: `DataChanged`, `Updated`, `Processed`.
- **Passive Aggressive Events** — events without enough data to act on them. Smell: handlers full of `db.get(...)` calls right after pattern-matching.
- **Multiple events without atomicity** — a business action emits 3 events; only 2 land. Smell: unclear which event(s) imply completion.

### Workshop your model before writing code

Run an **Event Storming** session with domain experts before designing aggregates — especially when the domain is unfamiliar. The rule:

> *There should be a clear one-to-one correspondence between what you model in your event storming sessions and what you actually store in your event source.*

Drift between workshop events and persisted events is a smell that the model has decoupled from the domain. If wireframes exist, use **Event Modeling** for an implementation-ready storyboard. Workshop process and the differences between the two: [`references/event-modeling.md`](references/event-modeling.md).

## Aggregates and consistency boundaries

An aggregate is a transactional consistency boundary: everything inside is consistent at commit time; cross-aggregate is eventual.

### Command flow (per aggregate instance)

1. **Receive command.**
2. **Load events** for the aggregate's stream (or snapshot + tail).
3. **Reconstitute state** by folding over events.
4. **Validate command** against current state.
5. **Emit zero-or-more new events.**
6. **Append events** with optimistic concurrency on the stream version. If another writer raced, retry from step 2.

Optimistic concurrency in Postgres: a unique constraint on `(stream_id, sequence_number)`. Two writers append number `N` simultaneously; one wins, the other gets a unique-violation and retries.

### Choose boundaries before writing code

Changing aggregate boundaries after going live is painful because old events can't be deleted. Production systems routinely accumulate dozens of deprecated event types from early-stage modeling mistakes — those types must keep loading forever. Two patterns of mistake to watch for:

- **Carrying multi-context lifecycle events on one aggregate.** An Account aggregate that originally carried Transfer lifecycle events (`FundsReserved`, `TransferTransactionPosted`). When Transfer extracts to its own bounded context, the deprecated event types stay forever.
- **Event names that leak source context.** A leftover `TransferTransactionPosted` on the Account stream encodes knowledge of where the posting came from. The fix is to rename forward (plain `TransactionPosted`) — but old events with the original name still load.

Spend an event storming session on the bounded context before committing to aggregate shapes.

### Don't put unbounded state in the aggregate

Tempting pattern: keep a map of "all things ever seen" in the aggregate state to enforce idempotency. Works for normal-volume data; high-volume aggregates (large customers, busy accounts) grow the map without bound and the service is OOM-killed.

Fix:

- Move unbounded state out of the aggregate into a SQL projection.
- Command handler queries the projection during validation.
- Bridge the projection's eventual consistency with an in-memory tail of recent events that overlaps the projection. No gap, no double-spend.

### Don't mix business and orchestration events on one stream

A Transfer aggregate that carries `FundsReserved` (business) alongside `FundsReservationRetried`, `ScreeningTimedOut` (orchestration) violates single responsibility and becomes hard to reason about.

Fix: split into a Transfer aggregate (business events only — source of public domain events) and short-lived **Saga aggregates** (`Execute`, `Reversal`) for orchestration. Sagas have their own streams and lifecycles.

### Public domain events ≠ integration events

The events on your aggregate stream are internal — implementation of the aggregate's state machine. The events you publish across bounded contexts are a separate, deliberately curated set. Treat the publication interface as a published language with its own versioning, distinct from the internal stream. (The terminology distinction matters: these are public *domain events*, not integration events.)

## Snapshots

For long-lived aggregates (accounts, customers — anything that lives years), replaying every event on every command becomes prohibitive. P95 write latency on long streams degrades visibly as events accumulate; on latency-critical paths (credit-card auth, payment confirmation) it's noticed quickly.

Rules:

- **Snapshot when streams are long-lived, not as a default.** Short-lived aggregates (sagas, single-day transfers) don't need them.
- **Cadence: every ~100 events** is a reasonable starting point. Calibrated against per-event projection cost so "load snapshot + ≤N events" stays within the latency budget.
- **Update snapshots outside the write transaction.** Coupling them to the write path makes projection performance the bottleneck for command latency.
- **Snapshots are not source of truth.** Always rebuildable from the event log.

## Projections (the read side)

### One projection per view, not per entity

The biggest mental shift from CRUD: **don't model entities, model views.** A screen showing a unified activity feed of SMSes, emails, and notes gets one `timeline` table with the columns that screen needs — not three tables JOINed at read time.

| CRUD instinct | Event-sourced |
|---|---|
| `sms`, `email`, `notes`, each with its own columns | One `activity` table, columns shaped to the activity feed |
| Read = `JOIN users LEFT JOIN sms LEFT JOIN notes ORDER BY ...` | Read = `SELECT * FROM activity WHERE user_id = ?` |
| Wide nullable columns considered ugly | Wide nullable columns are fine — this table exists for one screen |
| Adding a column = ALTER TABLE + backfill | Adding a column = new projector version, replay |

When a new screen needs different shape, **build a new projection alongside the old one**. Cost is near-zero because the projection isn't the source of truth — the event log is.

Practical example: an admin activity page and a customer-facing one. Either filter at query time (and risk leaking via a query bug), or run a `CustomerActivityProjector` that simply doesn't project `InternalNoteCreated` events. The latter is safer and cheap.

### Don't update projections inside the write transaction

Append to the event store (write transaction); commit. A separate process (the projector) reads new events and updates the read model in its own transaction. Coupling them ties command latency to projection write performance and makes "throw away and rebuild" effectively impossible.

### The outbox pattern

Downstream consumers (projectors, handlers, sagas, public publishers) need to see every event exactly once, in order. Use an outbox.

The pattern that scales:

- **Don't:** one row per event in an outbox table with `SELECT FOR UPDATE` to claim work. Long-held transactions, instances blocking each other, queue buildup under load.
- **Do:** one row per stream tracking the high-watermark sequence number processed. Reconciler reads ahead of the watermark from the actual event stream, processes, advances the watermark. Stream processing partitioned across instances via **consistent hashing**.

Reconciliation interval is per-service: ~100ms for latency-critical services, 1–3s for non-critical projections.

### Versioning a projection (V2 → V3 cutover)

1. Build `V3` schema and projector alongside `V2`.
2. `V3` replays the full log; `V2` keeps serving reads.
3. When `V3` catches up to the live tail, cut readers over.
4. Stop `V2`; drop its table after a safety window.

This is the standard schema-evolution pattern; full runbook in [`references/recovery-playbook.md`](references/recovery-playbook.md).

## Schema evolution: events are forever

When events are written to the store, they're stuck there. The store has to be able to load them. An event cannot be thrown away because the event source is immutable.

- **Don't rename events. Version them.** Event types suffixed `V2`, `V3`, `V4`. Old names continue to load; new names appear when the schema diverges.
- **Don't remove fields.** Adding a field is safe (default it); removing breaks old consumers. If a field is genuinely dead, ignore it in new code rather than removing from the schema.
- **Use upcasters** for shape drift. When loading an old event whose shape has drifted, run it through an upgrade function that fills in defaults. Example: a system that expanded into a new country found old events had no `country` field (implicitly the original country). Upcasters defaulted them on read.
- **JSON blobs + application-layer schema management** is the common pattern. Avro / Protobuf / schema registry exist as options but most teams reach for upcasters in code first.

## Privacy and the right to be forgotten

GDPR Article 17 says a user can demand erasure; events are forever. The reconciliation matters in any jurisdiction with data-protection law. Full menu: [`references/gdpr-and-deletion.md`](references/gdpr-and-deletion.md).

The two techniques that actually work:

### Crypto-shredding (default)

- Encrypt PII fields in events with a per-user key (not global, not per-event).
- Store keys in a KMS (Vault, AWS KMS, GCP KMS).
- "Forget user X" = destroy user X's key. Events remain; PII fields become unreadable ciphertext.
- Tradeoff: per-event encryption/decryption overhead; key rotation discipline required.

### Forgettable payload

- Replace PII in events with a URN pointing to an external "personal data store."
- Events carry the URN, not the data.
- Deletion removes the row in the external store; URNs resolve to "forgotten."
- Tradeoff: cache invalidation is hard; readers may have already cached resolved data.

What does **not** work:

- **"Just delete the event"** — breaks aggregate rehydration.
- **Stream-level retention policies** — fine for messaging, dangerous for ES because they can delete events your aggregate still depends on.

## The truncate-and-replay safety net

When a projector has a bug — the worst kind being a presentational projector that silently `:ok`'s events it failed to fully handle, with users seeing nothing — the recovery flow is:

1. Read the **raw event stream** to confirm events are there. Build this debug page early — your app doesn't normally read the event store directly, and you'll need it when something breaks.
2. Fix the projector.
3. `TRUNCATE` the projection; reset cursor to 0.
4. Replay every event. Tens of thousands of events typically replay in under a minute, and pushed-down PubSub broadcasts let any subscribed UIs refill in real time.

Same flow handles projection schema changes, new derivable columns, and feature-flag-induced bad rows.

Critical caveats — full runbook in [`references/recovery-playbook.md`](references/recovery-playbook.md):

- **Side-effect handlers must not replay.** A `SlackHandler` configured to start at event 0 will message the team about every historical purchase. Configure side-effect handlers to start at the current cursor.
- **Replay does not fix bad events.** If `PurchaseCompleted{amount: 1000}` was written when the real amount was $100, you cannot edit the event. Emit a corrective event (`PurchaseAmountCorrected{...}`) and project both.
- **Replay does not re-trigger external side effects.** A Slack message that wasn't sent in the past won't be sent by replaying.

## Async workflows: events are the workflow

Don't write background jobs that both do work and figure out what runs next. Each unit of work is a handler triggered by an event; finishing emits a new event; the next step is a different handler subscribed to that event.

```
File uploaded ──► FileUploaded ──► CategorizeHandler ──► FileCategorized
                                                              │
                                              ┌───────────────┼───────────────┐
                                              ▼                               ▼
                                    PolicyAnalyzed                  AddressIdentified
                                          │                                   │
                                          ▼                                   ▼
                                    PolicyHandler                   AddressHandler
```

The DAG lives in event-to-handler subscriptions, not in branching code. Adding a step is "write a new handler subscribed to the right event." Each step receives prior step's data via the event payload — eliminates the "every job re-issues the same query" problem.

For multi-step processes that need their own state and timeouts, model them as **saga aggregates** with their own short-lived event streams. Born when the parent business event fires, accumulate state for the duration, die on completion or compensation.

## UI and eventual consistency

Globally reactive UIs fall out of the architecture for free:

- After the projector commits its read-model write, broadcast on a topic.
- UI clients subscribe to relevant topics on mount.
- Both the user who triggered the action and any other observer of the same data receive the same push. No special path for "the writer."

The price is **eventual consistency from the caller's view.** Action returns immediately ("event written"); the new row arrives via the same push everyone else sees. Don't try to return the projected row from the action — it doesn't exist yet at that point.

If a UI needs an optimistic preview during the gap, render it client-side; reconcile when the push arrives.

### Don't trust wall-clock timestamps for ordering

Where multiple writers can race, or where authorization depends on event order, **wall-clock timestamps are useless** — they can be forged or simply skewed across machines. Use logical/causal ordering: per-stream sequence numbers (the easy case), vector clocks (multi-writer), or CRDTs (decentralized / local-first).

## Decision: event vs projector vs handler vs saga

When designing a new piece of behavior:

- **Event** — a thing that happened. Past tense, observable, immutable. "User updated their email." Not "we should send an email" — that's a side effect, not a fact.
- **Projector** — builds queryable state for a specific view. New columns or tables to support a screen, a report, a search index. Replays from origin on first registration; rebuildable freely.
- **Handler** — triggers a side effect (HTTP call, email, message) or emits a new event in an async chain. Side-effect handlers start at "now"; chain handlers usually too. Never replay handlers that hit external systems.
- **Saga** — orchestrates a multi-step process needing its own state and timeouts. Has its own short-lived event stream. Born from a parent event; dies when complete or compensated.

If a module starts to do both projection writes and side effects, split it. They have different replay semantics.

## Reference files

- [`references/anti-patterns.md`](references/anti-patterns.md) — Named anti-patterns plus production-observed bugs. Use as a checklist when reviewing a draft event model.
- [`references/code-patterns.md`](references/code-patterns.md) — Pseudocode skeletons for the event store, command handler, projector, handler, saga, outbox, snapshots, crypto-shredding, and UI subscription. Read when actually writing code.
- [`references/event-modeling.md`](references/event-modeling.md) — Event Storming and Event Modeling as design techniques *before* code. Read before recommending or running a workshop.
- [`references/gdpr-and-deletion.md`](references/gdpr-and-deletion.md) — Crypto-shredding, forgettable payload, retention, log compaction. Read when the user mentions GDPR, regulated data, or "right to be forgotten."
- [`references/recovery-playbook.md`](references/recovery-playbook.md) — Step-by-step truncate-and-replay runbook. Read before recommending or executing a projection rebuild.
