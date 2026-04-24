# Developer Security Practices

**Organization:** Wilkes & Liberty  
**Maintained by:** Jeremy Michael Cerda (`jmcerda@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23  
**Audience:** Internal reference · Prospective client review · Compliance assessment

This document describes the security practices Wilkes & Liberty follows in software development and infrastructure operations. It is intentionally grounded in what the team actually does today, not aspirational policy. A "Planned Improvements" section at the end captures known gaps.

---

## 1. Source Code & Version Control

**All code is tracked in Git.** The infrastructure repository (`infra`) and the application repository (`webcms`) are both hosted on GitHub (`github.com/Wilkes-Liberty`). No code is developed outside of version control.

**Secrets are never committed to source.** The `.gitignore` at repo root excludes all `*.env` files, `nas_docker/.env`, and any file matching `*_secrets.yml`. A `.sops.yaml` rule at repo root enforces SOPS+age encryption on any file matching `*_secrets.yml` before it can be committed. This is machine-enforced, not honor-system.

**Branch protections:** `master` is the production branch for both repos. Code changes follow a branch → merge → deploy workflow. Infrastructure changes that affect production are applied via `make onprem` or `make vps` — not by hand on live systems.

---

## 2. Secrets Management

All credentials and sensitive configuration values are stored exclusively in SOPS+age encrypted secret files under `ansible/inventory/group_vars/`:

| File | Contains |
|------|----------|
| `app_secrets.yml` | Drupal OAuth client secret, Postmark server token, webhook secrets, revalidation secrets |
| `sso_secrets.yml` | Keycloak admin password, Grafana admin password, PostgreSQL passwords, Redis password, Proton Mail SMTP credentials |
| `network_secrets.yml` | Tailscale IP addresses, device LAN IPs |
| `tailscale_secrets.yml` | Tailscale auth key |
| `staging_secrets.yml` | Staging-specific versions of all the above |

**How they're used:** Ansible decrypts these files at deploy time using the age private key (`$SOPS_AGE_KEY_FILE`) and writes values to `~/nas_docker/.env`, which is never committed, never readable by non-root users (`chmod 600`), and only lives on the operator's machine.

**No secret is ever**:
- Hardcoded in source code
- Passed as a command-line argument (it would appear in `ps` output)
- Logged (Ansible tasks that handle passwords use `no_log: true`)
- Embedded in Docker image layers (`Dockerfile.prod` uses only `ARG`-less `COPY` and secrets enter only at container runtime via `--env-file`)

**Rotation:** Credential rotation is on the remediation roadmap (see [OPEN_ISSUES.md §1](../OPEN_ISSUES.md) and [ACCESS_CONTROL.md](ACCESS_CONTROL.md) for the planned schedule).

---

## 3. Authentication & Access Control

**Production systems are not reachable from the public internet.** The on-prem server has zero public-facing ports. All application services (Drupal admin, Keycloak, Grafana, Prometheus, Alertmanager) are accessible only via Tailscale WireGuard VPN. The only public entry points are the Caddy reverse proxy on the Njalla VPS (ports 80/443).

**Least-privilege database access.** Drupal connects to PostgreSQL as `wl_app` — a role with no SUPERUSER, no CREATEDB, no REPLICATION, and access only to the `drupal` database. The keycloak database has `CONNECT` revoked from `PUBLIC`. The management superuser `postgres` is used only by Ansible automation, never by application code.

**API authentication.** The public JSON:API is intentionally read-only for anonymous users (headless CMS pattern). State-changing endpoints require OAuth2 `client_credentials` tokens issued by Drupal's `simple_oauth` module. Webhook endpoints use timing-safe `hash_equals` verification of a URL-embedded secret.

**SSH.** The Njalla VPS has `PasswordAuthentication no` enforced at the SSH daemon level. Only public-key authentication is accepted. `fail2ban` bans source IPs after 5 failed authentication attempts.

**Planned:** Keycloak SSO with MFA enforced for admin accounts. See [OPEN_ISSUES.md §6](../OPEN_ISSUES.md).

---

## 4. Encryption in Transit

All client-facing traffic is served over TLS. HTTP is unconditionally redirected to HTTPS at the Caddy layer — there is no opt-out path.

- **VPS (public):** Caddy auto-HTTPS via Let's Encrypt ACME. Certificate renews automatically 30 days before expiry.
- **On-prem (internal):** certbot wildcard `*.int.wilkesliberty.com` obtained via Let's Encrypt DNS-01 challenge. Cert is synced to the on-prem server by an Ansible-deployed deploy hook.
- **Minimum TLS version:** TLS 1.2 enforced in both Caddyfiles (`protocols tls1.2 tls1.3`).
- **VPN transport:** Tailscale uses WireGuard (ChaCha20-Poly1305 + Curve25519) for all on-prem ↔ VPS traffic.

**Encryption at rest:**
- Daily database backups are AES-256 encrypted before Proton Drive sync (`openssl enc -aes-256-cbc`).
- The SOPS age private key is protected by the host OS keychain and stored only on the operator's workstation.

---

## 5. Dependency Management & Vulnerability Scanning

Dependencies are managed with documented audit cadences. See [UPDATE_CADENCE.md](../UPDATE_CADENCE.md) for the full matrix. Summary:

| Layer | Audit tool | Check frequency | Security patch window |
|-------|-----------|-----------------|----------------------|
| Drupal/PHP (composer) | `composer audit` via Docker | Weekly | 7 days |
| Next.js/npm | `npm audit` | Monthly | 7 days |
| Python/Ansible | `pip-audit`, `ansible-galaxy` | Quarterly | Best effort |
| Docker base images | Manual comparison vs release notes | Monthly | Best effort |

**First applied (2026-04-23):** `composer audit` identified 4 advisories. Three (`drupal/core` XSS + gadget chain — SA-CORE-2026-001/002/003) were patched immediately (11.3.6 → 11.3.8). One (`webonyx/graphql-php` DoS) is blocked upstream and tracked in [OPEN_ISSUES.md](../OPEN_ISSUES.md).

**Commit convention for security updates:** `security: <component> <old> → <new> (<SA/CVE>)`. Audit trail: `git log --grep="security:" --oneline`.

---

## 6. Deployment Pipeline

All deployments are driven by Ansible (`make onprem`, `make vps`) — no manual steps on live systems. Key properties:

- **Idempotent:** `make onprem` can be re-run safely at any time. It produces the same state regardless of current system state.
- **Secrets injected at runtime:** `~/nas_docker/.env` is rendered by Ansible from SOPS-encrypted sources at deploy time. It is never committed.
- **Staging gate:** A staging environment mirrors production. Staging is refreshed from production via `make refresh-staging` (sanitizes PII before refresh). Deployments should be tested on staging before applying to production.
- **Rollback:** Git-based — `git checkout <previous-tag>` in the relevant repo followed by `make onprem` or `make vps` redeploys the prior version. Data rollback uses the backup restore procedure ([BACKUP_RESTORE.md](../BACKUP_RESTORE.md)).

---

## 7. Monitoring & Incident Detection

- **Prometheus** scrapes metrics from all services. 16 alert rules are configured covering service health, disk usage, response time, and error rates.
- **Alertmanager** routes alerts to `jmcerda@wilkesliberty.com` via Proton Mail SMTP.
- **Drupal watchdog** captures application-level errors; reviewable at `/admin/reports/dblog` and via `drush watchdog:show`.
- **Caddy JSON logs** are written to `/var/log/caddy/` on the VPS for each vhost.
- **Backup failure alerts** are sent via Postmark if the daily backup script detects Docker unavailability, container downtime, or an undersized dump.

See [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md) for the full incident response procedure.

---

## 8. Security Headers & Application Hardening

The following security headers are applied to all public responses by Caddy:

| Header | Value |
|--------|-------|
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains; preload` |
| `X-Frame-Options` | `SAMEORIGIN` |
| `X-Content-Type-Options` | `nosniff` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | camera, mic, geolocation, payment all blocked |
| `Content-Security-Policy` | Present; currently permits `unsafe-inline`/`unsafe-eval` (see planned improvements) |
| `Access-Control-Allow-Origin` | Locked to `https://www.wilkesliberty.com` — no wildcard |

**Rate limiting** is active on all public endpoints via a custom Caddy binary (`v2.11.2` + `mholt/caddy-ratelimit`). Login endpoints are restricted to 10 req/min per IP; general API traffic to 300 req/min per IP.

---

## 9. Supply Chain Integrity

**Composer (PHP/Drupal):** `composer.lock` pins every package to a specific version and SHA-256 hash. The hash is verified on every `composer install`. Packages are fetched from `packagist.org` (HTTPS only). `composer audit` is run against the advisory database on the schedule above.

**npm (Next.js):** `package-lock.json` pins all transitive dependencies. `npm audit` checks for known CVEs. Updates are applied individually, not via blanket upgrade.

**Docker images:** Base images are pinned to specific minor versions in `Dockerfile.prod` (e.g., `drupal:11-apache`, `node:20-alpine`). Full patch pinning is on the roadmap (see Planned Improvements below).

**Ansible collections:** `community.general` and `community.sops` are installed from Ansible Galaxy. Version pinning via `requirements.yml` is on the roadmap.

**Build reproducibility:** Docker multi-stage builds produce deterministic images from the locked `composer.lock` and `package-lock.json`. The build context includes only the application source directories — no host credentials or environment secrets are baked into images.

**Container isolation:** Application containers run as non-root users (`www-data` for Drupal, `nextjs` UID 1001 for Next.js). Each service is on a separate Docker network with explicit inter-service allow-listing.

---

## 10. Planned Improvements

| Item | Target | Reference |
|------|--------|-----------|
| Keycloak SSO + MFA for all admin accounts | Next available window | [OPEN_ISSUES.md](../OPEN_ISSUES.md) |
| Pin Dockerfile base images to specific patch versions | Next quarterly Docker update | [OPEN_ISSUES.md](../OPEN_ISSUES.md) |
| Add `trivy image` pre-deploy scan to deployment checklist | Near-term | [OPEN_ISSUES.md](../OPEN_ISSUES.md) |
| Tighten CSP with nonce-based inline script allowlisting | After Next.js nonce audit | [OPEN_ISSUES.md](../OPEN_ISSUES.md) |
| Replace URL-secret webhook with Postmark HMAC-SHA256 | Next module release | [OPEN_ISSUES.md](../OPEN_ISSUES.md) |
| Formalize credential rotation cadence | Near-term | [ACCESS_CONTROL.md](ACCESS_CONTROL.md) |
| Tailscale ACL tag policy (on Premium activation) | After Tailscale upgrade | [OPEN_ISSUES.md](../OPEN_ISSUES.md) |
| CI/CD pipeline with automated security scanning | Medium-term | [OPEN_ISSUES.md](../OPEN_ISSUES.md) |
