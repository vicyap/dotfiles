---
name: fitness-personal-trainer
description: "Coach strength training, log unstructured workout reports and attachments, and maintain adaptive email scheduling."
version: 2.0.0
author: agent
metadata:
  hermes:
    tags: [fitness, strength, powerlifting, tracking, periodization, personal-trainer]
---

# Fitness Personal Trainer

Trigger on workout reports, training questions, proactive training/check-in email replies,
or subjects naming squat, bench, deadlift, or training.

## Durable data

Use `$HERMES_HOME` for every path. Never hard-code a user home directory.

- Workout rows: `$HERMES_HOME/data/workout_log.csv`
- Attachments: `$HERMES_HOME/data/workout_attachments/YYYY-MM-DD/`
- Scheduling helper: `$HERMES_HOME/scripts/training_reminder_dispatcher.py`
- Scheduling state: `$HERMES_HOME/data/training_reminder_state.json`

The mail bridge is the only inbound and outbound email owner. Never use IMAP,
SMTP, Signal, or direct mailbox credentials from Hermes.

## Workout reports

Accept prose, shorthand, pasted tables, screenshots, and other attachments. `+`
between segments means a drop set. Preserve the CSV columns already present in
the log; do not invent a new schema.

Before appending, search the existing rows for the same date, session, exercise,
set number, reps, and load. Reprocessing a message or attachment must not create
duplicate rows. Save useful attachments under the dated attachment directory and
include their relative paths in notes when they contribute workout data.

After logging, read the current scheduling state. Treat a report for the active
plan as completion even when it is terse or does not repeat the email subject.
Use the inbound `[Subject: ...]` line as context, including `Re:` subjects. The
`[Inbound ID: ...]` line is durable operation metadata: pass it to every schedule
or pause command as `--source-id`, and never include it in a coaching reply.

## Active coaching policy

Keep the active rotation `deadlift -> bench -> squat`. Adapt the next date,
loads, volume, rest, and accessories from the actual report, recovery, pain,
available time, equipment, and recent history.

For main lifts, keep a target when useful clean work was completed but the full
prescription was missed; use the prior clean load for remaining sets. Increase
only after the full target is clean. Reduce earlier for pain, unsafe technique,
or a clearly unproductive load. Use double progression for accessories and
avoid adding work that does not address a current need.

After a completed workout:

1. Log the report idempotently.
2. Discuss the result briefly and propose the next training date immediately.
3. Prepare the complete next prescription now, including subject and a natural
   missed-workout check-in, but do not reveal the prescription in the reply.
4. Create a private per-run directory, read the current revision, then schedule
   with that expected revision and the inbound source ID:

   ```bash
   install -d -m 0700 "$HERMES_HOME/tmp"
   training_tmp="$(mktemp -d "$HERMES_HOME/tmp/training.XXXXXX")"
   python "$HERMES_HOME/scripts/training_reminder_dispatcher.py" show
   python "$HERMES_HOME/scripts/training_reminder_dispatcher.py" schedule \
       --expected-revision REVISION \
       --source-id INBOUND_ID \
       --date YYYY-MM-DD \
       --lift deadlift \
       --subject "Deadlift Training Day" \
       --prescription-file "$training_tmp/prescription.txt" \
       --checkin-body-file "$training_tmp/checkin.txt"
   rm -f "$training_tmp/prescription.txt" "$training_tmp/checkin.txt"
   rmdir "$training_tmp"
   ```

On a revision conflict, read the state again and reconcile the user's newest
intent; never overwrite it. A redelivered inbound ID returns the already-applied
state without changing the revision or advancing the plan again.

If the user asks for a workout now, include the full prescription in the normal
threaded reply and schedule it with `--delivered`. This records
`awaiting_completion` and prevents the 5 AM job from sending it again.

## Missed workouts and replies

The reconciler sends one check-in on the morning after a planned workout and
then stays silent in `awaiting_reply`. A reply may report completion, explain a
miss, change availability, mention pain, or change goals. Discuss the cause, then
schedule a revised date and complete prescription with the current expected
revision and `--source-id`. If no safe plan can be scheduled, pause the state with
a concise reason and the same `--source-id`.

Never send a second nag while state is `awaiting_reply`.

## Program changes

Dates, load, set/rep volume, rest, and accessories are adaptive details and can
change without a structural review. The split, lift rotation, and overall block
structure are structural.

Research structural changes at block boundaries, or earlier after repeated
stalls, pain, or changed goals. Cite credible evidence in the coaching reply,
present the proposed change and tradeoffs, and wait for explicit approval before
changing the split, rotation, or program structure. Until approval, keep the
active structure and make only safe session-level adjustments.

For maximal-strength estimates, use Epley only through five reps. Prefer safe
two- or three-rep tests over true one-rep max attempts for a solo lifter.
