# Hermes Cloud Pilot

Hermes runs as one always-on, email-only Fly Machine in the `the1000club`
organization. `the1000club-mail-bridge` is the only email transport owner and uses
Resend for `coach@the1000club.fit`. Hermes has no service, public IP, Flycast
address, dashboard, or inbound API.

The image is built from Hermes commit
`7426c09beee73bdff94d916015bac71384f6bc92`. `build-image.sh` refuses a
different or dirty checkout. The pilot overlay contains only generic code;
credentials, authentication, client data, prescriptions, scheduling state, and
backups stay out of this repository.

## Local validation

```bash
cd ~/.dotfiles/vms/hermes/fly
uv run --with pytest --with boto3 --with pyyaml pytest -q tests
shellcheck ./*.sh assets/pilot-jobs.sh
shfmt -d -i 4 -bn -ci ./*.sh assets/pilot-jobs.sh
fly config validate --strict --config fly.toml
./build-image.sh
```

The build copies the generic email plugin from
`~/code/vicyap/the1000club/apps/mail-bridge`. It does not contact the live bridge or
mutate Fly resources.

## Deployment

Authenticate manually before changing Fly resources:

```bash
fly auth login
```

Initial provisioning creates one app, a private Tigris bucket, an encrypted
5 GB volume, and 30-day snapshots:

```bash
cd ~/.dotfiles/vms/hermes/fly
./provision.sh
./push-image.sh
```

The primary app name is `the1000club-hermes`; `provision.sh` falls back to
`the1000club-fit-hermes` if needed. Tigris credentials are attached as Fly
secrets without printing them. A newly created app also requires
`BRIDGE_URL`, `BRIDGE_API_TOKEN`, `EMAIL_ADDRESS`, `EMAIL_ALLOWED_USERS`, and
`EMAIL_HOME_ADDRESS`. Resend credentials stay on the bridge.

`deploy.sh` takes a full Tigris backup before every existing-app deployment and
starts exactly one Machine:

```bash
./deploy.sh
```

Upgrades remain manual and backup-gated: change the pinned commit and image tag,
test the candidate against a restored temporary volume, then deploy it as a
separate release.

## Resend mail transport

The stateful bridge runs in the `the1000club` Fly organization alongside
Hermes.

Configure the mail transport in this order:

1. Create a Resend domain with sending and receiving enabled.
2. Create one `email.received` webhook for
   `https://the1000club-mail-bridge.fly.dev/v1/resend/webhook`.
3. Stage `RESEND_API_KEY`, `RESEND_WEBHOOK_SECRET`,
   `EMAIL_ADDRESS=coach@the1000club.fit`, and
   `EMAIL_ALLOWED_RECIPIENTS=coach@the1000club.fit` on the bridge. Retain its
   API token, sender allowlist, Pushover, and Tigris secrets.
4. Deploy the bridge and confirm `/healthz` before adding domain DNS.
5. Add the exact DNS records supplied by Resend, set them to DNS-only, and wait
   for the domain to verify.
6. Back up Hermes, then set only its
   `EMAIL_ADDRESS=coach@the1000club.fit`. Leave `EMAIL_HOME_ADDRESS` unchanged.
7. Send one text message and one attachment to the coach address and verify one
   threaded reply.

The bridge verifies the webhook before fetching content, admits only the exact
recipient and sender allowlist, requires aligned DMARC from Amazon SES, and
stores exact raw MIME before acknowledging delivery. Repeated webhook events
deduplicate by Resend email ID. Outbound payloads are frozen before the first
send and use a stable provider idempotency key.

Do not rerun the migration check-in command; it was a one-time cutover action.

## Operations

The supervised pilot job reconciles the training outbox every 15 minutes and
takes daily scheduling action only after 5:00 AM Pacific. A full Hermes backup
runs after 4:30 AM Pacific, uploads to the private
`the1000club-hermes-backups` bucket, and prunes objects older than 30 days.

```bash
fly status --app "${HERMES_APP:-the1000club-hermes}"
fly machine list --app "${HERMES_APP:-the1000club-hermes}"
fly volumes list --app "${HERMES_APP:-the1000club-hermes}"
fly services list --app "${HERMES_APP:-the1000club-hermes}"
fly ips list --app "${HERMES_APP:-the1000club-hermes}"
fly logs --app "${HERMES_APP:-the1000club-hermes}"
fly ssh console --app "${HERMES_APP:-the1000club-hermes}" \
    --user hermes \
    --command 'python /opt/data/scripts/training_reminder_dispatcher.py show'
```

Run a backup or restore drill on demand:

```bash
fly ssh console --app "${HERMES_APP:-the1000club-hermes}" \
    --user hermes \
    --command '/opt/hermes/.venv/bin/python /opt/hermes-pilot/backup_to_tigris.py'
./restore-drill.sh
```

The bridge sends one Pushover alert after five minutes without a Hermes lease
or renewal and clears it on recovery. Notifications contain no message,
address, credential, or queue data.

## Rollback

Roll back a release with the previous pinned Fly image and a restore-tested
Tigris backup. Fly volume snapshots are a secondary 30-day recovery source.
The halted Vagrant VM remains available only for a tested, single-gateway
recovery before a schema-changing upgrade; it must use the bridge and must not
be started from stale pre-cutover state.

This pilot is restore-based, not highly available. The volume is single-host
local storage; a Fly-wide outage affects both Hermes and the bridge. Resend's
send idempotency window is 24 hours, so a retry after that window can still
produce a rare duplicate. Root-domain Receiving is a catch-all, so unsolicited
mail to other local parts can consume the Resend account quota even though the
bridge rejects it.
