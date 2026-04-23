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

## One-time setup: fill in `stg_postmark_server_token`

Before the first run, create a **sandbox** server called `wilkesliberty-staging` in
[Postmark](https://account.postmarkapp.com) and copy its server token.  Then write
it to sops:

```bash
cd ~/Repositories/infra
sops --set '["stg_postmark_server_token"] "YOUR_TOKEN_HERE"' \
  ansible/inventory/group_vars/staging_secrets.yml
```

The playbook will refuse to proceed if this token is empty.

To test mail delivery on staging, add your personal address as a **sandbox
recipient** in Postmark → wilkesliberty-staging → Sandbox → Recipients.
Only those addresses will receive the email; all other `To:` addresses are silently
swallowed by Postmark's sandbox.

---

## How to run it

```bash
make refresh-staging
# Prompts: "Type 'yes' to continue:"
```

The playbook runs locally (no SSH — on-prem server is localhost) and takes
roughly 2–5 minutes depending on database size and file volume.

---

## What it does, in order

| Step | Action |
|------|--------|
| 1 | Verify all four containers are running |
| 2 | `pg_dump` prod DB → `/tmp/wl-prod-refresh.dump` on host |
| 3 | `dropdb` + `createdb` staging, `pg_restore --no-owner --no-acl` |
| 4 | `rsync` prod public files → staging (**private files are not copied**) |
| 5a | `drush cache:rebuild` so drush can bootstrap the restored DB |
| 5b | Rewrite all user emails to `noreply+stg-<uid>@wilkesliberty.com` |
| 5c | Invalidate non-admin password hashes (uid > 1) — invalid bcrypt prefix |
| 5d | Rewrite custom email-type entity fields (dynamic enumeration via Drupal's field API) |
| 5e | Rewrite webform submission email values (dynamic enumeration via webform config) |
| 5f | Truncate `watchdog` table |
| 6 | Configure SMTP to use sandbox Postmark server (`stg_postmark_server_token`) |
| 7 | Set staging site mail, webhook secret (`stg_postmark_webhook_secret`), admin password |
| 8 | Update `next.next_site.wilkesliberty_ui` URLs → `https://stg.int.wilkesliberty.com` |
| 9 | `drush updatedb -y` + final `drush cache:rebuild` |
| 10 | Verify bootstrap, display admin info |
| 11 | Remove temp dump files from `/tmp` and both postgres containers |

---

## Sanitization guarantees

### User emails
All `users_field_data.mail` values are rewritten:

```
realuser@example.com  →  noreply+stg-42@wilkesliberty.com
```

### Password hashes (non-admin)
All non-admin accounts (uid > 1) get an invalid bcrypt-prefixed hash:

```
$2y$10$staging.locked.out.<uid>
```

This value can never match any real password.  Admins cannot reset these
accounts via email because the sandbox SMTP only delivers to pre-approved
Postmark recipient addresses.

Admin (uid=1) gets a fresh password — see "Logging in" below.

### SMTP isolation
Staging uses a **Postmark sandbox server** (`wilkesliberty-staging`).
Sandbox servers only deliver to explicitly pre-approved recipient addresses.
Any other `To:` address is silently discarded by Postmark.  This means:
- You can test real email delivery end-to-end on staging
- No risk of accidentally emailing real users regardless of what email
  addresses remain in the DB
- Sandbox sends do not affect production reputation or stats

The sandbox token (`stg_postmark_server_token`) is isolated from production
and stored separately in sops.

### Custom entity email fields
All `field_storage_config` entries with `type: email` are enumerated at
runtime.  For each, both the data table and the revision table are updated:

```
noreply+stg-<entity_id>@wilkesliberty.com
```

If no custom email fields exist, the step logs "No custom email fields found."

### Webform submission emails
All webform elements with `#type: email` or `webform_email_confirm` are
enumerated from webform config.  Matching rows in `webform_submission_data`
are rewritten:

```
noreply+stg-webform-<sid>@wilkesliberty.com
```

If webform is not installed, or no email elements exist, the step skips
gracefully.

### Watchdog
The `watchdog` table is truncated — no prod log PII on staging.

### Next.js URLs
`next.next_site.wilkesliberty_ui` is updated:

| Key | Staging value |
|---|---|
| `base_url` | `https://stg.int.wilkesliberty.com` |
| `preview_url` | `https://stg.int.wilkesliberty.com/api/draft` |
| `revalidate_url` | `https://stg.int.wilkesliberty.com/api/revalidate` |

### Private files
`~/nas_docker/drupal/private/` is **not** copied.

---

## Remaining gaps

| Gap | Risk | Notes |
|---|---|---|
| Custom profile entity email fields (non `field_storage_config`) | Low | Only applies to base-field overrides on profile entity; not currently used |
| Content fields that store email as plain text (varchar, not email type) | Low | Would require field-by-field manual config; no such fields currently exist |
| Revalidate / preview secrets in `next.next_site` | Low | Still set to prod values after restore; staging Next.js uses different env vars (`stg_drupal_revalidate_secret`) so there's no functional overlap, but the DB value is stale |

---

## Logging in after a refresh

| URL | `https://api-stg.int.wilkesliberty.com/user/login` |
|---|---|
| Username | `admin` |
| Password | `stg_drupal_admin_password` in sops (see below) |

To retrieve the password:

```bash
sops -d ansible/inventory/group_vars/staging_secrets.yml | grep stg_drupal_admin_password
```

All other user accounts have invalidated password hashes and cannot log in.

---

## Sops keys used by this workflow

| Key | File | Purpose |
|---|---|---|
| `drupal_db_password` | `sso_secrets.yml` | Auth for prod `pg_dump` |
| `stg_drupal_db_password` | `staging_secrets.yml` | Auth for staging postgres operations |
| `stg_drupal_admin_password` | `staging_secrets.yml` | Staging Drupal admin (uid=1) password |
| `stg_postmark_server_token` | `staging_secrets.yml` | Postmark sandbox server token (fill in before first run) |
| `stg_postmark_webhook_secret` | `staging_secrets.yml` | Staging Postmark webhook URL secret |

All secrets are loaded from SOPS at runtime — nothing is hardcoded.

`make onprem` also applies `stg_postmark_server_token` and `stg_postmark_webhook_secret`
to the running staging Drupal when the staging bootstrap check passes, so SMTP
isolation and webhook credentials survive a fresh staging deploy.
