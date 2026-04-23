# Employee / Contractor Offboarding

**Organization:** Wilkes & Liberty  
**Maintained by:** Jeremy (`3@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23

---

## Overview

Access must be revoked within **24 hours** of departure notification (voluntary or involuntary). For involuntary terminations, revoke Tailscale access **immediately** as the first action.

All offboarding actions must be logged. The log is maintained as a commit to this repo or an email to `3@wilkesliberty.com` with the offboarding checklist as an attachment.

---

## Offboarding Checklist

**Employee/Contractor:** ___________________________________  
**Last day:** ___________________________________  
**Departure type:** [ ] Voluntary  [ ] Involuntary  [ ] Contract end  
**Completed by:** ___________________________________  
**Completion date:** ___________________________________

### Immediate actions (within 1 hour for involuntary; within 24 hours for voluntary)

- [ ] **Tailscale** — Remove device(s) from the tailnet
  - Go to `https://login.tailscale.com/admin/machines`
  - Find all devices associated with the departing person
  - Remove each device
  - Verify: `tailscale status` should not show their device

- [ ] **GitHub** — Remove from `Wilkes-Liberty` organization
  - Go to `https://github.com/orgs/Wilkes-Liberty/people`
  - Click on their name → Remove from organization
  - Verify: they can no longer push to any org repos

- [ ] **Keycloak** — Disable account
  - Go to `https://auth.int.wilkesliberty.com/admin/`
  - Find user → Disable (do not delete — keep for audit trail for 90 days)
  - Verify: they cannot log in

### Credential rotation (required if departing person had access to any of the following)

For each credential the person had knowledge of or access to:

| Credential | Who rotates | Procedure |
|-----------|-------------|----------|
| SOPS age key | Jeremy | Generate new key, update `.sops.yaml`, re-encrypt all secrets, redeploy |
| Drupal OAuth client secret | Jeremy | Regenerate in Drupal admin → update sops → `make onprem && make vps` |
| Postmark server token | Jeremy | Revoke in Postmark dashboard → update sops → `make onprem` |
| PostgreSQL passwords | Jeremy | Update in sops → `make onprem` (Ansible resets passwords) |
| Tailscale admin access | Jeremy | Change account password + rotate MFA secret |
| GitHub admin access | Jeremy | Review GitHub audit log for any changes made |

**For Admin/Owner role departures:** All credentials listed above must be rotated. This takes priority over all other offboarding steps.

- [ ] SOPS age key rotated
- [ ] All service credentials rotated
- [ ] New credentials deployed via `make onprem && make vps`
- [ ] Verify: `drush status` and `docker compose ps` confirm deployment succeeded

### SaaS accounts (if the departing person had their own accounts for company resources)

- [ ] Postmark — Remove from team (if applicable)
- [ ] Njalla — Change password / MFA (if they had access)
- [ ] Proton Drive — Revoke access (if they had access)
- [ ] Tailscale — Already covered above

### Hardware (if company-owned)

- [ ] Laptop / workstation returned
- [ ] Confirm macOS user account is removed from returned hardware
- [ ] Confirm no company data remains on personal devices they retain
  - Ask: do you have any company files on personal devices?
  - For sensitive roles: require deletion confirmation in writing

### Data retention

- [ ] Confirm any work product is accessible to the organization (committed to git, not only on their personal device)
- [ ] Archive any relevant email threads if needed
- [ ] Disable/delete their personal email alias if one was created

### Final verification

- [ ] `tailscale status` — their device is no longer visible
- [ ] Test: attempt to clone the infra repo with their GitHub credentials (should fail)
- [ ] Review Tailscale audit log for any connections after removal date
- [ ] Review GitHub audit log for any access after removal date

---

## Post-offboarding (within 30 days)

- [ ] Update [ROLES.md](ROLES.md) to remove the departed person's name
- [ ] Update [ACCESS_CONTROL.md](../compliance/ACCESS_CONTROL.md) access matrix
- [ ] File completed offboarding checklist (this doc, filled out) as a git commit to `docs/team/offboarding-records/YYYY-MM-DD-<name>.md` (private repo; or file internally)

---

## Notes on involuntary terminations

For involuntary terminations, assume the worst case. In addition to the above:
1. Revoke Tailscale **before** notifying the employee (if possible).
2. After termination meeting, confirm they have handed back all hardware before leaving.
3. Review git log for any last-minute commits that might have introduced backdoors or removed monitoring:
   ```bash
   git log --since="7 days ago" --author="[THEIR_NAME]" --all
   ```
4. Review Caddy access logs and Prometheus for any unusual traffic in the 48h before/after termination.
