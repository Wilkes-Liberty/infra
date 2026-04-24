# Open Issues & Planned Work

**What this is:** Central punch list for every known gap, deferred task, and upstream block across the WilkesLiberty stack. Add new items here as they surface; remove or move to [Changelog](#changelog) when resolved.

**Relationship to SECURITY_CHECKLIST.md:** The checklist is the steady-state audit (every section, with done/partial/not-done status). This doc is the actionable roadmap — only the open work, organized by theme, with owners and revisit targets.

**How to use:**
- When you find a gap during a deploy or audit, add it here immediately.
- When you fix something, move the row to the Changelog with a close date and one-line resolution.
- Cross-references point to the authoritative detail (SECURITY_CHECKLIST §x, STAGING_REFRESH.md, etc.).
- Severity: 🔴 High (exploitable/data loss risk, or required for federal contracting) · 🟡 Medium (real gap, not immediately exploitable) · 🟢 Low (hardening, process improvement) · 🔵 Info (deferred enhancement, no security impact)

**Owner:** Jeremy (`jmcerda@wilkesliberty.com`)
**Last reviewed:** 2026-04-23

---

## 1. Security & Compliance

| Severity | Title | Description | Reference | Action owner | Revisit |
|----------|-------|-------------|-----------|-------------|---------|
| 🔴 High _(upgraded 2026-04-23: federal contracting direction)_ | Keycloak realm not configured | No realm, users, brute-force detection, password policy, or 2FA has been set up — Keycloak is running but inert. MFA is a baseline expectation for federal contractors. | [SECURITY_CHECKLIST §2.6](SECURITY_CHECKLIST.md), [ADMIN_SETUP §3](ADMIN_SETUP.md), POA&M #AC-3 | user | Next available window; blocks Grafana SSO and all MFA items |
| 🔴 High _(upgraded 2026-04-23: federal contracting direction)_ | No credential rotation schedule | No cadence defined for rotating: Drupal OAuth secret, simple_oauth consumer secret, Postmark token, Keycloak bootstrap admin, Tailscale auth key, backup encryption key. NIST 800-171 3.5.x requires this. | [SECURITY_CHECKLIST §1.4](SECURITY_CHECKLIST.md), [ACCESS_CONTROL.md](compliance/ACCESS_CONTROL.md), POA&M #IA-4 | user | Define schedule; add to annual calendar |
| 🟡 Medium | Age private key has no off-host backup | `~/.config/sops/age/keys.txt` has no documented procedure for off-host backup; loss means encrypted backups are unrecoverable. | [SECURITY_CHECKLIST §1.5](SECURITY_CHECKLIST.md) | user | Back up to password manager or cold storage ASAP |
| 🔴 High _(upgraded 2026-04-23: federal contracting direction)_ | No incident response plan | No documented steps for: compromised credential, data breach, service outage. See [INCIDENT_RESPONSE.md](compliance/INCIDENT_RESPONSE.md) for the draft plan. NIST 800-171 3.6.x control family. | [SECURITY_CHECKLIST §10.1](SECURITY_CHECKLIST.md), [INCIDENT_RESPONSE.md](compliance/INCIDENT_RESPONSE.md), POA&M #IR-1 | user | Review and sign off on INCIDENT_RESPONSE.md draft |
| 🔴 High _(upgraded 2026-04-23: federal contracting direction)_ | PII retention and deletion policy not documented | Drupal collects webform submissions (name/email/message), user accounts, watchdog logs (IP). No retention policy or deletion procedure. Required for any contract touching federal agency personnel data. | [SECURITY_CHECKLIST §11.1](SECURITY_CHECKLIST.md), [DATA_CLASSIFICATION.md](compliance/DATA_CLASSIFICATION.md), POA&M #MP-5 | user | Define policy; add watchdog rotation cron |
| 🟡 Medium | No container image vulnerability scanning | No Trivy, Snyk, or Docker Scout in CI or as a pre-deploy step. Images built without automated CVE checking. | [SECURITY_CHECKLIST §5.3](SECURITY_CHECKLIST.md), POA&M #SI-2 | user | Add `trivy image` to DEPLOYMENT_CHECKLIST.md; CI pipeline long-term |
| 🟢 Low | CSP contains `unsafe-inline` / `unsafe-eval` on `www` | Current CSP on `www.wilkesliberty.com` uses `unsafe-inline` and `unsafe-eval`; needs nonces once Next.js inline scripts are audited. | [SECURITY_CHECKLIST §3.3](SECURITY_CHECKLIST.md) | user | When Next.js inline scripts are nonce-eligible |
| 🟢 Low | Webhook uses URL-embedded secret, not HMAC | `PostmarkWebhookController` uses `hash_equals` on a URL path segment. Postmark supports `X-Postmark-Signature` HMAC-SHA256, which is stronger. | [SECURITY_CHECKLIST §4.6](SECURITY_CHECKLIST.md) | user | Next wl_postmark_webhook release |
| 🟢 Low | OAuth consumer token lifetime not version-controlled | `simple_oauth` consumer created in Drupal UI; entity not in `config/sync/`. If DB is wiped, token lifetime must be manually reconfigured. | [SECURITY_CHECKLIST §2.3](SECURITY_CHECKLIST.md) | user | After next `drush config:export`, verify consumer entity captured |
| 🟡 Medium _(upgraded 2026-04-23: federal contracting direction)_ | SPF/DKIM/DMARC records not in automated audit | DNS records were set up via Njalla web UI when Postmark was configured but are not verified by any automated check. Federal email security guidelines expect this. | [SECURITY_CHECKLIST §9.1](SECURITY_CHECKLIST.md) | user | Add `dig TXT wilkesliberty.com` check to quarterly audit |
| 🟡 Medium _(upgraded 2026-04-23: federal contracting direction)_ | Custom route access-check audit not done | `wl_api` routes need a pass to confirm all non-public endpoints have `_access` or `_permission` checks; no direct `$_GET`/`$_POST` usage. Code security review expected for CUI systems. | [SECURITY_CHECKLIST §2.2, §4.1](SECURITY_CHECKLIST.md) | user | Run `drush route` spot-check; quarterly |
| 🟢 Low | No known-good container image digest baseline | No snapshot of image digests at last known-good deploy. Makes it harder to detect supply-chain tampering. | [SECURITY_CHECKLIST §10.2](SECURITY_CHECKLIST.md) | user | Capture `docker images --digests` after each successful deploy |

---

## 2. Deployment & Automation

| Severity | Title | Description | Reference | Action owner | Revisit |
|----------|-------|-------------|-----------|-------------|---------|
| 🔴 High _(upgraded 2026-04-23: federal contracting direction)_ | Rollback procedure not documented | `make onprem` rebuilds from current master; no written procedure for rolling back Drupal, Next.js, or data after a bad deploy. CM-9 (configuration management plan) requires this. | [SECURITY_CHECKLIST §7.4](SECURITY_CHECKLIST.md), [CONFIG_MANAGEMENT.md](compliance/CONFIG_MANAGEMENT.md), POA&M #CM-4 | user | Write one-pager: git checkout previous tag → make onprem/vps; data rollback → backup restore |
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
| 🟢 Low | Staging sanitization: revalidate/preview secrets are stale after refresh | After `make refresh-staging`, `next.next_site` `revalidate_url` and `preview_url` still hold prod values in the DB; functionally harmless but confusing. | [STAGING_REFRESH.md — Remaining gaps](STAGING_REFRESH.md) | user | Add a `drush config:set` step to the refresh playbook to rewrite these values |
| 🟢 Low | Encrypted Proton Drive backup copy not tested | `make test-backup-restore` only validates the local unencrypted dump. The AES-encrypted copy synced to Proton Drive is never decrypted and tested. | [BACKUP_RESTORE.md](BACKUP_RESTORE.md) | user | Add optional `--encrypted` path to test-backup-restore.sh; test annually |
| 🟢 Low | Keycloak SSO logout session invalidation not verified | Once Keycloak SSO is active, the Grafana logout → Keycloak logout → session clear flow needs a live test. Currently nothing to verify against. | [SECURITY_CHECKLIST §2.5](SECURITY_CHECKLIST.md), [ADMIN_SETUP §3H](ADMIN_SETUP.md) | user | When Keycloak realm is configured and Grafana OAuth is wired |

---

## 5. Deferred Enhancements (not blocking, nice-to-have)

| Severity | Title | Description | Reference | Action owner | Revisit |
|----------|-------|-------------|-----------|-------------|---------|
| 🔵 Info | Grafana OAuth SSO not wired | Config block exists in `docker-compose.yml` (commented out). Needs: `grafana_oauth_client_secret` in sops, env var in `.env.j2`, uncomment OAuth block, `make onprem`. Requires Keycloak realm first. | [ADMIN_SETUP §3F](ADMIN_SETUP.md) | user | After Keycloak realm is configured |
| 🔵 Info | Drupal `openid_connect` not enabled | Module is installed via composer but not enabled or wired in Ansible. Completing this would allow Drupal admin login via Keycloak SSO. | [ADMIN_SETUP §3F](ADMIN_SETUP.md) | user | After Keycloak realm + Grafana SSO verified |
| 🔵 Info | Uptime Kuma admin credentials not in sops | Kuma is self-provisioning on first boot; admin password is stored in a local database and must be saved to a password manager manually. | [ADMIN_SETUP §7](ADMIN_SETUP.md) | user | Low priority; password manager is acceptable |
| 🔵 Info | Inert config_split definitions | `development`, `staging`, `production` splits are defined in Drupal config but have no storage path and are never activated — dead scaffolding. | [CONFIG_EXPORT.md — config_split](CONFIG_EXPORT.md) | user | Remove if still unused after Keycloak setup; keep `local` split |

---

## 6. Federal Compliance Readiness

_Updated 2026-04-23. W&L infrastructure is not in scope of the EPA contract (EPA work runs on a separate device). These items document gaps between current state and aspirational federal-readiness posture, plus current-relevance items for the principal's Tier 4 Public Trust credentialing. See `docs/compliance/` for all documents._

| Severity | Title | Description | Target document | Action owner | Revisit |
|----------|-------|-------------|----------------|-------------|---------|
| 🟡 Medium | Developer Security Practices one-pager | Bid-facing doc describing SDLC controls, credential management, deployment practices, and code security posture. Much of the underlying practice already exists; doc formalizes it. | [docs/compliance/DEVELOPER_SECURITY.md](compliance/DEVELOPER_SECURITY.md) | user + code session | Draft ready — review and customize |
| 🟡 Medium | Supply Chain Integrity statement | Companion section within DEVELOPER_SECURITY.md describing dependency pinning, audit cadence, bill-of-materials approach, and build reproducibility. | [docs/compliance/DEVELOPER_SECURITY.md §Supply Chain](compliance/DEVELOPER_SECURITY.md) | user + code session | Draft ready — review and customize |
| 🔴 High | System Security Plan (SSP) | Maps all 110 NIST 800-171 Rev 2 controls to implementation status in this stack. Centerpiece doc for any federal bid. | [docs/compliance/SSP.md](compliance/SSP.md) | user + code session | Draft ready — requires legal entity name and review of each control |
| 🔴 High | Plan of Action & Milestones (POA&M) | Tracks partially-implemented 800-171 controls with owners and remediation dates. Living doc; updates as gaps close. | [docs/compliance/POAM.md](compliance/POAM.md) | user + code session | Draft ready — review and set real dates |
| 🟡 Medium | Configuration Management Plan | Formalizes how changes are tracked (git), tested (staging), and deployed (make onprem). Much of this is already practiced; doc makes it auditable. | [docs/compliance/CONFIG_MANAGEMENT.md](compliance/CONFIG_MANAGEMENT.md) | user + code session | Draft ready — review |
| 🟡 Medium | Access Control Policy | Defines who has what access to which systems, how access is granted/revoked, role definitions, and periodic review cadence. | [docs/compliance/ACCESS_CONTROL.md](compliance/ACCESS_CONTROL.md) | user + code session | Draft ready — fill in employee names when team grows |
| 🟡 Medium | Data Classification & Handling Policy | Describes data the business handles, classification tiers (public / internal / confidential / CUI), and handling rules for each. | [docs/compliance/DATA_CLASSIFICATION.md](compliance/DATA_CLASSIFICATION.md) | user + code session | Draft ready — confirm CUI scope before first federal contract |
| 🟡 Medium | Business Continuity & Disaster Recovery Plan (BCDR) | Formalizes RTO/RPO targets, backup restore procedure, and DR test cadence. Consolidates BACKUP_RESTORE.md content. | [docs/compliance/BCDR.md](compliance/BCDR.md) | user + code session | Draft ready — fill in RTO/RPO targets |
| 🟡 Medium | Incident Response Plan | NIST 800-61 aligned. Detection, triage, containment, eradication, recovery, post-incident review. Contact tree. 72-hour reporting procedure. | [docs/compliance/INCIDENT_RESPONSE.md](compliance/INCIDENT_RESPONSE.md) | user + code session | Draft ready — fill in contact tree; this resolves §1 item "No incident response plan" |
| 🟡 Medium | Vendor Risk Management | Lists all third-party vendors (Postmark, Tailscale, Njalla, Proton Drive, GitHub), data each can access, SOC 2/FedRAMP status, and review cadence. | [docs/compliance/VENDOR_RISK.md](compliance/VENDOR_RISK.md) | user + code session | Draft ready — verify vendor SOC 2 status annually |
| 🟡 Medium | Onboarding runbook | Day-1 access provisioning, required training, tools to install, docs to read. Placeholder names; fill in as team grows. | [docs/team/ONBOARDING.md](team/ONBOARDING.md) | user + code session | Draft ready — personalize for first hire |
| 🔴 High | Offboarding runbook | Access revocation checklist, credential rotation, hardware return, data retention. Critical for compliance when employees leave. | [docs/team/OFFBOARDING.md](team/OFFBOARDING.md) | user + code session | Draft ready — validate against all access points |
| 🟡 Medium | Roles & Responsibilities (RACI) | Documents who is responsible for security, backups, incident response, code review, etc. Written for future team even if solo today. | [docs/team/ROLES.md](team/ROLES.md) | user + code session | Draft ready — fill in real names as team grows |
| 🟡 Medium | Security Awareness Training cadence | What training new hires receive, annual refreshers, phishing-awareness procedure. | [docs/team/SECURITY_TRAINING.md](team/SECURITY_TRAINING.md) | user + code session | Draft ready — review and adapt |
| 🟢 Low | Tailscale Premium activation checklist | ~~Once upgraded~~ **In progress** — Premium activated 2026-04-23. Docs written. Remaining: assign device tags, apply ACL JSON (pending sign-off), enable SSH on VPS via Ansible, configure flow log destination. | [docs/TAILSCALE_PREMIUM.md](TAILSCALE_PREMIUM.md) | user — dashboard + Ansible update | See activation checklist in TAILSCALE_PREMIUM.md |
| 🟢 Low | Tailscale tag taxonomy & ACL design | ~~Draft pending~~ **In progress** — [TAILSCALE_ACL_DESIGN.md](TAILSCALE_ACL_DESIGN.md) written with full tag taxonomy, ACL HuJSON, test assertions, and sign-off checklist. Pending: owner review → apply to tailnet. | [docs/TAILSCALE_ACL_DESIGN.md](TAILSCALE_ACL_DESIGN.md) | user — review ACL doc, then apply | Review TAILSCALE_ACL_DESIGN.md and sign off |
| 🟡 Medium | Document Tier 4 continuous-evaluation self-reporting obligations | Tier 4 Public Trust positions require self-reporting of specified life events (foreign travel, foreign contacts, financial hardship, cohabitant changes, arrests/charges). Self-reporting routes through the immediate prime (clearance sponsor of record), not directly to the agency or higher-tier prime. The specific triggers and timelines are set by the immediate prime's FSO. These are not documented anywhere in this repo. | [docs/COMPANY_PROFILE.md](COMPANY_PROFILE.md) | user — consult immediate prime's FSO | Before next period of performance renewal or SF-86 re-investigation |

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
