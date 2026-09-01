# Reliable Email-First Hermes

## Current State

Hermes and its durable mail bridge run continuously on Fly.io in `sjc`.

- Address: `coach@the1000club.fit` through Resend.
- Hermes: `the1000club-hermes` in the `the1000club` organization, one private
  Machine with 2 GB RAM and an encrypted 5 GB volume.
- Mail bridge: `the1000club-mail-bridge`, one public Machine with 512 MB RAM and an
  encrypted volume. It is the only email transport owner.
- Sender policy: only configured senders and the exact coach recipient reach
  Hermes. Resend's root-domain catch-all does not broaden that policy.
- Backups: Hermes uploads daily full backups to Tigris. Litestream continuously
  replicates the bridge SQLite database to its private Tigris bucket. Fly volume
  snapshots retain 30 days.
- Vagrant: halted and retained only as a pre-schema-upgrade rollback source. It
  must never run concurrently with the Fly gateway.

## Reliability Contract

### Inbound mail

- Accept only signed Resend `email.received` webhooks.
- Check sender and recipient allowlists before retrieving content.
- Download and store the exact raw MIME before returning HTTP 200.
- Deduplicate repeated webhook delivery by Resend email ID.
- Lease one accepted message to Hermes at a time. Expired or released leases
  return to the queue.
- Acknowledge unauthorized and oversized messages without exposing them to
  Hermes or blocking later mail.

### Replies

- Queue replies and proactive mail in SQLite before delivery.
- Use one stable idempotency key for every logical outbound message.
- Preserve `In-Reply-To` and `References` for threading; Resend owns the
  outbound `Message-ID`.
- Retry temporary provider failures with backoff and dead-letter permanent
  failures.
- Send one final-answer email per Hermes turn.

### Retention and recovery

- Retain raw MIME, attachments, queue metadata, and replies indefinitely when
  `BRIDGE_RETENTION_DAYS=0`.
- Restore backups into temporary storage first, run SQLite integrity checks,
  and compare inventories before replacing production state.
- Never overwrite or delete a production database or volume during a restore
  exercise.

This is restore-based durability, not high availability. Both services use one
local Fly Volume and asynchronous Tigris replication. Resend's send idempotency
window is 24 hours, so a retry after that window can rarely duplicate an
accepted send.

## Operations

```bash
curl --fail --silent https://the1000club-mail-bridge.fly.dev/healthz | jq
fly status --app the1000club-mail-bridge
fly status --app the1000club-hermes
fly logs --app the1000club-mail-bridge
fly logs --app the1000club-hermes
```

Deployment, backup, restore, and upgrade commands live in
[`fly/README.md`](./fly/README.md). Hermes upgrades remain manual, pinned, and
backup-gated.
