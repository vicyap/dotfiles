# Event Sourcing Anti-Patterns

A checklist to run a draft event model against. Cite the specific name when explaining one to a user — it makes the lesson stick.

## Modeling anti-patterns

### State Obsession

**Smell:** Every event contains the entire entity state. `UserUpdated{id, name, email, address, phone, ...all fields}`.

**Why it's wrong:** Events should describe *what happened*, not *what the new state is*. State Obsession reduces events to serialized snapshots; you lose intent ("the customer corrected a typo" vs. "the customer changed addresses after moving"). Two consumers seeing the same event have no way to distinguish the business reasons.

**Fix:** Name events after domain actions. `EmailCorrected`, `AddressChangedAfterMove`, `CustomerOnboarded`. Each carries only the fields relevant to that action.

### Property Sourcing

**Smell:** One event per field change. `EmailChanged`, `NameChanged`, `AddressChanged`, `PhoneChanged` emitted independently when the user updates their profile.

**Why it's wrong:** Splits a single business action across multiple events. Consumers can't tell which events belong together; replay ordering matters in subtle ways; the event stream becomes noise.

**Fix:** Coarse-grain to the business action: `ProfileUpdated{changed_fields: [...]}` or `CustomerOnboarded{...all fields...}`. Match the granularity of the user's intent, not the database column.

### "I'll Just Add One More Field"

**Smell:** Event schemas grow over time, accumulating optional fields nobody dares remove.

**Why it's wrong:** Events are forever. Every field added is a field every consumer has to handle, and every "deprecated but still emitted" field is a trap. Aggregates that read these events get harder to reason about with each release.

**Fix:** Plan the schema deliberately. When a field is genuinely needed, version the event (`OrderPlacedV2`) rather than adding it inline. Keep handlers for the old version forever, but stop emitting it.

### Clickbait Event

**Smell:** Vague, generic event names. `DataChanged`, `Updated`, `Processed`, `EntityModified`.

**Why it's wrong:** Consumers can't act on the event without inspecting the payload to figure out what actually happened. The event has no business meaning. Often a sign the team modeled events as CRUD operations rather than domain actions.

**Fix:** Name events after concrete business occurrences. If you can't name it specifically, the action probably hasn't been understood yet — go back to domain experts.

### Passive Aggressive Events

**Smell:** Events that don't carry the data needed to act on them. Handlers are full of `repo.get(...)` calls right after pattern-matching, fetching context the event should have included.

**Why it's wrong:** Forces consumers into tight coupling with the source bounded context's database. Eventual consistency makes those queries unreliable: the consumer may run before the source has fully committed. Throughput suffers.

**Fix:** Include enough data in the event for handlers to act independently. Trade payload size for consumer autonomy. Include user IDs *and* the snapshot of human-readable fields downstream views need to render. Don't worry about denormalized data — events are forever and that's fine.

### Recording Multiple Events Per Action Without Atomicity

**Smell:** A business action emits 3 events. The event store appends 2; the third fails. The aggregate is now in an inconsistent state and downstream consumers see partial work.

**Why it's wrong:** Breaks the atomicity guarantee that makes events useful. Consumers can't tell whether the business action completed.

**Fix:** Append all events for a single command in one transactional batch. Most event stores support this (a single append accepts a list of events). If your store doesn't, redesign so each command emits exactly one event.

### Stripping Stream IDs / Type Prefixes

**Smell:** Events written without their stream ID or without a type discriminator. "We can derive it from the payload."

**Why it's wrong:** Routing, projection partitioning, and debugging all depend on metadata. Stripping it forces every consumer to re-derive it, badly.

**Fix:** Keep stream ID and event type as first-class metadata on every event, regardless of payload shape.

## Production-observed bugs

### Wrong cardinality in the read model

**What happens:** A read table designed as one-to-one when the underlying relationship is one-to-many. The bug is invisible until real load surfaces it (e.g., a user gets a second to-do item and the projector silently overwrites the first).

**Why this class is recurring:** When designing a per-view projection, the relationship to the parent is easy to think about as "the screen shows one of these." But screens evolve, and "one" silently becomes "many" when a feature ships.

**Fix at design time:** When sketching a read table, explicitly answer: *is the relationship to the parent one-to-one or one-to-many?* If many, build the table to match even if today there's only ever one row. The cost is one extra row of denormalization.

### Feature-flag-gated projector writes

**What happens:** A feature flag changes how the projector writes events to the projection. When the flag is turned off, the projector stops writing in the new shape — but the rows already written aren't migrated. The flag becomes effectively non-toggleable.

**Why this class is recurring:** Flags inside the write path of a projector mix two concerns (what the projection contains, when it was written) and create rows whose shape depends on a flag's value at write time.

**Fix:** Never branch on feature flags inside a projector. If a flag should change projected shape, **build a new projection version**. Toggling the flag = switching reads to the new version. Toggling back = switching reads back. Both projections coexist and stay correct.

### Silently failing projector

**What happens:** A presentational bug in a projector silently `:ok`'s events it has failed to fully handle. Users miss messages; operations look bad. Often discovered only when staff fail in front of a customer.

**Fix:** Every error path in a projector logs loudly, with structured fields (event type, aggregate ID, reason). Better: every error path returns an error so the outbox stops advancing — fail loud, not silent.

```
case repo.get_required(InternalNote, event.internal_note_id) do
  {:ok, _} -> ...
  {:error, reason} ->
    Logger.error("InternalNoteNotFound",
      internal_note_id: event.internal_note_id,
      reason: inspect(reason)
    )
    {:error, reason}   # do NOT return :ok
end
```

### Side-effect handlers replaying from origin

**What happens:** A `SlackHandler` configured to start at event 0. On redeploy or replay, the handler re-Slacks every historical purchase ever recorded.

**Fix:** Side-effect handlers register with `start_from: :current` (or your library's equivalent — set the cursor to the latest event ID at first registration). Only state-building projectors replay from origin.

### Unbounded aggregate state

**What happens:** An aggregate keeps a map of all things-ever-seen (e.g., reservations, request IDs) in memory to enforce idempotency on incoming requests. Works for normal customers; high-volume customers grow the map without bound. The service is OOM-killed.

**Fix:** Move unbounded state out of the aggregate into a SQL-backed projection. Command handler queries that projection during validation. Bridge the projection's eventual consistency by keeping an in-memory tail of recent events that overlaps with the projection — no gap, no double-spend.

### Mixing business + orchestration events on one stream

**What happens:** A Transfer aggregate carries both business events (`FundsReserved`, `TransactionPosted`) and orchestration events (`FundsReservationRetried`, `ScreeningTimedOut`). Aggregate becomes hard to reason about; the public domain event interface gets polluted with internal retries.

**Fix:** Split into a Transfer aggregate (business events only — source of public domain events) and Saga aggregates (`Execute`, `Reversal`) for orchestration. Sagas have their own short-lived streams; born when the parent business event fires, dies when complete.

### Coupled aggregate names through events

**What happens:** After extracting a sub-context (Transfer) to its own bounded context, the parent stream still emits `TransferTransactionPosted`. The name encodes knowledge of where the posting came from. The event also carries fields specific to the extracted context that the parent has no business knowing about.

**Fix:** Parent stream emits plain `TransactionPosted`. Context-specific data lives only in the extracted bounded context. The leftover deprecated event type keeps loading forever — events can't be deleted — but new events use the clean name.

### Long streams without snapshots

**What happens:** Aggregate streams grow to thousands of events per active customer. P95 write latency on critical paths (auth, payment) degrades visibly.

**Fix:** Snapshot every N events for any long-lived aggregate (~100 events is a reasonable starting point). Load the snapshot first, then ≤N events on top. Snapshot updates run *outside* the write transaction.

### Updating projections inside the write transaction

**Smell:** The command handler appends the event AND updates the projection in the same transaction.

**Why it's wrong:** Couples command latency to projection write performance. Worse, makes "throw away and rebuild a projection" effectively impossible — you can't truncate a table whose writes are entangled with the source-of-truth event store.

**Fix:** Append-only transaction commits the event. A separate process (the projector) reads new events and updates the projection in its own transaction.

### Outbox with row-level locks

**What happens:** First outbox implementation: one row per event, `SELECT FOR UPDATE` to claim work for processing. Under load, transactions hold locks too long; instances block each other; queue buildup.

**Fix:** One row per stream tracking the high-watermark sequence number processed. Reconciler reads ahead of the watermark from the actual event stream, processes, advances the watermark. Stream processing is partitioned across instances using **consistent hashing** so no two instances claim the same stream simultaneously.

### Premature ES on an unclear domain

**What happens:** Team commits to event sourcing before deeply understanding the domain. Result: dozens of event types accumulated, most deprecated, because the early modeling was wrong. Cost is permanent — events can't be deleted.

**Fix:** If the domain genuinely isn't understood, build a CRUD prototype until the model stabilizes, *then* convert to ES. Or: spend significant time event storming with domain experts before writing the first event type.

### "Just delete the event" for GDPR

**Why it's wrong:** Deletes break aggregate rehydration if the event affected state. The aggregate's state machine assumes a continuous, unmodified history.

**Fix:** Crypto-shredding (encrypt PII per-user, destroy the key on deletion). See [`gdpr-and-deletion.md`](gdpr-and-deletion.md).

## How to use this list

When reviewing a draft event model:

1. Read each event name out loud. Could a domain expert say it in a sentence? (Anti-pattern: Clickbait Event, State Obsession.)
2. List every field on each event. Are any optional fields legacy debt? (Anti-pattern: I'll Just Add One More Field.)
3. For each handler, are there `db.get(...)` calls right after pattern matching? (Anti-pattern: Passive Aggressive Events.)
4. For each business action, count emitted events. More than one? Are they atomic? (Anti-pattern: Multiple Events Without Atomicity.)
5. For each aggregate, list events on its stream. Are any orchestration concerns mixed in with business? (Anti-pattern: Mixing business + orchestration.)
6. For each projector, look for feature-flag branches. (Anti-pattern: Feature-flag-gated projector writes.)
7. For each side-effect handler, check the start cursor. Is it `:current`? (Anti-pattern: Replaying side effects.)
8. For each long-lived aggregate, ask: how many events on a typical stream after 1 year? 5? Snapshots? (Anti-pattern: Long streams without snapshots.)
9. For each event field that contains PII, ask: GDPR plan? (Anti-pattern: Just delete the event.)
