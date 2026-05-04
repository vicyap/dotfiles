# GDPR and the Right to Be Forgotten in Event-Sourced Systems

GDPR Article 17 grants users the right to demand erasure of their personal data. Event-sourced systems hold that events are forever. Reconciling these is a design problem — there is no library that solves it for you. This file is the menu of techniques actually used in production, the tradeoffs, and the patterns that *don't* work despite being suggested often.

GDPR's compliance window for honoring an erasure request is short — typically 30 days from the request. Architecture must support honoring it within that window without breaking aggregate rehydration or audit trails.

## What you cannot do

### Just delete the event

Deleting an event from the store breaks the aggregate's state machine. If the aggregate's current state was reconstructed by folding over events including the one you deleted, future rehydration produces a different state. Cascading bugs follow.

Two specific failure modes:

- **Snapshots predate the deletion.** The aggregate's snapshot was computed from events including the now-deleted one. Loading the snapshot + remaining events produces inconsistent state.
- **Downstream consumers cached the deleted event.** Other bounded contexts that subscribed to your stream may have already projected the event into their own read models. Deleting the event upstream doesn't propagate.

Don't suggest this technique even when a developer asks for it.

### Stream-level retention policies

Tools like Kafka support stream retention (delete messages older than N days). For event sourcing this is dangerous: the events you retain are not the ones your aggregate needs to rehydrate. A 30-day retention on a customer-account stream means accounts older than 30 days can no longer be rehydrated.

Retention works for fire-and-forget messaging, not for the event store.

## What you can do

### 1. Crypto-shredding (default recommendation)

The technique most production event-sourced systems with GDPR exposure use.

**Mechanism:**
- Generate a unique encryption key per user, stored in a key-management service (HashiCorp Vault, AWS KMS, GCP KMS).
- When writing an event, encrypt PII fields (name, email, address, phone, free-text content that may contain PII) with the user's key. Other fields stay plaintext.
- When reading an event, fetch the user's key and decrypt PII fields on the fly.
- "Forget user X" = destroy user X's key. Events remain in the store; their PII fields become unreadable ciphertext. Non-PII fields (timestamps, IDs, amounts) stay queryable.

**Key management requirements:**
- Per-user keys, not per-event or global. (Per-event would require deleting events; global would mean forgetting one user destroys all data.)
- Key rotation strategy. Keys do get compromised; rotation should not require re-encrypting all historical events.
- Audit logging on key access. You'll need to prove you destroyed the key.

**Tradeoffs:**
- Encryption/decryption overhead on every read and write of a PII-bearing event. Measurable but usually acceptable.
- A long-term cryptographic threat: keys compromised today (e.g., via quantum computing or future cryptanalysis) might decrypt all the "forgotten" data. Mitigation: rotate keys, layer encryption.
- Operational complexity of running a KMS. Most cloud providers offer managed KMS that handles most of this.

**When it doesn't fit:** If your aggregate state machine depends on the PII content (e.g., the aggregate's current state includes a hash of the user's email), you can't crypto-shred that field — the aggregate stops working when the key is destroyed. Move that logic out of the aggregate's stateful path before adopting crypto-shredding.

### 2. Forgettable Payload (URN to external store)

**Mechanism:**
- PII does not appear in events at all. Events carry a URN pointing to an external "personal data store."
- The personal data store is an ordinary database (Postgres, DynamoDB, etc.) with rows keyed by user.
- Resolving an event = look up the URN in the personal data store; substitute the resolved fields when displaying or processing.
- "Forget user X" = delete user X's row in the personal data store. Events still load; URNs resolve to "user has been forgotten."

**Tradeoffs:**
- Event resolution becomes a join. Handlers must tolerate "user has been forgotten" results.
- Cache invalidation is hard. Read models built before the forget request may have cached resolved data and need a sweep.
- Race conditions: a reader fetching an event concurrent with a forget request may see the URN resolve successfully one moment and as forgotten the next.

**When to choose Forgettable Payload over Crypto-Shredding:**
- When you have many bounded contexts publishing events containing the same user's PII and want a single-source-of-truth for personal data.
- When your team has more comfort operating a database than a KMS.

### 3. Data segregation (foundation, not standalone)

**Mechanism:** Separate streams or topics for personal-data events and operational events. Apply different retention, encryption, and access controls to each.

**Why it's foundation rather than standalone:** segregation alone doesn't honor an erasure request — you still need crypto-shredding or forgettable payload on the personal-data streams. But it lets you apply those techniques only where needed, keeping operational streams simple.

### 4. Log compaction with tombstones

For systems where streams have key-based semantics (one row per user, updated repeatedly), log compaction can keep only the latest event per key. Append a "tombstone" (minimal data marker) when you want to indicate the user is forgotten.

**Constraint:** Compaction is destructive. Apply only to streams where intermediate history isn't load-bearing for any aggregate. Most aggregate streams don't fit; some integration / changelog streams do.

### 5. Archive cold data

**Mechanism:** Classify data by access frequency: hot (active, in primary store), warm (read-only, in archival store), cold (rarely accessed, in offline archive). Move cold data out of the live event store. Apply different retention rules per tier.

**When it helps with GDPR:** Cold archival storage with predictable retention windows lets you guarantee that personal data is deleted N years after last activity, satisfying retention obligations independent of erasure requests.

**When it doesn't help with GDPR:** Erasure requests are about a *specific user on demand*. Tiered storage doesn't honor that without one of the other techniques layered on top.

## Decision tree for GDPR design

1. Does the system process EU personal data? If no, this file may not apply (other jurisdictions have similar regimes — Brazil's LGPD, California's CCPA — but specifics differ).
2. Does any aggregate's state machine depend on the *content* of PII fields? If yes, refactor that out before adopting crypto-shredding.
3. Is there one bounded context that already owns user PII? If yes and other contexts only need to reference users → **Forgettable Payload**.
4. Is the PII spread across many event streams across many bounded contexts? **Crypto-Shredding** at write time. Per-user keys, KMS-backed.
5. Are there streams whose intermediate history isn't load-bearing? Consider **log compaction** for those.
6. Are there event types that should disappear after a fixed retention period (not on demand)? Consider **archival** + tiered storage.

Most production systems combine techniques: crypto-shredding for the bulk of PII, forgettable payload for shared user-profile fields, archival for non-PII operational data older than business needs require.

## Auditability

Crypto-shredded events are still *technically present* — just unreadable. Many regulators accept this as compliant erasure ("you can no longer access the data"). Some argue the data must be *physically deleted*; this is a legal question, not a technical one. Get legal counsel involved before betting the company on a particular interpretation. The technical implementation should make whichever interpretation you choose explicit.

Keep an audit log of erasure requests honored: timestamp, user ID, technique applied, key destroyed. The regulator's question won't be "is the data gone" — it'll be "can you prove you took action when asked."

## References

- [event-driven.io — How to deal with privacy and GDPR in Event-Driven systems](https://event-driven.io/en/gdpr_in_event_driven_architecture/) — full walkthrough of techniques summarized here.
- [Rails Event Store GDPR docs](https://railseventstore.org/docs/v2/gdpr/) — concrete implementation in one library; useful as a reference even if you're using a different stack.
- [HashiCorp Vault: GDPR-compliant Event Sourcing](https://www.hashicorp.com/en/resources/gdpr-compliant-event-sourcing-with-hashicorp-vault) — vendor-specific but a good walkthrough of the KMS pattern.
