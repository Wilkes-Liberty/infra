# Configuration Management Plan

**Organization:** Wilkes & Liberty  
**Maintained by:** Jeremy (`3@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23  
**Framework reference:** NIST SP 800-171 §3.4

---

## 1. Purpose

This plan describes how configuration changes to the WilkesLiberty platform are tracked, tested, approved, and deployed. The goal is to ensure that the system is always in a known, reproducible state and that no unauthorized changes can be made without detection.

---

## 2. Baseline Configuration

The authoritative system configuration lives in two git repositories:

| Repo | What it controls | Canonical state |
|------|-----------------|----------------|
| `github.com/Wilkes-Liberty/infra` | All infrastructure: Docker Compose stack, Ansible playbooks, Caddy configs, CoreDNS zone, backup scripts, monitoring | `master` branch |
| `github.com/Wilkes-Liberty/webcms` | Drupal application: composer.lock, Drupal configuration (config/sync/), custom modules | `master` branch |

**Nothing in production diverges from what's in git.** If it's not in the repo, it doesn't exist in production. `make onprem` and `make vps` are the only sanctioned methods for applying changes to live systems.

The Drupal running configuration (active config in the database) is snapshotted nightly at 3:00 AM by an Ansible-deployed launchd agent. Any config drift from the last `config:export` triggers an auto branch push and email notification. See [CONFIG_EXPORT.md](../CONFIG_EXPORT.md).

---

## 3. Change Types & Process

### 3.1 Routine changes (application updates, config tweaks)

1. **Develop** on a feature branch (infra or webcms repo).
2. **Test on staging** — deploy to staging environment via `docker compose up --build` or `make onprem` against staging inventory.
3. **Review** — self-review the diff; no second approver required for single-operator team.
4. **Merge to master** — squash or regular merge.
5. **Deploy to production** — `make onprem` or `make vps` as appropriate.
6. **Verify** — run smoke-test checklist from DEPLOYMENT_CHECKLIST.md.

### 3.2 Security patches

Follow the emergency response procedure in [UPDATE_CADENCE.md §Emergency Response](../UPDATE_CADENCE.md). Patch window: critical/high within 24h of fix availability.

Commit format: `security: <component> <old> → <new> (<SA/CVE>)`.

### 3.3 Infrastructure changes (new services, network changes)

For changes that affect the system boundary, firewall rules, or encryption posture:
1. Update this SSP and relevant compliance docs to reflect the new state.
2. Assess impact on NIST 800-171 controls — update [SSP.md](SSP.md) and [POAM.md](POAM.md) if controls change status.
3. Follow routine change process above.

### 3.4 Emergency changes

For changes required to respond to an active incident (see [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md)):
1. Make the change to restore security or availability.
2. Document in the incident record.
3. Commit a git record immediately after the incident is resolved.
4. Update the SSP/POA&M if the change affects control implementation.

---

## 4. Component Inventory

Current components under configuration management:

| Component | Version | Pinned | Config location |
|-----------|---------|--------|----------------|
| Drupal | 11.3.8 | composer.lock | webcms/composer.lock |
| PostgreSQL | 16 | docker-compose.yml tag | docker/docker-compose.yml |
| Redis | 7-alpine | docker-compose.yml tag | docker/docker-compose.yml |
| Keycloak | 25.0 | docker-compose.yml tag | docker/docker-compose.yml |
| Solr | 9.6 | docker-compose.yml tag | docker/docker-compose.yml |
| Caddy | v2.11.2 + rate_limit | all.yml `caddy_custom_version` | ansible/inventory/group_vars/all.yml |
| Prometheus | v2.53.0 | docker-compose.yml tag | docker/docker-compose.yml |
| Grafana | 11.1.0 | docker-compose.yml tag | docker/docker-compose.yml |
| Alertmanager | v0.27.0 | docker-compose.yml tag | docker/docker-compose.yml |
| Next.js | per package.json | package-lock.json | ui/package-lock.json |
| Ansible | current | pip requirements | ansible/requirements.txt (planned) |
| Tailscale | auto-update | n/a | Tailscale admin console |

_See UPDATE_CADENCE.md for the full check/apply cadence for each component._

---

## 5. Configuration Change Log

All changes are recorded in git commit messages. The audit trail:

```bash
# All changes
git log --oneline

# Security updates only
git log --grep="security:" --oneline

# Infrastructure changes
cd ~/Repositories/infra && git log --oneline -20

# Application changes
cd ~/Repositories/webcms && git log --oneline -20
```

No separate change log file is maintained. The git history is the change log.

---

## 6. Rollback Procedure

If a change causes a production issue:

**Application (Drupal/Next.js):**
```bash
# Identify the last known-good commit
git log --oneline -10   # in webcms or ui repo

# Roll back to it
git checkout <commit-hash> -- composer.lock  # or package-lock.json
git commit -m "revert: roll back to <version> due to <reason>"
make onprem   # or make vps
```

**Infrastructure (Ansible/Docker):**
```bash
# In infra repo:
git revert <commit-hash>   # creates a new revert commit
make onprem
```

**Data (database):**
If a bad migration corrupts data, restore from the most recent backup:
```bash
make test-backup-restore   # verify the backup is valid first
# Then follow the full restore procedure in BACKUP_RESTORE.md
```

**RTO target:** Production restored within 4 hours.  
**RPO target:** No more than 24 hours of data loss (daily backup cadence).

---

## 7. Least Functionality

Unnecessary software, services, and ports are not installed or enabled. Policy:
- VPS: only packages required for Caddy, Let's Encrypt, Tailscale, and fail2ban.
- Docker containers: only the services defined in `docker-compose.yml`.
- No development tools (debug modules, profilers) in production containers.
- Prometheus `--web.enable-lifecycle` is disabled (prevents unauthenticated config reload endpoint).
