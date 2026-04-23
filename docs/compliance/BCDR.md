# Business Continuity & Disaster Recovery Plan (BCDR)

**Organization:** Wilkes & Liberty  
**Maintained by:** Jeremy (`3@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23  
**Framework reference:** NIST SP 800-171 §3.6.2; NIST SP 800-34

---

## 1. Objectives

| Metric | Target | Basis |
|--------|--------|-------|
| **RTO** (Recovery Time Objective) | 4 hours | Maximum acceptable downtime for production services |
| **RPO** (Recovery Point Objective) | 24 hours | Maximum acceptable data loss; daily backup cadence |
| **Backup frequency** | Daily (2:00 AM) | `com.wilkesliberty.backup` launchd agent |
| **Backup retention** | 30 days rolling | Local `~/Backups/wilkesliberty/daily/` |
| **Offsite backup** | Proton Drive (AES-256 encrypted) | Synced by backup script after local verification |
| **Restore test cadence** | Quarterly | `make test-backup-restore` |

---

## 2. System Architecture Summary

For recovery purposes, the platform consists of two components:

**On-prem server** (macOS, home office):
- Runs the full Docker Compose stack: Drupal, PostgreSQL, Redis, Keycloak, Solr, monitoring.
- All persistent data lives in Docker named volumes under the macOS filesystem.
- Replaced by: rebuild the Docker stack on any macOS machine via `make onprem`.

**Njalla VPS** (cloud):
- Runs Caddy (reverse proxy) and Next.js (UI).
- Stateless: no persistent data except Caddy TLS certificates (auto-renewed by Let's Encrypt).
- Replaced by: provision a new Debian VPS at Njalla, point DNS, run `make vps`.

---

## 3. Backup Procedure

### 3.1 Automated daily backup

`~/Scripts/backup-onprem.sh` runs at 2:00 AM daily via launchd (`com.wilkesliberty.backup`). What it does:

1. Checks prerequisites (Docker available, `wl_postgres` container healthy).
2. Runs `pg_dump` on the `drupal` database → compressed SQL (`drupal_postgres_TIMESTAMP.sql.gz`).
3. Size-validates the dump (< 10 KB = failure; sends Postmark alert + aborts).
4. Archives Drupal public and private files.
5. Encrypts the archive with AES-256 (`BACKUP_ENCRYPTION_KEY` from sops).
6. Syncs to Proton Drive via `rclone`.
7. Sends failure alerts via Postmark on any error.

Backup location: `~/Backups/wilkesliberty/daily/YYYY-MM-DD_HHMMSS/`

### 3.2 Monitoring backup health

```bash
# Confirm recent backups aren't undersized
ls -lh ~/Backups/wilkesliberty/daily/ | tail -7

# Check backup log
tail -50 ~/Backups/wilkesliberty/logs/backup.log

# Run restore test (quarterly or after any backup script change)
make test-backup-restore
```

For the full restore test procedure, see [BACKUP_RESTORE.md](../BACKUP_RESTORE.md).

---

## 4. Disaster Scenarios & Recovery Procedures

### 4.1 Scenario A: Service outage (containers down)

**RTO target:** 30 minutes

```bash
# Diagnose
make status
docker compose -f ~/Repositories/infra/docker/docker-compose.yml logs --tail=50

# Restart
make onprem   # stops and restarts the full stack with latest config
```

If `make onprem` fails, check the DEPLOYMENT_CHECKLIST.md for common failure modes.

### 4.2 Scenario B: Data corruption (bad migration / accidental delete)

**RTO target:** 2 hours  
**RPO:** Last successful backup (≤ 24 hours ago)

```bash
# 1. Verify the backup
make test-backup-restore

# 2. Stop the production stack
docker compose -f ~/Repositories/infra/docker/docker-compose.yml down

# 3. Restore the database
# See full procedure in BACKUP_RESTORE.md

# 4. Restart
make onprem
```

### 4.3 Scenario C: On-prem server hardware failure

**RTO target:** 4 hours (with spare hardware available)  
**RPO:** Last successful backup (≤ 24 hours ago)

**Assumptions:** Replacement macOS machine is available; `infra` repo is accessible from another device.

1. Install Homebrew, Docker Desktop, Tailscale on replacement machine.
2. Clone the `infra` repo.
3. Copy the SOPS age key from backup (password manager) to `~/.config/sops/age/keys.txt`.
4. `make bootstrap` — installs Ansible, SOPS, and other tools.
5. `make onprem` — deploys the full stack (creates a fresh database).
6. Restore the database from the latest backup per BACKUP_RESTORE.md.
7. Verify: `make test-backup-restore`, `drush status`, smoke test the site.

### 4.4 Scenario D: VPS failure or hosting provider outage

**RTO target:** 2 hours

1. Provision a new Debian VPS at Njalla (or an alternative provider).
2. Update the VPS IP in `ansible/inventory/hosts.ini` and relevant DNS records.
3. `terraform apply` — updates Njalla DNS records to point to new VPS.
4. `make vps` — deploys Caddy + Next.js + Let's Encrypt.
5. Verify: `curl -o /dev/null -sw "%{http_code}" https://www.wilkesliberty.com`.

### 4.5 Scenario E: Security incident requiring full rebuild

See [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md) for the incident handling procedure. After containment:

1. Provision fresh infrastructure (new VPS if VPS was compromised; fresh Docker stack if on-prem was compromised).
2. Rotate all credentials (see INCIDENT_RESPONSE.md §3.1 credential rotation playbook).
3. Restore data from the last known-good backup (verify backup predates the compromise).
4. Do not restore from backups taken after the suspected compromise start time.

---

## 5. Media Sanitization & Hardware Disposal

When hardware containing production data is decommissioned or repaired:

- **macOS SSD/HDD:** Use Apple's Erase Assistant or `diskutil secureErase freespace <level> <device>` to wipe free space, or full drive erase via Recovery Mode.
- **Docker volumes:** `docker volume rm <volume>` for data removal. Underlying disk must be wiped per above.
- Removed hardware is not donated or sold before sanitization is confirmed.
- Physical destruction (drill through platter/chip) is preferred for drives that once held encryption keys.

See [DATA_CLASSIFICATION.md §5](DATA_CLASSIFICATION.md) for the full sanitization policy.

---

## 6. Test & Review Schedule

| Activity | Frequency | Next due |
|----------|-----------|---------|
| Automated restore test (`make test-backup-restore`) | Quarterly | 2026-07-23 |
| Full BCDR plan review (update this document) | Annually | 2027-04-23 |
| Tabletop exercise (walk through one scenario with all responders) | Annually | 2027-04-23 |
| Verify Proton Drive encrypted backup is restorable | Annually | 2027-04-23 |

---

## 7. Key Contacts & Dependencies

| Resource | Location | Access method |
|----------|----------|--------------|
| SOPS age key | Password manager (primary) · `~/.config/sops/age/keys.txt` (local) | Retrieved from password manager on a second device |
| Infra repo | `github.com/Wilkes-Liberty/infra` | Git clone; GitHub account + SSH key |
| Tailscale | `login.tailscale.com/admin` | Tailscale account (MFA) |
| Njalla | `njal.la` | Njalla account (MFA) |
| Proton Drive | `drive.proton.me` | Proton account (MFA) |
| Latest backup | `~/Backups/wilkesliberty/daily/` (local) · Proton Drive `/wilkesliberty/daily/` | Local filesystem or `rclone ls proton:wilkesliberty/daily/` |
