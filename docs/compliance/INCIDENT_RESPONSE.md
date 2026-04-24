# Incident Response Plan

**Organization:** Wilkes & Liberty  
**Framework:** NIST SP 800-61 Rev 2  
**Maintained by:** Jeremy Michael Cerda (`jmcerda@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23  
**Applies to:** All systems under `wilkesliberty.com` (on-prem server, Njalla VPS, associated SaaS accounts)

---

## Contact Tree

| Role | Name | Contact | Escalation order |
|------|------|---------|-----------------|
| Incident Commander / Primary Responder | Jeremy Michael Cerda (`jmcerda`) | `jmcerda@wilkesliberty.com` · TBD | 1st |
| Business Continuity Contact (Spouse) | Aleksandra Cerda | `acerda@wilkesliberty.com` · TBD | Contact only if Jeremy is unreachable and business-continuity action is required. Not an IR responder — see PROJECT_PLAN.md Phase D for break-glass activation. |
| Legal Counsel (if data breach) | [NAME — fill in] | [EMAIL] · [PHONE] | Notify within 24h of confirmed breach |
| Key Customer / Client Notification | [NAME — fill in] | [EMAIL] | Notify within 72h of confirmed breach affecting their data |

_Fill in real names and phone numbers before this plan is operational. Store this information in the password manager, not only in this doc._

---

## Phase 1 — Preparation

### 1.1 Monitoring tools

The following detection channels are active and monitored:

| Channel | What it detects | Where to check |
|---------|----------------|---------------|
| Prometheus / Alertmanager | Service downtime, high error rates, disk pressure, unusual traffic | `https://alerts.int.wilkesliberty.com` · email to `jmcerda@wilkesliberty.com` |
| Drupal watchdog | PHP errors, access denied events, failed logins | `drush watchdog:show --severity=error` · `/admin/reports/dblog` |
| Caddy access logs | 4xx/5xx spikes, unusual request patterns, rate-limit triggers | `/var/log/caddy/api.log` on VPS |
| Uptime Kuma | Public endpoint availability | `https://uptime.int.wilkesliberty.com` |
| Backup failure alerts | `backup-onprem.sh` failures | Postmark email to `jmcerda@wilkesliberty.com` |
| GitHub Dependabot | Dependency CVEs | GitHub repo security tab |

### 1.2 Response kit

Before an incident occurs, verify these are working and accessible:

- [ ] Tailscale is active (to reach on-prem server and VPS internal interfaces)
- [ ] SOPS age key is accessible: `export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt`
- [ ] SSH to VPS works: `ssh root@<vps>`
- [ ] `make test-backup-restore` passes on the latest daily backup
- [ ] Password manager is accessible from a second device

---

## Phase 2 — Detection & Analysis

### 2.1 Incident classification

| Severity | Definition | Initial response time | Examples |
|----------|-----------|----------------------|---------|
| P1 — Critical | Data exfiltration suspected or confirmed; system completely unavailable; ransomware | Immediate (< 1h) | Credential compromise, active intrusion, database dump exfiltrated |
| P2 — High | Partial service disruption; security control bypassed; CVE actively exploited in wild | < 4h | Container crash loop, rate-limiter bypass, known exploited CVE unpatched |
| P3 — Medium | Degraded service; security advisory without active exploitation; failed backup | < 24h | Docker volume filling, Prometheus alert for elevated error rate |
| P4 — Low | No user impact; informational finding; routine hardening item | Next business day | Low-severity Dependabot advisory, log anomaly with no follow-on activity |

### 2.2 Initial triage checklist

When an alert fires or a possible incident is reported:

```bash
# 1. Check overall system health
make status                                         # container status
docker exec wl_drupal drush watchdog:show --severity=warning --count=50
docker compose -f ~/nas_docker/docker-compose.yml logs --since=1h | grep -i "error\|warn\|fatal"

# 2. Check for active intrusion indicators
ssh root@<vps> "fail2ban-client status sshd"        # banned IPs
ssh root@<vps> "last -20"                           # recent logins
ssh root@<vps> "w"                                  # current sessions
docker exec wl_postgres psql -U postgres -c "SELECT * FROM pg_stat_activity WHERE state='active';"

# 3. Check Caddy rate limit events (unusual 429 spike = possible attack)
ssh root@<vps> "tail -200 /var/log/caddy/api.log | grep 429"

# 4. Check backup integrity
ls -lh ~/Backups/wilkesliberty/daily/ | tail -5     # confirm recent backups aren't tiny
tail -30 ~/Backups/wilkesliberty/logs/backup.log
```

### 2.3 Scope determination

Document in the incident record:
- What system(s) are affected?
- What data may be at risk? (See [DATA_CLASSIFICATION.md](DATA_CLASSIFICATION.md))
- What is the estimated start time of the incident?
- Is the threat actor still active?
- Is this a known vulnerability (CVE) or novel?

---

## Phase 3 — Containment, Eradication & Recovery

### 3.1 Playbook: Compromised credential

**Trigger:** A secret (OAuth token, DB password, SOPS key, Tailscale auth key) is suspected or confirmed to have been exposed.

```bash
# Step 1 — Identify the exposed secret type
# (different secrets require different rotation procedures — see below)

# Step 2 — Rotate the secret before eradication
# Drupal OAuth client secret:
#   Drupal admin → /admin/config/services/consumer → regenerate secret
#   sops ansible/inventory/group_vars/app_secrets.yml → update drupal_client_secret
#   make onprem && make vps

# PostgreSQL password (wl_app):
#   sops ansible/inventory/group_vars/sso_secrets.yml → update drupal_db_password
#   make onprem  (Ansible resets wl_app password to match env)

# Postmark server token:
#   Postmark dashboard → Servers → wilkesliberty-production → API Tokens → Revoke + New
#   sops ansible/inventory/group_vars/app_secrets.yml → update postmark_server_token
#   make onprem

# Tailscale auth key:
#   Tailscale admin console → Settings → Keys → Revoke key
#   sops ansible/inventory/group_vars/tailscale_secrets.yml → update tailscale_auth_key
#   make onprem

# SOPS age private key (most severe — all secrets must be re-encrypted):
#   1. Generate new age key: age-keygen -o ~/.config/sops/age/new-keys.txt
#   2. Update .sops.yaml with new public key
#   3. Re-encrypt all *_secrets.yml:
#      for f in ansible/inventory/group_vars/*_secrets.yml; do sops updatekeys "$f"; done
#   4. Revoke old key from any backup copies
#   5. Redeploy: make onprem && make vps

# Step 3 — Review audit trail
git log --since="48 hours ago" --all --format="%h %ai %an %s"
ssh root@<vps> "journalctl --since='48 hours ago' | grep -i 'auth\|sudo\|ssh'"

# Step 4 — Verify no persistence mechanisms were added
docker inspect wl_drupal | grep Volumes      # unexpected volume mounts?
docker images | grep -v "<official images>"  # unexpected local images?
ssh root@<vps> "crontab -l"                  # unexpected cron jobs?
ssh root@<vps> "systemctl list-units --state=active | grep -v standard"
```

### 3.2 Playbook: Container compromise / active intrusion

**Trigger:** Unexpected process in container, unusual outbound connections, rootkit indicators.

```bash
# Immediate containment: isolate the affected container
docker stop wl_drupal   # or whichever container

# Capture forensic state BEFORE destroying evidence
docker inspect wl_drupal > /tmp/incident-inspect-$(date +%Y%m%d-%H%M%S).json
docker logs wl_drupal --since=2h > /tmp/incident-logs-$(date +%Y%m%d-%H%M%S).txt

# Check for lateral movement
docker exec wl_postgres psql -U postgres -c "\du"                    # unexpected DB roles?
docker exec wl_postgres psql -U postgres -c "SELECT * FROM pg_stat_statements LIMIT 20;"

# Rebuild container from clean image (do NOT restart the potentially-compromised one)
docker compose -f ~/Repositories/infra/docker/docker-compose.yml \
  --env-file ~/nas_docker/.env up -d --build --force-recreate wl_drupal

# After rebuild, rotate all credentials the container had access to
# (see §3.1 credential rotation procedures)
```

### 3.3 Playbook: Data breach (suspected exfiltration)

**Trigger:** Unexpected large outbound transfer, database dump found externally, insider threat report.

1. **Contain immediately** — block the suspected exfiltration vector (revoke API token, isolate container, block IP in UFW).
2. **Preserve evidence** — capture logs before any changes. Do not power off unless absolutely necessary.
3. **Scope the breach** — determine what data was accessible. See [DATA_CLASSIFICATION.md](DATA_CLASSIFICATION.md) for what this system stores.
4. **72-hour notification clock starts now.** If PII belonging to identifiable individuals was in the breach, legal counsel must be notified within 24h and affected parties within 72h (depends on applicable law and contract terms).
5. **Document everything** in the incident record (see §4 template below).

### 3.4 Playbook: Service outage

**Trigger:** Prometheus alert, Uptime Kuma alert, user report.

```bash
# Triage in under 2 minutes:
make status                                              # which containers are down?
docker logs <container> --tail=50                        # why did it crash?

# Most common causes and fixes:
# 1. Port conflict on redeploy → make onprem (stops then restarts)
# 2. Postgres won't start → disk full? check: df -h ~/nas_docker/postgres-data/
# 3. Drupal 503 → Postgres not ready: docker exec wl_postgres pg_isready -U drupal
# 4. Caddy cert expired → certbot renew then make onprem
# 5. VPS unreachable → check Tailscale: tailscale status | grep vps

# RTO target: production restored within 4 hours of detection
# RPO target: no more than 24 hours of data loss (daily backup cadence)
# See BCDR.md for full recovery procedure
```

---

## Phase 4 — Post-Incident Activity

### 4.1 Post-incident review (required for P1 and P2)

Schedule a review within 5 business days of incident closure. Address:

1. **Timeline** — when did the incident start? when detected? when resolved?
2. **Root cause** — what went wrong?
3. **Detection** — how was it found? would monitoring have caught it sooner?
4. **Containment** — were the right steps taken in the right order?
5. **Impact** — what data, systems, or users were affected?
6. **Lessons learned** — what would we do differently?
7. **Action items** — specific changes with owners and due dates

### 4.2 Post-incident report template

```markdown
## Incident Report — [YYYY-MM-DD] [Brief title]

**Severity:** P[1/2/3/4]
**Incident start:** [datetime]
**Detected:** [datetime] via [alert source]
**Resolved:** [datetime]
**Total duration:** [Xh Ym]

### Systems affected
[list]

### Timeline
| Time | Event |
|------|-------|
| HH:MM | [action taken or event observed] |

### Root cause
[description]

### Impact
[data affected, users affected, services degraded]

### Detection gap
[was there a monitoring gap? should this have been caught sooner?]

### Action items
| Item | Owner | Due |
|------|-------|-----|
| | | |

### Lessons learned
[1–3 key takeaways]
```

### 4.3 External notification obligations

| Condition | Notify | Timeline |
|-----------|--------|---------|
| PII of EU/UK residents exfiltrated | Data Protection Authority (if applicable) | 72h |
| PII of any identifiable individuals | Affected individuals | "Without undue delay" |
| Federal contract data (CUI) involved | Contracting officer / agency ISSO | Per contract terms (often 1h for discovery report, 72h for full report) |
| Key client data involved | Client security contact | Per contract / SLA terms |

---

## 5. Annual Review & Drills

- **Test the contact tree** annually — verify all phone numbers and email addresses work.
- **Table-top exercise** annually — walk through a P1 scenario with all responders.
- **Backup restore drill** quarterly — `make test-backup-restore` verifies the latest backup is usable (see [BACKUP_RESTORE.md](../BACKUP_RESTORE.md)).
- **This document** reviewed annually or after any incident that reveals a gap.

_Next scheduled review: 2027-04-23_
