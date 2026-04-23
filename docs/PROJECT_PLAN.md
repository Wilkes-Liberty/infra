# Project Plan

**Organization:** Wilkes & Liberty  
**Maintained by:** Jeremy (`3@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23

---

## How to use this doc

This is the **active-work sequencing layer** — the executive view of what we're building, in what order, and why that order.

- **OPEN_ISSUES.md** = the parts bin (every known gap, upstream block, and deferred enhancement)
- **PROJECT_PLAN.md** = the assembly order (which parts to fit together, and when)
- **SECURITY_CHECKLIST.md** = the steady-state audit (ongoing pass/fail for every security control)

Update this doc as initiatives complete: move finished phases to [Changelog](#changelog-closed-initiatives), promote the next queued initiative to Active, and add new decisions to the Decision Log.

---

## Active initiative

### Keycloak + Tailscale Premium SSO foundation
**Kicked off:** 2026-04-23  
**Status:** In progress (Tailscale Premium activated; Keycloak not yet configured)

**Goal:** Stand up unified SSO via Keycloak so all internal apps and Tailscale use the same identity — before adding the second teammate.

**Why this order:**
1. **Keycloak first** → identity foundation is stable before anything else depends on it
2. **Tailscale OIDC second** → Tailscale uses Keycloak as its IdP; enrolled devices get Keycloak-native identities
3. **ACLs applied after identity migration** → tag-to-user assignments map to stable Keycloak identities, not ephemeral external-IdP identities
4. **Second teammate added last** → they get clean Keycloak-native onboarding from day one; no migration debt

---

### Phase A — Keycloak foundation

| Field | Value |
|-------|-------|
| **Status** | Not started |
| **Estimate** | ~1.5 hours |
| **Owner** | User (with code-session support) |
| **Blockers** | None |

**Steps:**
1. Log in to `https://auth.int.wilkesliberty.com/admin` (password from sops `sso_secrets.yml`)
2. Create realm: `wilkesliberty`
3. Configure realm settings: Login (brute-force protection on, remember-me off), Tokens (access token 15 min, refresh 8h), Email (SMTP already configured via Postmark)
4. Create realm roles: `admin`, `dev`, `contractor`, `readonly`, `drupal-admin`, `grafana-admin`
5. Create user `jcerda` (or chosen username convention — see Decision Log), assign all admin roles, set permanent password
6. Test forgot-password email flow to confirm Postmark integration works end-to-end

**Reference:** `docs/ADMIN_SETUP.md` §3

**Exit criteria:**
- `wilkesliberty` realm exists with brute-force protection enabled
- `jcerda` user created with all admin roles
- Password reset email received via Postmark (confirms SMTP is wired correctly)

---

### Phase B — Tailscale ↔ Keycloak custom OIDC integration

| Field | Value |
|-------|-------|
| **Status** | Not started |
| **Estimate** | ~1 hour |
| **Owner** | User + code-session walkthrough |
| **Blockers** | Requires Phase A complete |

**Steps:**
1. In Keycloak: create OIDC client `tailscale`, generate client secret, configure redirect URIs per Tailscale's docs
2. In Tailscale admin console: **User Management → SSO → Custom OIDC** → enter Keycloak issuer URL + client ID + client secret
3. Keep prior IdP active during cutover (graceful migration — existing devices stay enrolled)
4. Re-authenticate each enrolled device via Keycloak: device prompts for login → authenticate with Keycloak credentials
5. Verify devices appear in admin console under the new Keycloak-sourced identity
6. After 24 hours stable, disable the old IdP

**Reference:** `docs/TAILSCALE_PREMIUM.md`

**Exit criteria:**
- All enrolled devices show Keycloak-sourced identity in Tailscale admin console
- Old IdP disabled and removed

---

### Phase C — Tailscale ACL application

| Field | Value |
|-------|-------|
| **Status** | Not started (design doc written; awaiting sign-off) |
| **Estimate** | ~30 minutes |
| **Owner** | User reviews design; code-session applies |
| **Blockers** | Requires Phase B complete; requires user sign-off on `docs/TAILSCALE_ACL_DESIGN.md` |

**Steps:**
1. User reviews `docs/TAILSCALE_ACL_DESIGN.md` — verify port numbers and tag-to-device mapping are correct
2. In Tailscale admin console: tag each enrolled device per the design (on-prem server → `tag:onprem-server`, VPS → `tag:vps`, operator laptop → `tag:admin`)
3. Apply ACL HuJSON — `tag:admin` has full access as a safety net
4. Test critical paths: SSH to on-prem, SSH to VPS, VPS → on-prem Drupal proxy, internal service access from operator device
5. Tighten ACL progressively if any access is broader than intended

**Reference:** `docs/TAILSCALE_ACL_DESIGN.md`

**Exit criteria:**
- ACL active with all built-in `"tests"` assertions passing
- VPS can reach on-prem :8080 and :8081; cannot reach :5432
- Operator device has full access; no untagged devices remain

---

### Phase D — Add second user

| Field | Value |
|-------|-------|
| **Status** | Not started |
| **Estimate** | ~30 minutes |
| **Owner** | User (Proton + Keycloak provisioning); code-session support available |
| **Blockers** | Requires Phases A–C complete; requires user-provided info (real name, role assignment) |

**Steps:**
1. In Proton: create `<initial><lastname>@wilkesliberty.com` alias routing to their real mailbox
2. In Keycloak: create user with the new email, assign appropriate roles (likely `dev` initially)
3. Set temporary password; email onboarding instructions and link to `docs/team/ONBOARDING.md`
4. They authenticate via Keycloak through Tailscale OIDC — device enrollment is automatic
5. Assign their device the `tag:dev` tag in Tailscale admin console
6. Verify they can reach staging services and Grafana but not production Drupal/DB

**Reference:** `docs/team/ONBOARDING.md`, `docs/TAILSCALE_ACL_DESIGN.md`

**Exit criteria:**
- Second user has working Keycloak account with Tailscale-native login
- Device tagged `tag:dev`; staging access confirmed; production access blocked
- Onboarding acknowledgment email received at `3@wilkesliberty.com`

---

## Queued initiatives (next up)

These are ready to schedule once the active initiative's Phase D is stable for ~1 week.

### Drupal openid_connect SSO wiring
- **Trigger:** Phase D complete and stable for 1 week
- **Estimate:** ~1 hour
- **Why:** Allows Drupal admin login via Keycloak SSO; closes OPEN_ISSUES §5 "Drupal `openid_connect` not enabled"
- **Reference:** `docs/ADMIN_SETUP.md` §3F (Drupal subsection), `docs/OPEN_ISSUES.md` §5

### Grafana OAuth activation
- **Trigger:** Drupal SSO complete
- **Estimate:** ~45 minutes (includes Ansible + sops changes for `grafana_oauth_client_secret`)
- **Why:** Closes the last major SSO gap; all admin UIs then use Keycloak identity
- **Reference:** `docs/ADMIN_SETUP.md` §3F (Grafana subsection), `docs/OPEN_ISSUES.md` §5

### POA&M item IA-4: Credential rotation cadence
- **Trigger:** Any major credential approaching 90 days old; or after first hire (whichever comes first)
- **Estimate:** ~30 minutes to define cadence + add to calendar
- **Why:** NIST 800-171 §3.5.x; currently no rotation schedule exists
- **Reference:** `docs/compliance/POAM.md` item IA-4, `docs/OPEN_ISSUES.md` §1

---

## Backlog (from OPEN_ISSUES, not yet scheduled)

Full details in `docs/OPEN_ISSUES.md`. Top unscheduled items by priority:

1. **🔴 No credential rotation schedule** — NIST 800-171 §3.5.x; define cadence + calendar for all 8 credential types (`OPEN_ISSUES.md` §1)
2. **🔴 No incident response plan reviewed** — INCIDENT_RESPONSE.md is drafted; needs contact tree filled in and owner sign-off (`OPEN_ISSUES.md` §1, §6)
3. **🔴 SSP and POA&M review** — SSP.md needs legal entity name + per-control review; POA&M needs real target dates (`OPEN_ISSUES.md` §6)
4. **🟡 PII retention policy** — watchdog log rotation + documented deletion procedure for webform submissions (`OPEN_ISSUES.md` §1)
5. **🟡 Container image vulnerability scanning** — add `trivy image` to DEPLOYMENT_CHECKLIST.md pre-deploy step (`OPEN_ISSUES.md` §1)

---

## Decision log

| Date | Decision | Why | Alternatives considered |
|------|----------|-----|------------------------|
| 2026-04-23 | Keycloak configured before Tailscale ACL changes | Identity stability: applying ACLs against pre-Keycloak identities would require a redo after migration | Tailscale ACL first with current external IdP, then re-tag after Keycloak cutover — rejected as more error-prone |
| 2026-04-23 | Self-identifying Keycloak usernames (`jcerda` pattern), not generic role accounts | NIST 800-171 IA-2 requires unique user identification; generic accounts break audit accountability | Generic `admin` account for owner — rejected on compliance grounds |
| 2026-04-23 | Provision `@wilkesliberty.com` email for second teammate, not personal Gmail | NIST 800-171 AC-2/IA-4 require organizational identifier control; personal email breaks lifecycle management | Gmail to reduce Proton seat cost — rejected as insufficient for federal contracting direction |
| 2026-04-23 | Tailscale Premium activated before first hire | Tag-based ACLs must be in place before a second device joins the tailnet; easier to define access rules with one device than retrofit after multiple are enrolled | Wait until hire — rejected because retrofitting ACLs on an existing multi-device tailnet is higher-risk |

---

## Changelog (closed initiatives)

_Items move here when all phases of an initiative are complete._

| Closed | Initiative | Notes |
|--------|-----------|-------|
| — | — | Nothing closed yet |
