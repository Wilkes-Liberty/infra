# Security Checklist

Pre-deployment checklist and ongoing audit reference for the WilkesLiberty stack.

**How to use:**
- Run this before every production deploy (use the [compact summary](#pre-deployment-checklist) at the bottom)
- Re-audit the full doc quarterly or after any significant infrastructure change
- Status symbols: ✅ Done · ⚠️ Partial · ❌ Not done

**Stack:** Drupal 11 (headless CMS, on-prem Docker) · Next.js (VPS) · Keycloak (SSO, on-prem) · Postgres 16 · Redis 7 · Caddy (reverse proxy, both hosts) · Tailscale mesh · SOPS+age secrets

---

## 1. Secrets & Credentials

### 1.1 No secrets in source code or frontend bundles
**Status: ✅ Done**

All credentials flow through SOPS-encrypted `*_secrets.yml` → Ansible → `~/nas_docker/.env` (never committed). Next.js reads server-side env vars; none are embedded in the client bundle. `.gitignore` excludes `*.env`, `nas_docker/.env`, and `nas_docker_staging/.env`.

Evidence: `docker/.env.j2` (all values are `{{ var }}` Jinja2 references), `.sops.yaml` enforces encryption on any `*_secrets.yml` pattern.

### 1.2 Secrets files encrypted at rest
**Status: ✅ Done**

All `ansible/inventory/group_vars/*_secrets.yml` files are SOPS+age encrypted before commit. `.sops.yaml` at repo root enforces auto-encryption.

### 1.3 Dedicated secrets per environment (no shared prod/staging secrets)
**Status: ✅ Done**

`app_secrets.yml` (prod), `staging_secrets.yml` (staging) — separate tokens, separate DB passwords, separate Postmark servers (sandbox vs production).

### 1.4 Credential rotation schedule documented
**Status: ❌ Not done**

No rotation schedule exists for: Drupal OAuth client secret, simple_oauth consumer secret, Postmark server tokens, Keycloak bootstrap admin, Tailscale auth key, backup encryption key.

**Action:** Define rotation cadence (annually minimum). Document which sops keys to update and what to redeploy after each.

### 1.5 Backup encryption key backed up securely
**Status: ⚠️ Partial**

`BACKUP_ENCRYPTION_KEY` is in sops. The age key (`~/.config/sops/age/keys.txt`) itself has no documented off-host backup procedure.

**Action:** Back up the age private key to a separate secure location (password manager or printed cold storage). Without it, encrypted backups are unrecoverable.

---

## 2. Authentication & Authorization

### 2.1 Admin routes protected by network layer
**Status: ✅ Done**

Drupal admin (`api.int.wilkesliberty.com`) is Tailscale-only. Keycloak admin (`auth.int.wilkesliberty.com`) is Tailscale-only. Caddy internal binds exclusively to the Tailscale IP — confirmed in `Caddyfile.internal.j2` (`bind {{ onprem_tailscale_ip }}`).

### 2.2 Public API endpoints require appropriate auth
**Status: ⚠️ Partial**

Drupal JSON:API is intentionally public for the headless CMS pattern — anonymous read of published content is by design. Draft/unpublished content requires `client_credentials` OAuth2 via `simple_oauth`. `/api/webhooks/postmark/{secret}` uses URL secret with `hash_equals`. `/api/contact` is a public form endpoint (rate limiting not configured — see 5.2).

**Action:** Audit all custom route definitions in `wl_api` and `wl_postmark_webhook` modules to confirm each non-public route has an access check. Run `drush route` and spot-check `_access` or `_permission` on each.

### 2.3 OAuth2 access tokens have expiry
**Status: ⚠️ Partial**

`simple_oauth.settings.yml`: `authorization_code_expiration: 300` (5 minutes for auth codes). Access token lifetime is configured per-consumer, not globally. No consumer config files found in `config/sync/` — the consumer was created manually in the UI but the lifetime value is not version-controlled.

**Action:** After creating the OAuth2 consumer (ADMIN_SETUP.md §1), export config (`drush config:export -y`) to capture the consumer entity with its configured token lifetime. Ensure lifetime is ≤ 1 hour.

### 2.4 Passwords hashed with bcrypt or argon2
**Status: ✅ Done**

Drupal 11 uses `password_bcrypt` with cost factor 10 by default (PhpPassword service). Keycloak uses PBKDF2/bcrypt internally. Redis password is high-entropy random string in sops.

### 2.5 Session invalidation on logout
**Status: ⚠️ Partial**

Drupal session invalidation on logout is handled by core. Grafana SSO logout is wired to Keycloak's OIDC logout endpoint via `GF_AUTH_SIGNOUT_REDIRECT_URL` (in docker-compose.yml comment, active once SSO is wired). Keycloak token revocation endpoint available but not documented.

**Action:** Once Keycloak SSO is active, verify that logging out of Grafana invalidates the Keycloak SSO session (test with two browser tabs).

### 2.6 Keycloak hardening configured
**Status: ❌ Not done**

Keycloak is running but no realm has been created yet. Brute force detection, password policy, 2FA, and session timeouts are all unconfigured.

**Action:** Follow ADMIN_SETUP.md §3 (Steps C, I): enable brute force detection (5 failures, 30s wait), set password policy (min 12 chars, not username), configure session idle/max timeouts (30 min / 10 hours), enforce OTP for `admin` role.

---

## 3. Network & Transport Security

### 3.1 HTTPS enforced, HTTP redirected
**Status: ✅ Done**

VPS: Caddy auto-HTTPS handles all public domains; HTTP is automatically redirected.
Internal: `Caddyfile.internal.j2` has an explicit `http://*.int.wilkesliberty.com { ... redir https://{host}{uri} permanent }` block bound to the Tailscale IP.

### 3.2 CORS locked to specific origin
**Status: ✅ Done**

`Caddyfile.production.j2` line 100: `Access-Control-Allow-Origin "https://www.wilkesliberty.com"` on `api.wilkesliberty.com`. Not a wildcard. Preflight OPTIONS handled explicitly.

### 3.3 Security headers on all responses
**Status: ✅ Done (public) / ⚠️ Partial (internal)**

**Public (`www.wilkesliberty.com`):**
- HSTS: `max-age=63072000; includeSubDomains; preload` ✅
- X-Frame-Options: `SAMEORIGIN` ✅
- X-Content-Type-Options: `nosniff` ✅
- Referrer-Policy: `strict-origin-when-cross-origin` ✅
- Permissions-Policy: camera/mic/geo/payment blocked ✅
- Content-Security-Policy: present but contains `unsafe-inline` and `unsafe-eval` (noted in config as needing tightening once Next.js nonces are implemented) ⚠️

**Internal (`*.int.wilkesliberty.com`):**
- HSTS: `max-age=63072000; includeSubDomains` ✅
- X-Frame-Options: `SAMEORIGIN` ✅
- X-Content-Type-Options: `nosniff` ✅
- Referrer-Policy: `no-referrer` ✅
- Permissions-Policy: ✅
- Content-Security-Policy: not set on internal vhosts ⚠️

**Action:** Tighten CSP on `www` once Next.js inline scripts are audited for nonce eligibility. Add CSP to internal Caddyfile (lower priority — internal only).

### 3.4 Firewall: only required ports public
**Status: ✅ Done**

UFW deployed via `ansible/roles/common/tasks/firewall.yml`: default deny incoming; allow SSH from `admin_allow_cidrs` + Tailscale CIDR; allow 80/443 on VPS only. On-prem has zero public ports — all services bind to localhost or Tailscale IP.

### 3.5 Internal services Tailscale-only
**Status: ✅ Done**

CoreDNS binds on Tailscale IP only. Caddy internal binds on Tailscale IP only. `search.int`, `metrics.int`, `alerts.int` additionally restricted to `admin_allow_cidrs` (Caddy `remote_ip` check). On-prem Docker services bind to `localhost:PORT` not `0.0.0.0:PORT`.

### 3.6 SSH hardening on VPS
**Status: ❌ Not done in Ansible**

The `common` role is a stub (`# TODO: implement this role` in `ansible/roles/common/tasks/main.yml`). UFW restricts SSH to admin CIDRs, but no Ansible task hardens `sshd_config`: `PasswordAuthentication`, `PermitRootLogin`, or `PubkeyAuthentication` are not explicitly set. No fail2ban deployed.

**Action (high priority):** Implement the `common` role with:
```yaml
- name: Harden sshd_config
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: "{{ item.regexp }}"
    line: "{{ item.line }}"
  loop:
    - { regexp: '^#?PasswordAuthentication', line: 'PasswordAuthentication no' }
    - { regexp: '^#?PermitRootLogin', line: 'PermitRootLogin no' }
    - { regexp: '^#?PubkeyAuthentication', line: 'PubkeyAuthentication yes' }
  notify: restart sshd
- name: Install fail2ban
  apt: name=fail2ban state=present
```

### 3.7 TLS minimum version enforced
**Status: ✅ Done**

`Caddyfile.internal.j2` wildcard cert block: `protocols tls1.2 tls1.3`. VPS Caddy defaults to TLS 1.2+ globally.

---

## 4. Application Security

### 4.1 Input validated and sanitized server-side
**Status: ✅ Done (Drupal core) / ⚠️ Partial (custom code)**

Drupal core uses the Form API with server-side validation, field-type enforcement, and `Html::escape()` / `Xss::filter()` throughout. Custom module `wl_postmark_webhook`: uses `json_decode`, `mb_substr` for length capping, and `hash_equals` for secret comparison (correct timing-safe comparison). Webform module handles submission validation per-element.

**Action:** Audit `wl_api` module routes for any direct use of `$_GET`/`$_POST` without Drupal's typed request handling.

### 4.2 Parameterized queries, no string concatenation
**Status: ✅ Done**

Drupal uses PDO with parameterized queries throughout core and its DB API. `wl_postmark_webhook` uses `->insert()->fields()->execute()` (Drupal DB API, parameterized). `sanitize_email_fields.php` and `sanitize_webform_emails.php` use named placeholder arrays (`[':elem_0' => $value]`).

### 4.3 File upload restrictions
**Status: ⚠️ Partial**

Individual Drupal file fields have type/size restrictions configured per-field (visible in `config/sync/field.field.*` files). No global Caddy `request_body` size limit is set in either Caddyfile. Drupal's `php.ini` `upload_max_filesize` and `post_max_size` are the backstop.

**Action:** Add `request_body { max_size 50MB }` (or appropriate limit) to the `@api` block in `Caddyfile.production.j2` and the corresponding internal block. Prevents large-body DoS against Drupal.

### 4.4 CSRF protection
**Status: ✅ Done**

Drupal's Form API generates and validates CSRF tokens on all state-changing form submissions automatically. REST/JSON:API endpoints that use OAuth2 bearer tokens are CSRF-exempt by design (bearer token = no cookie session).

### 4.5 Rate limiting on sensitive endpoints
**Status: ❌ Not done**

`Caddyfile.production.j2` lines 113–122: the `rate_limit {}` block is commented out entirely. No rate limiting on: `/user/login`, `/api/contact`, `/api/webhooks/postmark/*`, or JSON:API write endpoints.

**Action (high priority):** Uncomment and configure Caddy rate limiting. Minimum:
```
rate_limit {
  zone auth {
    key {remote_host}
    events 10
    window 1m
  }
}
```
Apply to login endpoints. Keycloak brute-force detection (§2.6) handles the SSO path separately.

### 4.6 Webhook signature verification
**Status: ⚠️ Partial**

`PostmarkWebhookController.php` uses `hash_equals($configured, $secret)` where `$secret` is the URL path segment. `hash_equals` prevents timing attacks. However, this is a URL-embedded shared secret, not an HMAC signature. Postmark supports `X-Postmark-Signature` HMAC-SHA256 verification which would be stronger — the secret never appears in server logs.

**Action (low priority):** v2 improvement — add Postmark HMAC signature verification alongside the URL secret. See Postmark docs on message stream webhooks.

### 4.7 No secrets in logs
**Status: ✅ Done**

Ansible tasks that handle passwords use `no_log: true`. Docker exec commands with `PGPASSWORD` use `-e PGPASSWORD=...` environment injection, not command-line args. Caddy JSON logs do not log Authorization headers by default.

---

## 5. Container & Infrastructure Security

### 5.1 Containers run as non-root users
**Status: ⚠️ Partial**

- **Next.js**: `Dockerfile.prod` creates `nextjs` user (UID 1001) and sets `USER nextjs` at line 78 ✅
- **Drupal**: runs as `www-data` (a system user, not root, but not a dedicated minimal user) ✅
- **Postgres, Redis, Keycloak, Solr, Grafana, Prometheus**: standard images with their own non-root defaults (Postgres runs as `postgres`, Prometheus as `nobody`, etc.) — not overridden ⚠️ (acceptable for these images but not verified)

### 5.2 Base images pinned to specific versions
**Status: ⚠️ Partial**

`docker-compose.yml` services use pinned versions: `postgres:16`, `redis:7-alpine`, `keycloak/keycloak:25.0`, `solr:9.6`, `prom/prometheus:v2.53.0`, `grafana/grafana:11.1.0`, `prom/alertmanager:v0.27.0`, `prom/node-exporter:v1.8.1`, `gcr.io/cadvisor/cadvisor:v0.49.1`. ✅

Drupal `Dockerfile.prod` uses `drupal:11-apache` (floating minor) and `composer:2` (floating). Next.js `Dockerfile.prod` uses `node:20-alpine` (floating minor).

**Action:** Pin Dockerfile base images to specific patch versions: `drupal:11.1.2-apache`, `composer:2.7`, `node:20.15.1-alpine`. Update periodically.

### 5.3 Image vulnerability scanning
**Status: ❌ Not done**

No Trivy, Snyk, or Docker Scout scanning in CI or as a pre-deploy check. No CI/CD pipeline exists.

**Action:** Add `trivy image wilkesliberty/webcms:latest` as a manual pre-deploy check. Document in deployment checklist. Long-term: add to a CI pipeline.

### 5.4 Dependency scanning
**Status: ❌ Not done**

No documented `composer audit`, `npm audit`, or `pip-audit` cadence.

**Action:** Add to quarterly audit cadence:
```bash
# Drupal
docker exec wl_drupal composer audit

# Next.js (on VPS or dev machine)
cd ~/Repositories/ui && npm audit

# Ansible/Python (if pip packages)
pip-audit
```

### 5.5 Secrets in environment only (not image layers)
**Status: ✅ Done**

`Dockerfile.prod` for both Drupal and Next.js do not `COPY` or `ARG` any secret values. Secrets enter only at runtime via `--env-file ~/nas_docker/.env`.

---

## 6. Database

### 6.1 Backups configured and running
**Status: ✅ Done**

`backup-onprem.sh` deployed via Ansible to `~/Scripts/`. launchd agent `com.wilkesliberty.backup` runs daily at 4:00 AM. Backup encrypted with AES-256 via `BACKUP_ENCRYPTION_KEY`. Synced to Proton Drive via rsync.

### 6.2 Backup restore tested
**Status: ❌ Not done**

No restore test procedure exists or has been performed. Backups are untested.

**Action (high priority):** Perform a restore test immediately. On a scratch volume or DDEV environment, restore the encrypted backup and verify Drupal bootstraps. Schedule quarterly.

### 6.3 App DB user is not a superuser
**Status: ❌ Not done — critical**

```
Role name | Attributes
drupal    | Superuser, Create role, Create DB, Replication, Bypass RLS
```

The `drupal` Postgres role has full superuser privileges. A SQL injection or Drupal RCE would have unrestricted database access.

**Action (high priority):** Create a least-privilege role:
```sql
CREATE ROLE drupal_app WITH LOGIN PASSWORD '...' NOSUPERUSER NOCREATEDB NOCREATEROLE;
GRANT ALL PRIVILEGES ON DATABASE drupal TO drupal_app;
\c drupal
GRANT ALL ON ALL TABLES IN SCHEMA public TO drupal_app;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO drupal_app;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO drupal_app;
```
Update `DRUPAL_DB_USER` in `.env.j2` and `drupal_db_user` in sops. Requires `make onprem` and a Drupal settings.php change.

### 6.4 Parameterized queries (no SQL injection)
**Status: ✅ Done**

See §4.2.

### 6.5 Separate dev and prod databases
**Status: ✅ Done**

Prod: `~/nas_docker/`, Staging: `~/nas_docker_staging/`, Dev: DDEV (separate Docker environment). Each has its own Postgres instance with separate credentials.

### 6.6 Schema changes in version control
**Status: ✅ Done**

Drupal schema changes use `.install` files (hook_update_N) committed to the webcms repo. No manual ALTER TABLE operations are needed or documented. Config changes go through `config:export`.

### 6.7 Connection pooling
**Status: N/A for this scale**

Drupal manages Postgres connections via its database layer. At current scale, no separate connection pooler (pgBouncer) is warranted. Revisit when concurrent connection count approaches Postgres `max_connections` (default 100).

---

## 7. Deployment & Operations

### 7.1 All environment variables set on production server
**Status: ✅ Done**

`make onprem` renders `~/nas_docker/.env` from `docker/.env.j2` + SOPS secrets. All required variables are Ansible-managed. Deploying without all sops keys will fail the playbook.

### 7.2 SSL certificates valid and auto-renewing
**Status: ✅ Done**

VPS: Caddy auto-HTTPS (Let's Encrypt ACME, auto-renews 30 days before expiry).
On-prem: certbot wildcard `*.int.wilkesliberty.com` via `letsencrypt` Ansible role; certbot deploy hook syncs to on-prem. Caddy internal uses the synced cert.

### 7.3 Services managed by a process supervisor
**Status: ✅ Done (adapted for this stack)**

All on-prem services run in Docker Compose with `restart: unless-stopped`. Docker daemon is managed by Docker Desktop on macOS with auto-start. Next.js on VPS is managed by systemd (`wl-vps-ui` Ansible role). The `common` role stub aside, Docker itself provides restart-on-failure for all containers.

### 7.4 Rollback procedure documented
**Status: ❌ Not done**

No rollback procedure is written down. `make onprem` is idempotent for config but does not handle code rollback (the Drupal image is rebuilt from the current `master` branch on each deploy).

**Action:** Document rollback: for Drupal, `git -C ~/Repositories/webcms checkout <previous-tag>` then `make onprem` (rebuilds image). For Next.js, `git -C ~/Repositories/ui checkout <previous-tag>` then `make vps`. For data, see backup restore (§6.2).

### 7.5 Staging tested before production deploy
**Status: ⚠️ Partial**

Staging environment exists and `make refresh-staging` is documented. There is no enforced gate — nothing in the deploy workflow requires staging sign-off before production.

**Action:** Add a checklist item to `DEPLOYMENT_CHECKLIST.md`: "Deploy to staging and smoke-test before deploying to production."

### 7.6 Auto-update policy for OS and packages
**Status: ❌ Not done**

No `unattended-upgrades` or equivalent is configured on the VPS. No documented cadence for Drupal security releases, Keycloak updates, Docker image refreshes.

**Action:** On VPS: `apt install unattended-upgrades` with security-only updates. Document monthly cadence for: `composer update drupal/core-*`, Docker image version bumps, Keycloak minor upgrades.

---

## 8. Logging & Monitoring

### 8.1 Application logs accessible and retained
**Status: ✅ Done**

Caddy: JSON logs at `/var/log/caddy/www.log`, `api.log`, `auth.log`, `internal.log`.
Drupal: `docker exec wl_drupal drush watchdog:show` (stored in DB, accessible via admin UI at `/admin/reports/dblog`).
Docker: `docker compose logs -f [service]`.
Config snapshot: `~/Backups/wilkesliberty/logs/config-snapshot.log` (30-day rotation).

### 8.2 Metrics and alerting active
**Status: ✅ Done**

Prometheus scrapes all services. 16 alert rules configured in `docker/prometheus/alerts.yml`. Alertmanager routes to email via Proton Mail SMTP. Grafana dashboards at `https://monitor.int.wilkesliberty.com`.

### 8.3 Log review procedure documented
**Status: ❌ Not done**

No documented log review procedure — what to check, how often, what anomaly signatures to look for.

**Action:** Document minimal weekly log review: `drush watchdog:show --severity=error`, Caddy access log grep for 4xx/5xx spikes, Prometheus alert status check.

---

## 9. Email Deliverability & Abuse

### 9.1 SPF/DKIM/DMARC configured
**Status: ⚠️ Partial**

Postmark requires and validates SPF and DKIM for sending domains. Assumed configured when Postmark was set up, but DNS records are not in this repo (managed via Njalla web UI, not Terraform — CAA records are noted as the same pattern). Cannot verify from the repo.

**Action:** Verify via `dig TXT wilkesliberty.com | grep -E "v=spf|DKIM|DMARC"`. Add DNS record verification to quarterly audit.

### 9.2 Bounce and complaint handling active
**Status: ✅ Done**

`wl_postmark_webhook` v2 auto-suppresses addresses on bounce/complaint events. Suppression list visible at `https://api.wilkesliberty.com/admin/reports/postmark-events`. Staging uses a sandbox Postmark server that cannot deliver to unverified addresses.

### 9.3 Transactional mail isolated from marketing
**Status: ✅ Done**

Single Postmark server for transactional. No marketing mail configured or planned.

---

## 10. Incident Response

### 10.1 Incident response plan documented
**Status: ❌ Not done**

No documented runbook for: compromised credential, data breach, service outage, supply chain compromise.

**Action:** Write a minimal incident response doc. Minimum contents:
- How to revoke a compromised SOPS key and re-encrypt all secrets files
- How to rotate a Postmark token (update sops → `make onprem`)
- How to rotate the Drupal OAuth client secret (Drupal UI → update sops → `make onprem`)
- How to restore from backup (see §6.2)
- Contact escalation (even if it's just "the on-call person is me")

### 10.2 Known good baseline documented
**Status: ⚠️ Partial**

`make onprem` is the canonical deploy and produces a known state. No snapshot of "known good" container image digests.

---

## 11. Compliance & Data Handling

### 11.1 PII inventory and retention policy
**Status: ❌ Not done**

Drupal collects: webform submission data (name, email, message), user accounts (email, name), watchdog logs (IP addresses). No documented retention or deletion policy.

**Action:** Define minimal retention policy. Webform submissions: review after 90 days, delete if no longer needed. User accounts: deactivate after X months inactive. Watchdog: already truncated on staging refresh; consider a cron-based rotation on production.

### 11.2 Staging sanitization (prevents PII leakage to staging)
**Status: ✅ Done**

`make refresh-staging` sanitizes: user emails → `noreply+stg-<uid>@wilkesliberty.com`, password hashes invalidated, webform submission emails rewritten, `remote_addr` → `127.0.0.1`, watchdog truncated. Staging SMTP uses a Postmark sandbox server — cannot email real users.

---

## Pre-Deployment Checklist

Run before every production deploy:

**Secrets & Credentials**
- [ ] All `*_secrets.yml` files are SOPS-encrypted (no plaintext)
- [ ] `~/nas_docker/.env` is not committed anywhere

**Security**
- [ ] `composer audit` run in webcms — no critical issues
- [ ] `npm audit` run in ui — no critical issues
- [ ] Staged on staging, smoke-tested

**Deployment**
- [ ] SSL certificates valid (`curl -vI https://api.wilkesliberty.com 2>&1 | grep -i expire`)
- [ ] All containers healthy after deploy (`docker compose ps`)
- [ ] `drush status` returns bootstrap = Successful
- [ ] Caddy serving correctly (`curl -o /dev/null -sw "%{http_code}" https://api.wilkesliberty.com/jsonapi`)

**Post-deploy spot-checks**
- [ ] Admin login works (`https://api.int.wilkesliberty.com/user/login`)
- [ ] No `error` entries in watchdog (`docker exec wl_drupal drush watchdog:show --severity=error --count=20`)
- [ ] Prometheus targets all UP (`https://metrics.int.wilkesliberty.com/targets`)

---

## Open Issues Summary

| Priority | Item | Section |
|----------|------|---------|
| 🔴 High | Drupal Postgres user has Superuser privileges | §6.3 |
| 🔴 High | SSH hardening not in Ansible (`common` role is a stub) | §3.6 |
| 🔴 High | Backup restore never tested | §6.2 |
| 🔴 High | Rate limiting commented out in Caddyfile | §4.5 |
| 🟡 Medium | Keycloak brute force / password policy / 2FA not configured | §2.6 |
| 🟡 Medium | No credential rotation schedule | §1.4 |
| 🟡 Medium | Rollback procedure not documented | §7.4 |
| 🟡 Medium | No dependency scanning (composer/npm audit) | §5.4 |
| 🟡 Medium | OS auto-updates not configured on VPS | §7.6 |
| 🟡 Medium | Dockerfile base images not fully pinned | §5.2 |
| 🟡 Medium | No incident response runbook | §10.1 |
| 🟡 Medium | PII retention policy not documented | §11.1 |
| 🟢 Low | CSP contains `unsafe-inline` / `unsafe-eval` | §3.3 |
| 🟢 Low | Webhook HMAC upgrade (currently URL-secret) | §4.6 |
| 🟢 Low | OAuth consumer token lifetime not version-controlled | §2.3 |
| 🟢 Low | SPF/DKIM/DMARC verification not automated | §9.1 |
| 🟢 Low | Caddy `request_body` size limit not set | §4.3 |
| 🟢 Low | Log review procedure not documented | §8.3 |
| 🟢 Low | Age private key backup not documented | §1.5 |
