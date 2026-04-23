# Open Issues & Planned Work

**What this is:** Central punch list for every known gap, deferred task, and upstream block across the WilkesLiberty stack. Add new items here as they surface; remove or move to [Changelog](#changelog) when resolved.

**Relationship to SECURITY_CHECKLIST.md:** The checklist is the steady-state audit (every section, with done/partial/not-done status). This doc is the actionable roadmap — only the open work, organized by theme, with owners and revisit targets.

**How to use:**
- When you find a gap during a deploy or audit, add it here immediately.
- When you fix something, move the row to the Changelog with a close date and one-line resolution.
- Cross-references point to the authoritative detail (SECURITY_CHECKLIST §x, STAGING_REFRESH.md, etc.).
- Severity: 🔴 High (exploitable/data loss risk) · 🟡 Medium (real gap, not immediately exploitable) · 🟢 Low (hardening, process improvement) · 🔵 Info (deferred enhancement, no security impact)

**Owner:** Jeremy (`3@wilkesliberty.com`)
**Last reviewed:** 2026-04-23

---

## 1. Security & Compliance

| Severity | Title | Description | Reference | Action owner | Revisit |
|----------|-------|-------------|-----------|-------------|---------|
| 🟡 Medium | Keycloak realm not configured | No realm, users, brute-force detection, password policy, or 2FA has been set up — Keycloak is running but inert. | [SECURITY_CHECKLIST §2.6](SECURITY_CHECKLIST.md), [ADMIN_SETUP §3](ADMIN_SETUP.md) | user | Next available window; blocks Grafana SSO |
| 🟡 Medium | No credential rotation schedule | No cadence defined for rotating: Drupal OAuth secret, simple_oauth consumer secret, Postmark token, Keycloak bootstrap admin, Tailscale auth key, backup encryption key. | [SECURITY_CHECKLIST §1.4](SECURITY_CHECKLIST.md) | user | Define schedule; add to quarterly checklist |
| 🟡 Medium | Age private key has no off-host backup | `~/.config/sops/age/keys.txt` has no documented procedure for off-host backup; loss means encrypted backups are unrecoverable. | [SECURITY_CHECKLIST §1.5](SECURITY_CHECKLIST.md) | user | Back up to password manager or cold storage ASAP |
| 🟡 Medium | No incident response runbook | No documented steps for: compromised SOPS key, data breach, service outage, Postmark token rotation, backup restore under duress. | [SECURITY_CHECKLIST §10.1](SECURITY_CHECKLIST.md) | user | Write minimal runbook; can be a single doc |
| 🟡 Medium | PII retention and deletion policy not documented | Drupal collects webform submissions (name/email/message), user accounts, watchdog logs (IP). No retention policy or deletion procedure written. | [SECURITY_CHECKLIST §11.1](SECURITY_CHECKLIST.md) | user | Define policy; add watchdog rotation cron |
| 🟡 Medium | No container image vulnerability scanning | No Trivy, Snyk, or Docker Scout in CI or as a pre-deploy step. Images built without automated CVE checking. | [SECURITY_CHECKLIST §5.3](SECURITY_CHECKLIST.md) | user | Add `trivy image` to deployment checklist; long-term: CI pipeline |
| 🟢 Low | CSP contains `unsafe-inline` / `unsafe-eval` on `www` | Current CSP on `www.wilkesliberty.com` uses `unsafe-inline` and `unsafe-eval`; noted in Caddyfile as needing tightening once Next.js nonce support is implemented. | [SECURITY_CHECKLIST §3.3](SECURITY_CHECKLIST.md) | user | When Next.js inline scripts are nonce-eligible |
| 🟢 Low | Webhook uses URL-embedded secret, not HMAC | `PostmarkWebhookController` uses `hash_equals` on a URL path segment. Postmark supports `X-Postmark-Signature` HMAC-SHA256, which is stronger and never exposes the secret in logs. | [SECURITY_CHECKLIST §4.6](SECURITY_CHECKLIST.md) | user | Next wl_postmark_webhook release |
| 🟢 Low | OAuth consumer token lifetime not version-controlled | `simple_oauth` consumer was created in Drupal UI; the entity (including token lifetime) is not in `config/sync/`. If the DB is wiped, lifetime must be reconfigured manually. | [SECURITY_CHECKLIST §2.3](SECURITY_CHECKLIST.md) | user | After next `drush config:export`, verify consumer entity is captured |
| 🟢 Low | SPF/DKIM/DMARC records not in automated audit | DNS records were set up via Njalla web UI when Postmark was configured but are not verified by any automated check or quarterly checklist step. | [SECURITY_CHECKLIST §9.1](SECURITY_CHECKLIST.md) | user | Add `dig TXT wilkesliberty.com` check to quarterly audit |
| 🟢 Low | Custom route access-check audit not done | `wl_api` routes need a pass to confirm all non-public endpoints have `_access` or `_permission` checks; no direct `$_GET`/`$_POST` usage. | [SECURITY_CHECKLIST §2.2, §4.1](SECURITY_CHECKLIST.md) | user | Run `drush route` spot-check; quarterly |
| 🟢 Low | No known-good container image digest baseline | No snapshot of image digests at last known-good deploy. Makes it harder to detect supply-chain tampering. | [SECURITY_CHECKLIST §10.2](SECURITY_CHECKLIST.md) | user | Capture `docker images --digests` after each successful deploy |

---

## 2. Deployment & Automation

| Severity | Title | Description | Reference | Action owner | Revisit |
|----------|-------|-------------|-----------|-------------|---------|
| 🟡 Medium | Rollback procedure not documented | `make onprem` rebuilds from current master; no written procedure for rolling back Drupal, Next.js, or data after a bad deploy. | [SECURITY_CHECKLIST §7.4](SECURITY_CHECKLIST.md) | user | Write one-pager: git checkout previous tag → make onprem/vps; data rollback → backup restore |
| 🟡 Medium | Dockerfile base images not pinned to patch versions | `drupal:11-apache` and `node:20-alpine` use floating minor tags; `composer:2` floats. A broken upstream patch could break builds silently. | [SECURITY_CHECKLIST §5.2](SECURITY_CHECKLIST.md) | user | Pin to patch during next quarterly Docker image update |
| 🟢 Low | No enforced staging sign-off gate before prod | `make onprem` has no gate requiring staging to be smoke-tested first. | [SECURITY_CHECKLIST §7.5](SECURITY_CHECKLIST.md) | user | Add checklist item to DEPLOYMENT_CHECKLIST.md |
| 🟢 Low | Log review procedure not documented | No written guide on what to check (drush watchdog, Caddy access logs, Prometheus alerts) or how often. | [SECURITY_CHECKLIST §8.3](SECURITY_CHECKLIST.md) | user | Add minimal weekly review steps to DEPLOYMENT_CHECKLIST.md |
| 🟢 Low | No Caddy `request_body` size limit | Neither the VPS nor internal Caddyfile sets a `request_body { max_size }` limit — large-body DoS against Drupal is possible from the public internet. | [SECURITY_CHECKLIST §4.3](SECURITY_CHECKLIST.md) | user | Add `request_body { max_size 50MB }` to `@api` matcher blocks in both Caddyfiles |

---

## 3. Upstream Blocks (waiting on external)

| Severity | Package | Installed | Required fix | Block reason | Action owner | Revisit |
|----------|---------|-----------|-------------|-------------|-------------|---------|
| 🟡 Medium | `webonyx/graphql-php` | v14.11.10 | ≥ 15.31.5 (CVE-2026-40476 — DoS via quadratic query complexity) | `drupal/graphql 4.13.0` constrains to `^14.x`; the fix is in v15 which requires `drupal/graphql` 5.x — no stable 5.x release yet | waiting upstream | Monitor `drupal/graphql` releases; update when 5.x stable ships |

---

## 4. Documentation & Process Gaps

| Severity | Title | Description | Reference | Action owner | Revisit |
|----------|-------|-------------|-----------|-------------|---------|
| 🟢 Low | Staging sanitization: revalidate/preview secrets are stale after refresh | After `make refresh-staging`, `next.next_site` `revalidate_url` and `preview_url` still hold prod values in the DB; functionally harmless (staging Next.js reads env vars) but confusing. | [STAGING_REFRESH.md — Remaining gaps](STAGING_REFRESH.md) | user | Add a `drush config:set` step to the refresh playbook to rewrite these values |
| 🟢 Low | Encrypted Proton Drive backup copy not tested | `make test-backup-restore` only validates the local unencrypted dump. The AES-encrypted copy synced to Proton Drive is never decrypted and tested. | [BACKUP_RESTORE.md](BACKUP_RESTORE.md) | user | Add optional `--encrypted` path to test-backup-restore.sh; test annually |
| 🟢 Low | Keycloak SSO logout session invalidation not verified | Once Keycloak SSO is active, the Grafana logout → Keycloak logout → session clear flow needs a live test. Currently nothing to verify against. | [SECURITY_CHECKLIST §2.5](SECURITY_CHECKLIST.md), [ADMIN_SETUP §3H](ADMIN_SETUP.md) | user | When Keycloak realm is configured and Grafana OAuth is wired |

---

## 5. Deferred Enhancements (not blocking, nice-to-have)

| Severity | Title | Description | Reference | Action owner | Revisit |
|----------|-------|-------------|-----------|-------------|---------|
| 🔵 Info | Grafana OAuth SSO not wired | Config block exists in `docker-compose.yml` (commented out). Needs: `grafana_oauth_client_secret` in sops, env var in `.env.j2`, uncomment OAuth block, `make onprem`. Requires Keycloak realm to exist first. | [ADMIN_SETUP §3F](ADMIN_SETUP.md) | user | After Keycloak realm is configured |
| 🔵 Info | Drupal `openid_connect` not enabled | Module is installed via composer but not enabled or wired in Ansible. Completing this would allow Drupal admin login via Keycloak SSO. | [ADMIN_SETUP §3F](ADMIN_SETUP.md) | user | After Keycloak realm + Grafana SSO verified |
| 🔵 Info | Uptime Kuma admin credentials not in sops | Kuma is self-provisioning on first boot; admin password is stored in a local database and must be saved to a password manager manually. No infra-managed backup of the credential. | [ADMIN_SETUP §7](ADMIN_SETUP.md) | user | Low priority; password manager is acceptable |
| 🔵 Info | Inert config_split definitions | `development`, `staging`, `production` splits are defined in Drupal config but have no storage path and are never activated — dead scaffolding. | [CONFIG_EXPORT.md — config_split](CONFIG_EXPORT.md) | user | Remove if still unused after Keycloak setup; keep `local` split |

---

## Changelog

Items are moved here when resolved, with a close date and one-line resolution.

| Closed | Item | Resolution |
|--------|------|-----------|
| 2026-04-23 | Backup launchd job silently failing (20-byte dumps) | Fixed: `export PATH` in script + plist `EnvironmentVariables`; prereq checks; size-validation; Postmark failure alerts. See [SECURITY_CHECKLIST §6.8](SECURITY_CHECKLIST.md). |
| 2026-04-23 | wl_app least-privilege DB role not implemented | Fixed: `wl_app` (non-superuser) created; Drupal connects as `wl_app`; keycloak DB access revoked from PUBLIC. See [SECURITY_CHECKLIST §6.3](SECURITY_CHECKLIST.md). |
| 2026-04-23 | No rate limiting on public endpoints | Fixed: custom Caddy binary with `mholt/caddy-ratelimit` deployed on VPS; 6 rate zones configured. See [SECURITY_CHECKLIST §4.5](SECURITY_CHECKLIST.md). |
| 2026-04-23 | SSH hardening not applied to VPS | Fixed: `common` role deployed — `PasswordAuthentication no`, `fail2ban`, `unattended-upgrades`. See [SECURITY_CHECKLIST §3.6](SECURITY_CHECKLIST.md). |
| 2026-04-23 | App update cadence not documented | Fixed: `docs/UPDATE_CADENCE.md` written with full cadence matrix, emergency response, and tooling commands. See [SECURITY_CHECKLIST §7.6](SECURITY_CHECKLIST.md). |
| 2026-04-23 | drupal/core 11.3.6 CVEs (SA-CORE-2026-001/002/003) | Fixed: updated to 11.3.8 via `composer update`; commit `66c655e` in webcms repo. |
| 2026-04-23 | Backup restore not tested | Fixed: `scripts/test-backup-restore.sh` written; `make test-backup-restore` target added. See [SECURITY_CHECKLIST §6.2](SECURITY_CHECKLIST.md). |
| 2026-04-23 | xcaddy not available in Homebrew for custom Caddy build | Fixed: replaced xcaddy with Caddy download API (`caddyserver.com/api/download`). |
