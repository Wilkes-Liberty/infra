# Access Control Policy

**Organization:** Wilkes & Liberty  
**Maintained by:** Jeremy Michael Cerda (`jmcerda@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23  
**Framework reference:** NIST SP 800-171 §3.1, §3.5

---

## 1. Purpose

This policy defines who has access to what systems, how access is granted and revoked, and the review cadence for all access rights.

---

## 2. System Inventory & Access Matrix

### 2.1 Systems in scope

| System | Location | Auth mechanism | Admin path |
|--------|----------|---------------|-----------|
| On-prem server (macOS) | Home office / dedicated location | Physical access | n/a |
| Docker stack (Drupal, Postgres, Keycloak, etc.) | On-prem Docker | Container network; Drupal admin via Tailscale | `https://api.int.wilkesliberty.com/admin` |
| Njalla VPS | Cloud (Njalla) | SSH key, Tailscale | `ssh root@<vps>` via Tailscale |
| Tailscale admin console | SaaS (Tailscale) | Tailscale account (password + MFA) | `https://login.tailscale.com/admin` |
| GitHub repos | SaaS (GitHub) | GitHub account (password + MFA) | `github.com/Wilkes-Liberty` |
| Postmark | SaaS (Postmark) | Postmark account (password + MFA) | `account.postmarkapp.com` |
| Njalla registrar | SaaS (Njalla) | Njalla account (password + MFA) | `njal.la` |
| Proton Drive | SaaS (Proton) | Proton account (password + MFA) | `drive.proton.me` |

### 2.2 Role definitions

| Role | Description | Systems accessible |
|------|-------------|-------------------|
| **Owner / Admin** | Full access to all systems; responsible for all security decisions | All systems |
| **Developer** (future) | Can read/write application code; can deploy to staging; cannot deploy to production without approval; no access to production secrets | GitHub, staging Docker stack, staging DB |
| **Contractor** (future) | Same as Developer but scoped to specific repos; access revoked at contract end | Subset of GitHub repos; no infrastructure access |
| **Readonly** (future) | Can view Grafana dashboards and logs; no write access | Grafana, Prometheus (view-only) |

_Current team size: 1. Roles above define the future state. The Owner role maps to Jeremy Michael Cerda (`jmcerda`)._

---

## 3. Access Provisioning

### 3.1 New hire onboarding

Access is provisioned in this order at the start of employment:

1. **Tailscale device enrollment** — send the new hire a Tailscale invite. Define which tag(s) their device gets based on their role (see [TAILSCALE_ACL_DESIGN.md](../TAILSCALE_ACL_DESIGN.md)).
2. **GitHub organization invite** — add to the `Wilkes-Liberty` org with the appropriate team and repository permissions.
3. **Keycloak account creation** — create a user in the `wilkesliberty` realm with the appropriate realm roles. Set a temporary password.
4. **SOPS/age key sharing** — only for Owner/Admin role. Share the age key via a secure, out-of-band channel (e.g., 1Password Secure Share). Never share via email.
5. **Send [ONBOARDING.md](../team/ONBOARDING.md)** — the new hire reads and acknowledges all listed documents.

### 3.2 Access approval

All access provisioning requires written approval (email or Slack message from Jeremy Michael Cerda). Access grants are logged in the git history of the relevant config file (Tailscale ACL, GitHub org settings, etc.).

### 3.3 Minimum access principle

Each role receives the minimum access required for the job function. Access is not granted by default; it must be explicitly provisioned. Requests for elevated access must be documented and justified.

---

## 4. Access Revocation (Offboarding)

See [OFFBOARDING.md](../team/OFFBOARDING.md) for the complete checklist. Summary:

Access is revoked in reverse order of provisioning, within **24 hours** of departure or termination:

1. Remove from Tailscale (devices are immediately disconnected)
2. Remove from GitHub org (access to code repos is cut)
3. Disable Keycloak account
4. Rotate any shared credentials the departing person had knowledge of
5. Remove from Postmark, Njalla, Proton teams (if applicable)

For involuntary terminations, revoke Tailscale access **immediately** (before any other step).

---

## 5. Credential Management

### 5.1 Service account credentials

All service account credentials (PostgreSQL passwords, Redis password, API tokens, OAuth client secrets) are managed via SOPS-encrypted files in `ansible/inventory/group_vars/`. See [SECRETS_MANAGEMENT.md](../SECRETS_MANAGEMENT.md).

### 5.2 Rotation schedule

| Credential | Rotation trigger | Minimum rotation cadence |
|-----------|-----------------|--------------------------|
| Drupal OAuth client secret | Any team departure · suspected compromise | Annually |
| Postmark server token | Any team departure · suspected compromise | Annually |
| PostgreSQL passwords (wl_app, keycloak) | Any team departure · suspected compromise | Annually |
| Redis password | Any team departure · suspected compromise | Annually |
| Keycloak admin password | Any admin departure · suspected compromise | Annually |
| Tailscale auth key | Any team departure · key expiry | Per key expiry setting |
| Backup encryption key | Suspected compromise | Every 2 years |
| SOPS age private key | Suspected compromise · key holder departure | When triggered; always immediately on departure |

**Rotation procedure for any credential:**
1. Generate new credential (in the respective service's admin UI or `openssl rand -base64 32`)
2. `sops ansible/inventory/group_vars/<file>.yml` — update the key
3. `make onprem && make vps` — deploy updated credentials
4. Verify service is still healthy
5. Revoke old credential in the respective service

### 5.3 Password policy (human accounts)

Enforced via Keycloak when configured:
- Minimum length: 12 characters
- Must not be the username or email address
- Must not be the previous 5 passwords
- All admin accounts must use MFA (TOTP)

---

## 6. Periodic Access Review

**Cadence:** Quarterly  
**Process:** The Owner reviews the access matrix (§2.2) and confirms:
- All active accounts belong to current employees or active contractors
- Role assignments are still appropriate
- No former employees retain access
- MFA is enforced on all admin accounts (once Keycloak is configured)

**Documentation:** Record the review date and outcome in a comment on the quarterly security checklist review commit.

---

## 7. Audit Trail

All access changes are logged:
- **Tailscale:** admin console audit log
- **GitHub:** organization audit log (admin → Settings → Audit log)
- **Keycloak:** realm events (when configured)
- **SOPS secrets updates:** git commit history on `ansible/inventory/group_vars/`

Access provisioning and revocation events are traceable to git commits with the date, operator (Jeremy Michael Cerda), and change description.
