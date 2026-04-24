# Next Steps — W&L Infra & Compliance Buildout

**Owner:** Jeremy Michael Cerda (`jmcerda@wilkesliberty.com`)  
**Written:** 2026-04-23  
**Status:** Compliance and infrastructure buildout docs complete — ready for execution

---

## Today's Status

The compliance and infrastructure documentation buildout is complete. This covers: identity standardization (Jeremy Michael Cerda / jmcerda@wilkesliberty.com throughout), NIST 800-171 evidence docs (`docs/compliance/`), team docs (`docs/team/`), Tailscale design docs, past performance records (`docs/PAST_PERFORMANCE.md`), and the active work dashboard (`docs/PROJECT_PLAN.md`). Tailscale Premium is activated. Keycloak is deployed but not yet configured. Phase A is the unblocked starting point for tomorrow.

---

## Ordered Execution Plan

### Phase A — Keycloak Foundation
**Estimate:** ~1.5 hours  
**Blockers:** None — start here  
**Reference:** `docs/PROJECT_PLAN.md` Phase A, `docs/ADMIN_SETUP.md` §3

1. Log in to `https://auth.int.wilkesliberty.com/admin` (password from `sops ansible/inventory/group_vars/sso_secrets.yml`)
2. Create realm: `wilkesliberty`
3. Configure realm settings:
   - Login tab: brute-force protection ON, remember-me OFF
   - Tokens tab: access token 15 min, refresh 8h
   - Email tab: confirm Postmark SMTP is wired (test send)
4. Create realm roles: `admin`, `dev`, `contractor`, `readonly`, `drupal-admin`, `grafana-admin`
5. Create user `jmcerda` (Jeremy Michael Cerda, `jmcerda@wilkesliberty.com`), assign all admin roles, set permanent password
6. Trigger and receive a password reset email to confirm Postmark SMTP is working end-to-end

**Exit criteria:** `wilkesliberty` realm exists; `jmcerda` user created with all admin roles; password reset email arrives via Postmark.  
**Unblocks after completion:** Phase B, Phase D (can run in parallel after Phase A)

---

### Phase B — Tailscale ↔ Keycloak Custom OIDC
**Estimate:** ~1 hour  
**Blockers:** Phase A complete  
**Reference:** `docs/PROJECT_PLAN.md` Phase B, `docs/TAILSCALE_PREMIUM.md`

1. In Keycloak (`wilkesliberty` realm): create OIDC client named `tailscale`
   - Configure redirect URIs per Tailscale's custom OIDC docs
   - Generate and save client secret
2. In Tailscale admin console: **User Management → SSO → Custom OIDC**
   - Enter Keycloak issuer URL: `https://auth.int.wilkesliberty.com/realms/wilkesliberty`
   - Enter client ID: `tailscale`
   - Enter client secret from step 1
3. Keep prior IdP active during cutover — existing devices stay enrolled
4. Re-authenticate each enrolled device via Keycloak
5. Verify devices appear in admin console under the Keycloak-sourced identity
6. After 24 hours stable: disable and remove the old IdP

**Exit criteria:** All enrolled devices show Keycloak identity in Tailscale admin; old IdP removed.  
**Unblocks after completion:** Phase C

---

### Phase C — Tailscale ACL Application
**Estimate:** ~30 minutes  
**Blockers:** Phase B complete; review `docs/TAILSCALE_ACL_DESIGN.md` and sign off  
**Reference:** `docs/PROJECT_PLAN.md` Phase C, `docs/TAILSCALE_ACL_DESIGN.md`

1. Review `docs/TAILSCALE_ACL_DESIGN.md` end-to-end — confirm port numbers and device-to-tag mapping are correct
2. In Tailscale admin console: assign tags to each enrolled device
   - On-prem macOS server → `tag:onprem-server`
   - Njalla VPS → `tag:vps`
   - Jeremy's operator laptop → `tag:admin`
3. Apply the ACL HuJSON from `docs/TAILSCALE_ACL_DESIGN.md`
4. Test critical paths:
   - SSH to on-prem from operator device ✓
   - SSH to VPS from operator device ✓
   - VPS → on-prem Drupal (`:8080`) reachable ✓
   - VPS → on-prem PostgreSQL (`:5432`) blocked ✓
5. Run `tailscale acl test` from the CLI to confirm built-in test assertions pass
6. Sign the ACL sign-off checklist in `docs/TAILSCALE_ACL_DESIGN.md`

**Exit criteria:** ACL active; all built-in test assertions pass; VPS→on-prem proxy confirmed; DB port blocked.  
**Unblocks after completion:** Phase C is self-contained; Phase D can begin independently after Phase A

---

### Phase D — Spouse Break-Glass Account (Business Continuity)
**Estimate:** ~30 minutes  
**Blockers:** Phase A complete (Keycloak realm must exist) — can run concurrently with Phases B/C  
**Reference:** `docs/PROJECT_PLAN.md` Phase D

1. In Keycloak (`wilkesliberty` realm): create user `acerda`, email `acerda@wilkesliberty.com`, no active realm roles
2. Set a strong password; store in the shared password manager in a vault Aleksandra can access
3. Enroll Aleksandra's device in the Tailscale tailnet; assign `tag:business-continuity`
4. Verify she can reach on-prem services (`:8080`, `:8081`, `:3001`) and SSH to on-prem/VPS
5. Document the break-glass procedure in the password manager (which services to check, who to contact)
6. Review Tailscale audit log to confirm device enrollment events are captured

**Exit criteria:** `acerda` Keycloak account exists; device enrolled with `tag:business-continuity`; reachability confirmed; audit log reviewed.

---

### Post-Phase-D Items (Newly Unblocked)

Once all four phases are complete:

5. **Drupal `openid_connect` SSO wiring** (~1h) — wire Drupal admin login through Keycloak; closes OPEN_ISSUES §5. Reference: `docs/ADMIN_SETUP.md` §3F.
6. **Grafana OAuth activation** (~45 min) — last major SSO gap; all admin UIs use Keycloak identity. Requires sops change for `grafana_oauth_client_secret`. Reference: `docs/ADMIN_SETUP.md` §3F, `docs/OPEN_ISSUES.md` §5.
7. **POA&M target dates** — set real remediation dates for open POA&M items now that identity infrastructure is stable. Reference: `docs/compliance/POAM.md`.
8. **Credential rotation schedule** — define cadence + calendar for the 8 credential types in OPEN_ISSUES §1. Reference: `docs/compliance/ACCESS_CONTROL.md`.

---

## Things Only Jeremy Can Do

These are blocked on Jeremy's direct input — code sessions cannot complete them. Pull from `docs/PAST_PERFORMANCE.md` Action Items and `docs/OPEN_ISSUES.md` §6.

| # | Action | Priority | Where to record the result |
|---|--------|----------|---------------------------|
| 1 | Fill all `[FILL IN by Jeremy]` fields in `docs/PAST_PERFORMANCE.md` (dates, scope, frameworks, reference contacts) | Before any bid | `docs/PAST_PERFORMANCE.md` |
| 2 | Inventory retained CMS compliance artifacts (SSPs, training certs, audit logs from the HHS/CMS engagement) | Before first bid prep | `docs/PAST_PERFORMANCE.md` §1 Notes |
| 3 | Contact Scope Infotec and confirm they will serve as a past-performance reference | Before any bid | `docs/PAST_PERFORMANCE.md` §1, reference field |
| 4 | Contact ECS Tech / ECS Federal and confirm Postal OIG reference availability | Before any bid | `docs/PAST_PERFORMANCE.md` §2 Engagement C |
| 5 | Self-check Gridiron IT outside-employment policy — confirm W&L is appropriately disclosed to Gridiron HR/FSO if their policy requires it | ASAP | `docs/OPEN_ISSUES.md` §6 (mark resolved when done) |
| 6 | Confirm whether citing EPA/Gridiron IT experience on W&L proposals is permitted under Gridiron IT's proprietary-information or outside-employment provisions | Before any bid | `docs/PAST_PERFORMANCE.md` §2 Engagement A note |
| 7 | OCI / FAR 9.504 analysis — when W&L begins bidding, analyze apparent/actual OCI for any bids touching EPA/HHS-adjacent agencies given concurrent Gridiron IT employment | Before any federal bid touching EPA-adjacent work | `docs/COMPANY_PROFILE.md`, OPEN_ISSUES §6 |
| 8 | Tier 4 continuous-evaluation self-reporting triggers — consult Gridiron IT FSO on specific triggers/timelines; note any relevant W&L infrastructure events that may require reporting | ASAP | `docs/COMPANY_PROFILE.md` §Continuous Evaluation |
| 9 | SBA affiliation analysis — engage an SBA-familiar attorney before any W&L set-aside filing | Before first set-aside certification | `docs/OPEN_ISSUES.md` §6 |
| 10 | Attach current resume to repo for extraction into `docs/resume/` (redacted version — no phone/address) | Before first bid prep | `docs/resume/` (new directory) |
| 11 | Fill in legal counsel contact and client notification contacts in `docs/compliance/INCIDENT_RESPONSE.md` contact tree | Before plan is operational | `docs/compliance/INCIDENT_RESPONSE.md` |
| 12 | Review and sign off on `docs/compliance/SSP.md` per-control review; set real dates in `docs/compliance/POAM.md` | Before any federal bid | `docs/compliance/SSP.md`, `docs/compliance/POAM.md` |
| 13 | **Enable Advanced Data Protection in iCloud** — extends E2E encryption to iCloud Backup, Notes, Photos. Settings → [Your Name] → iCloud → Advanced Data Protection → Turn On. | ASAP | `docs/compliance/PHYSICAL_SECURITY.md` §4.1, `docs/OPEN_ISSUES.md` §7 |
| 14 | **Confirm HomePods are physically out of office** — verify all 4 HomePods are in non-office rooms; disable "Listen for Hey Siri" on each via Home app. | ASAP | `docs/compliance/PHYSICAL_SECURITY.md` §4.2 |
| 15 | **Disable Samsung ACR (Samba) and Sony Bravia telemetry** — menu paths in PHYSICAL_SECURITY.md §4.3. | ASAP | `docs/compliance/PHYSICAL_SECURITY.md` §4.3 |
| 16 | **Complete camera placement table in PHYSICAL_SECURITY.md §4.1** — fill in room/position and confirm no LOS to work monitors for each camera. | When convenient | `docs/compliance/PHYSICAL_SECURITY.md` §4.1 |
| 17 | **Procure Firewalla Gold SE when ready to start the network rewrite** — ~$450; order after confirming Eero bridge-mode support and AT&T gateway passthrough status. | Before network rewrite | `docs/NETWORK_PLAN.md` §4, `docs/OPEN_ISSUES.md` §7 |

---

## Deferred Until After Content/UI Sprint

These items are real but not blocking the infrastructure or compliance buildout:

- **Drupal CSP nonce migration** — `unsafe-inline` / `unsafe-eval` cleanup; needs Next.js inline-script audit first. See OPEN_ISSUES §1.
- **Container image vulnerability scanning (Trivy)** — add to DEPLOYMENT_CHECKLIST pre-deploy; not blocking current ops. See OPEN_ISSUES §1.
- **Dockerfile base image pinning to patch versions** — next quarterly Docker image update. See OPEN_ISSUES §2.
- **Staging sanitation — revalidate/preview secret values** — low-priority config fix. See OPEN_ISSUES §4.
- **Encrypted Proton Drive backup restore test** — low-priority; add optional `--encrypted` path to test script. See OPEN_ISSUES §4.
- **Uptime Kuma credentials in sops** — low-priority; password manager is acceptable. See OPEN_ISSUES §5.
- **config_split cleanup** — remove inert splits after Keycloak setup is stable. See OPEN_ISSUES §5.
- **Webhook HMAC upgrade** — stronger than URL-embedded secret; defer to next `wl_postmark_webhook` release. See OPEN_ISSUES §1.
- **Home network rewrite (Path 2 — Firewalla Gold SE)** — insert Firewalla Gold SE in front of Eero, Eero in bridge mode, VLAN segmentation (work / iot-homekit / iot-untrusted / personal / guest). Full plan in `docs/NETWORK_PLAN.md`. Deferred until Keycloak Phase A + Tailscale Phase B complete. Estimated: 1–2 evenings setup + 1 weekend tuning.

---

## Key References

| Topic | Document |
|-------|---------|
| Active initiative dashboard | `docs/PROJECT_PLAN.md` |
| All known gaps + punch list | `docs/OPEN_ISSUES.md` |
| Keycloak + identity setup | `docs/ADMIN_SETUP.md` §3 |
| Tailscale Premium features | `docs/TAILSCALE_PREMIUM.md` |
| Tailscale ACL design | `docs/TAILSCALE_ACL_DESIGN.md` |
| Corporate past performance | `docs/PAST_PERFORMANCE.md` §1, `docs/COMPANY_PROFILE.md` |
| Principal past performance | `docs/PAST_PERFORMANCE.md` §2 |
| NIST 800-171 control status | `docs/compliance/SSP.md` |
| Open remediation items | `docs/compliance/POAM.md` |
| Incident response plan | `docs/compliance/INCIDENT_RESPONSE.md` |
| Home office physical security | `docs/compliance/PHYSICAL_SECURITY.md` |
| Home network rewrite plan | `docs/NETWORK_PLAN.md` |
