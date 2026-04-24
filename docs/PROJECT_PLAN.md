# Project Plan

**Organization:** Wilkes & Liberty  
**Maintained by:** Jeremy Michael Cerda (`jmcerda@wilkesliberty.com`)  
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

**Goal:** Stand up unified SSO via Keycloak so all internal apps and Tailscale use the same identity — then provision the spousal break-glass account while identity infrastructure is stable.

**Why this order:**
1. **Keycloak first** → identity foundation is stable before anything else depends on it
2. **Tailscale OIDC second** → Tailscale uses Keycloak as its IdP; enrolled devices get Keycloak-native identities
3. **ACLs applied after identity migration** → tag-to-user assignments map to stable Keycloak identities, not ephemeral external-IdP identities
4. **Break-glass account provisioned last** → Keycloak is stable before adding a dormant continuity account; avoids leaving an unreviewed credential in place during the migration window

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
5. Create user `jmcerda` (Jeremy Michael Cerda), assign all admin roles, set permanent password
6. Test forgot-password email flow to confirm Postmark integration works end-to-end

**Reference:** `docs/ADMIN_SETUP.md` §3

**Exit criteria:**
- `wilkesliberty` realm exists with brute-force protection enabled
- `jmcerda` user created with all admin roles
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

### Phase D — Spouse break-glass account (business continuity)

| Field | Value |
|-------|-------|
| **Status** | Not started |
| **Estimate** | ~20 minutes |
| **Owner** | Jeremy (Keycloak provisioning) |
| **Blockers** | Requires Phase A complete (Keycloak realm must exist) |

**Context:** Aleksandra Cerda is Jeremy's spouse. She is not an employee. This account provides a minimum-viable break-glass path for business continuity if Jeremy is unexpectedly unreachable — not active access for day-to-day work. No Tailscale access is provisioned (an unused VPN credential is an attack surface).

**Provisioning steps:**
1. In Keycloak: create user `acerda`, email `acerda@wilkesliberty.com`, no realm roles assigned
2. Set a strong password; store in the shared password manager in a vault Aleksandra can access
3. **Disable the account** (`Enabled: OFF`) — it is dormant by default
4. Document the activation procedure below in a note in the password manager

**Account activation procedure (break-glass only):**
1. Jeremy (or Aleksandra if Jeremy is unreachable) logs into Keycloak admin → Users → `acerda` → Enable
2. Grant minimum-necessary roles for the specific emergency (e.g., access to read backup status, contact a vendor)
3. After the emergency is resolved: disable the account again and review what was accessed

**What this account does NOT provide:**
- No Tailscale access — she cannot reach on-prem services or VPS directly
- No GitHub access — she cannot push to infra repos
- No SOPS age key access — she cannot decrypt secrets
- No production deploy capability

**Exit criteria:**
- `acerda` Keycloak account exists, is disabled, password stored in password manager
- Aleksandra has been told the account exists and where to find the credentials
- Activation procedure is documented in the password manager note

---

## Queued initiatives (next up)

These are ready to schedule once Phases A–C are complete. Phase D (break-glass provisioning) is independent and can happen at any point after Phase A.

### Drupal openid_connect SSO wiring
- **Trigger:** Phases A–C complete; Keycloak stable for 1 week
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
3. **🔴 SSP and POA&M review** — SSP.md needs per-control review (legal entity `Wilkes & Liberty, LLC` now filled in); POA&M needs real target dates (`OPEN_ISSUES.md` §6)
4. **🟡 PII retention policy** — watchdog log rotation + documented deletion procedure for webform submissions (`OPEN_ISSUES.md` §1)
5. **🟡 Container image vulnerability scanning** — add `trivy image` to DEPLOYMENT_CHECKLIST.md pre-deploy step (`OPEN_ISSUES.md` §1)

---

## Decision log

| Date | Decision | Why | Alternatives considered |
|------|----------|-----|------------------------|
| 2026-04-23 | Keycloak configured before Tailscale ACL changes | Identity stability: applying ACLs against pre-Keycloak identities would require a redo after migration | Tailscale ACL first with current external IdP, then re-tag after Keycloak cutover — rejected as more error-prone |
| 2026-04-23 | Name correction — owner is Jeremy Michael Cerda | Prior commits in this repo used "Jeremias" due to a context error in the AI assistant's env. The correct legal name is Jeremy Michael Cerda. Username `jmcerda` is preserved as-is (already correct). | n/a |
| 2026-04-23 | Organizational email standardized on `jmcerda@wilkesliberty.com` | Proton alias `jmcerda@wilkesliberty.com` already existed. Replacing `3@wilkesliberty.com` in all professional docs, contact trees, and system configs. `3@` remains active as a personal alias but is not the org-identity address. | Keep `3@` everywhere — rejected for lack of parallelism with `acerda@` and poor appearance on formal docs |
| 2026-04-23 | Username convention: first-initial + last-name (`jsmith`) as default; `jmcerda` preserved as-is; collision → add middle initial | NIST 800-171 IA-2 requires unique user identification; generic accounts break audit accountability | Generic `admin` account for owner — rejected on compliance grounds |
| 2026-04-23 | `acerda@wilkesliberty.com` Proton alias provisioned for spouse break-glass account, not personal Gmail | Keeps the org identity namespace consistent; `acerda@` routes to Aleksandra's personal mailbox as a forwarding alias | Personal Gmail — rejected; org email alias costs nothing and maintains a clean namespace |
| 2026-04-23 | Tailscale Premium activated before first hire | Tag-based ACLs must be in place before a second device joins the tailnet; easier to define access rules with one device than retrofit after multiple are enrolled | Wait until hire — rejected because retrofitting ACLs on an existing multi-device tailnet is higher-risk |
| 2026-04-23 | Spouse break-glass account — no Tailscale access, disabled by default | Aleksandra Cerda (spouse) has a dormant Keycloak account for business continuity only. No Tailscale access: an unused VPN credential is an unnecessary attack surface and does not meet the minimum-necessary standard. Account disabled at rest; activated only during an emergency, then disabled again. | Standing `tag:dev` Tailscale access — rejected as excessive for a non-operational account |
| 2026-04-23 | Spousal relationship disclosure — required on federal proposal forms | Jeremy Michael Cerda and Aleksandra Cerda are married. This requires explicit disclosure on: FAR 9.504 (Organizational Conflicts of Interest — spousal financial interests may constitute OCI); OGE rules for federal contractors (spousal employment and financial interests are reportable); 13 CFR 121 (SBA affiliation rules — spousal business activities count toward affiliation for small-business set-asides, including 8(a), WOSB/EDWOSB, VOSB, HUBZone eligibility determinations); SF-86/SF-85P (security clearance applications — spousal information always required). Disclose the relationship in SAM.gov registration, past performance certifications, and any set-aside eligibility representations. Not a blocker for any current work — informational. | n/a |

---

## Changelog (closed initiatives)

_Items move here when all phases of an initiative are complete._

| Closed | Initiative | Notes |
|--------|-----------|-------|
| — | — | Nothing closed yet |
