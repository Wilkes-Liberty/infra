# Drupal Config Export

Drupal stores configuration in two places: the **active config** in the database (what the running site actually uses) and the **sync config** on disk as YAML files (what git tracks). `drush config:export` moves active → sync so changes made in the admin UI can be version-controlled and replayed on other environments.

---

## Two modes of export

### Automatic (nightly snapshot)

A launchd agent `com.wilkesliberty.config-snapshot.prod` runs at **3:00 AM** daily.

**Script:** `~/Scripts/config-snapshot-prod.sh` (deployed by `make onprem`)

**What it does:**

1. Pulls `origin/master` into `~/Repositories/webcms`
2. Checks the Drupal watchdog for any `type=config` entries in the last 30 minutes — if found, skips with a log entry to avoid capturing in-progress work
3. Runs `drush config:export -y`
4. If the diff is non-empty: creates an `auto/config-YYYY-MM-DD-HHMMSS` branch off `origin/master`, commits all changes under `config/sync/`, pushes to origin
5. Emails `devops@wilkesliberty.com` via Postmark:
   - Subject: `[WilkesLiberty] Config snapshot ready for review (prod)`
   - Body: branch name + GitHub compare URL + "merge into master if changes look correct"
6. Logs to `~/Backups/wilkesliberty/logs/config-snapshot.log` (rotates files older than 30 days)

The script **never auto-merges**. The branch sits in the repo until you review and merge it manually.

### Manual (on-demand)

Run this after making admin UI changes you want to keep:

```bash
cd ~/Repositories/webcms
docker exec wl_drupal drush config:export -y
git status config/sync/
git diff config/sync/
git add config/sync/
git commit -m "config: describe what changed"
git push
```

---

## Where files land

The export directory is **`config/sync/` at the repo root** — a sibling of `web/`, not inside it.

```
webcms/
├── web/          ← Drupal docroot
│   └── ...
├── config/
│   └── sync/     ← config:export writes here  ← git tracks this
└── composer.json
```

This is set by `settings.docker.php` via Drupal's `$settings['config_sync_directory']`, pointing to `dirname(DRUPAL_ROOT) . '/config/sync'`. The docker-compose volume mount makes it writable from inside the container:

```
~/Repositories/webcms/config/sync:/opt/drupal/config/sync
```

> **Don't `cd web/config/sync/`** looking for exported config — almost nothing lives there. The only file you'll find in `web/config/sync/` is `config_ignore.settings.yml`, which is a historical artifact and doesn't belong there. The real sync dir is one level up.

---

## What's excluded from export (`config_ignore`)

**File:** `config/sync/config_ignore.settings.yml`

```yaml
ignored_config_entities:
  - smtp.settings
  - wl_postmark_webhook.settings
```

These two entities are written by Ansible from sops on every `make onprem` and intentionally never exported to git. Exporting them would either overwrite Ansible's values on next deploy or — worse — land a Postmark token in the commit history.

To exclude additional config entities (e.g., a module that stores runtime state you don't want snapshotted):

```bash
cd ~/Repositories/webcms
# edit config/sync/config_ignore.settings.yml
# add the entity name to ignored_config_entities:
git add config/sync/config_ignore.settings.yml
git commit -m "config: ignore <entity>"
```

---

## Common workflows

### (a) I made admin UI changes I want to keep

```bash
cd ~/Repositories/webcms
docker exec wl_drupal drush config:export -y
git diff config/sync/        # read the diff before staging
git add config/sync/
git commit -m "config: <describe what changed>"
git push
```

Scan the diff before staging — `config:export` will include everything that diverged from the last export, not just what you touched this session.

### (b) I got the nightly snapshot email

Email subject: `[WilkesLiberty] Config snapshot ready for review (prod)`

```bash
git fetch
git diff master...origin/auto/config-YYYY-MM-DD-HHMMSS -- config/sync/
```

- **Looks intentional?** Merge it:
  ```bash
  git checkout master
  git merge --ff-only origin/auto/config-YYYY-MM-DD-HHMMSS
  git push
  ```
- **Looks like drift or in-progress work?** Delete the branch and export manually when ready:
  ```bash
  git push origin --delete auto/config-YYYY-MM-DD-HHMMSS
  ```

### (c) Apply exported config to another environment

`make onprem` does not auto-import config — UI changes survive deploys. To explicitly apply the sync dir to a running instance:

```bash
# --partial: only import what's in sync; don't delete active config that isn't there
docker exec wl_drupal drush config:import --partial -y
```

Without `--partial`, a full import will delete any active config not present in the sync directory. Don't run that unless you're intentionally resetting the DB config to match git.

---

## Gotchas

**Review the diff before committing.** If you've been poking around the UI, the diff may include entities you didn't intend to change. Commit only what you meant to change; discard the rest with `git checkout -- config/sync/<file>`.

**Never put secrets in the sync dir.** If you find yourself wanting to, add the entity to `config_ignore.settings.yml` instead.

**`config:export` is silent but you're sure something changed.** `config_ignore` may be blocking the entity. Check the `ignored_config_entities` list and temporarily remove the entity name to verify.

**The nightly snapshot keeps firing on the same files.** Something in Drupal is drifting — often a cron job writing a timestamp or last-run value into config. Check which files are in the diff; you may need to add that entity to `config_ignore`.

---

## Staging

A parallel agent `com.wilkesliberty.config-snapshot.staging` runs at **3:05 AM**, operating on `~/Repositories/staging/webcms`. Branches are named `auto/config-stg-YYYY-MM-DD-HHMMSS` off `origin/staging`. The email subject reads `(staging)` instead of `(prod)`. Otherwise identical behavior.

---

## Related

- [ADMIN_SETUP.md](ADMIN_SETUP.md) — first-run admin app setup (Drupal OAuth consumer, Keycloak, Grafana)
- [STAGING_REFRESH.md](STAGING_REFRESH.md) — `make refresh-staging` (clone prod DB to staging)
- `ansible/roles/wl-onprem/templates/config-snapshot-prod.sh.j2` — the script source
- `ansible/roles/wl-onprem/tasks/main.yml` — launchd deployment tasks
