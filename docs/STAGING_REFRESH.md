# Staging Refresh

`make refresh-staging` clones the live production Drupal database and files into
the staging environment, then sanitizes the copy so it cannot accidentally contact
real users or share credentials with production.

---

## When to run it

- Before testing a major feature branch on staging (gives real content to work with)
- After a large production content migration (keeps staging in sync)
- When staging has drifted far enough from prod that testing results are unreliable
- After onboarding new team members who need realistic staging data

Do **not** run it mid-sprint if someone is actively testing on staging — it wipes everything.

---

## How to run it

```bash
make refresh-staging
```

You will be prompted to type `yes` to confirm before anything destructive happens.

The playbook runs locally (no SSH — on-prem server is localhost) and takes
roughly 2–5 minutes depending on database size and file volume.

---

## What it does, in order

| Step | Action |
|------|--------|
| 1 | Verify both `wl_postgres`/`wl_drupal` and `wl_stg_postgres`/`wl_stg_drupal` are running |
| 2 | `pg_dump` prod DB (`wl_postgres`) → `/tmp/wl-prod-refresh.dump` on host |
| 3 | `dropdb` + `createdb` on staging, then `pg_restore --no-owner --no-acl` |
| 4 | `rsync` prod public files (`~/nas_docker/drupal/files/`) → staging (`~/nas_docker_staging/drupal/files/`) — **private files are not copied** |
| 5 | `drush cache:rebuild` so drush can bootstrap the restored DB |
| 6 | **Sanitize** user emails and truncate watchdog (see below) |
| 7 | **Disable SMTP** (`smtp_on: false`) — no mail can leave staging |
| 8 | Set staging-specific config (site mail, webhook secret, admin password) |
| 9 | `drush updatedb -y` + final `drush cache:rebuild` |
| 10 | Verify Drupal bootstrap and display admin user info |
| 11 | Remove temp dump files from `/tmp` and both postgres containers |

---

## Sanitization guarantees

### Email addresses
All user email addresses in `users_field_data` are rewritten:

```
realuser@example.com  →  noreply+stg-42@wilkesliberty.com
```

where `42` is the user's uid.  Any accidental email send goes to a
non-existent address rather than a real inbox.

**Known gaps:** custom profile entity fields that store email addresses are
not rewritten by this step.  If your content type has an email field that
you expose to users, add a sanitization SQL statement to the playbook.

### SMTP

SMTP is **disabled entirely** on staging (`smtp.settings.smtp_on = false`).
Any code that tries to send mail will silently fail — no email leaves staging.

**Upgrade path (option b):** Create a `wilkesliberty-staging` server in
Postmark, store its token in `staging_secrets.yml` as `stg_postmark_server_token`,
and update the playbook's SMTP isolation task to configure SMTP with that token
instead of disabling it.  This lets you test actual mail delivery in isolation.

### Watchdog
The `watchdog` table is truncated.  Production log entries are not useful on
staging and contain user PII (IP addresses, paths, messages).

### Admin password
The Drupal `admin` account (uid=1) password is reset to the value of
`stg_keycloak_admin_password` in SOPS.  To retrieve it:

```bash
sops -d ansible/inventory/group_vars/staging_secrets.yml | grep stg_keycloak_admin_password
```

To use a dedicated staging Drupal admin password instead, add
`stg_drupal_admin_password` to `staging_secrets.yml` and update the
`Set staging Drupal admin password` task in `refresh-staging.yml`.

### What is NOT sanitized
- **Other user passwords** — all non-admin accounts retain their prod
  password hashes.  Because SMTP is disabled, those accounts cannot
  receive a password-reset email, and staging is Tailscale-only anyway.
- **Content** — all nodes, media, and config are exact clones of prod.
- **Private files** — `~/nas_docker/drupal/private/` is not copied.

---

## Logging in to staging after a refresh

| URL | `https://api-stg.int.wilkesliberty.com/user/login` |
|---|---|
| Username | `admin` |
| Password | value of `stg_keycloak_admin_password` in sops (see above) |

All other user accounts have their prod passwords.  Because SMTP is off
they cannot reset passwords via email.

---

## Next.js site URLs (manual check required)

After a refresh, the Drupal `next.next_site` configuration may still reference
production URLs (`https://www.wilkesliberty.com`).  Verify and update at:

```
https://api-stg.int.wilkesliberty.com/admin/config/services/next
```

Change `Base URL` to `https://stg.int.wilkesliberty.com` if needed.

This is not automated because the config entity machine name varies per
installation and cannot be safely assumed in the playbook.

---

## Secrets used by the playbook

| Variable | Source file | Purpose |
|---|---|---|
| `drupal_db_password` | `sso_secrets.yml` | Auth for prod `pg_dump` |
| `stg_drupal_db_password` | `staging_secrets.yml` | Auth for staging `dropdb`/`createdb`/`pg_restore`/sanitize SQL |
| `stg_keycloak_admin_password` | `staging_secrets.yml` | Set staging Drupal admin password |
| `postmark_webhook_secret` | `app_secrets.yml` | Reset webhook secret on staging |

All secrets are loaded from SOPS at playbook runtime.  Nothing is hardcoded.
