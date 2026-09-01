# Workout Email Logging Through the Mail Bridge

The mail bridge delivers the complete inbound MIME, parsed body, subject, and
cached attachments to Hermes. Treat that event as the source of truth.

1. Use the plain-text body and `[Subject: ...]` context; ignore quoted reminder
   text except where it clarifies an exercise.
2. Save useful cached attachments under
   `$HERMES_HOME/data/workout_attachments/YYYY-MM-DD/`.
3. Update `$HERMES_HOME/data/workout_log.csv` idempotently. Its existing columns
   are authoritative.
4. Reply normally through the active email platform. It preserves threading and
   queues delivery through `POST /v1/replies`.

Never poll a mailbox or send with IMAP/SMTP from Hermes. If mail is missing,
report the bridge symptom so the operator can inspect the bridge queue.
