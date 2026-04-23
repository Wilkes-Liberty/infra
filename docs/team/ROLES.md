# Roles & Responsibilities

**Organization:** Wilkes & Liberty  
**Maintained by:** Jeremy (`3@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23

---

## Current Team

| Name | Role | Email |
|------|------|-------|
| Jeremy | Owner / System Administrator / Security Officer | `3@wilkesliberty.com` |
| _[Second hire]_ | _[Role — fill in]_ | _[Email]_ |

---

## Role Definitions

### Owner / System Administrator / Security Officer

Currently: Jeremy

**Responsibilities:**
- Overall accountability for security posture
- Production deployments (`make onprem`, `make vps`)
- Secrets management (SOPS age key custodian)
- Incident response (primary responder)
- Vendor management and contract review
- Access provisioning and revocation
- Security checklist quarterly review
- Backup monitoring and quarterly restore test
- Code review for security-sensitive changes

**System access:** All systems (see ACCESS_CONTROL.md §2.2)

---

### Developer (future role)

**Responsibilities:**
- Feature development in `webcms`, `ui` repos
- Staging deployments
- Code review for non-security-sensitive changes
- Documenting new features in relevant docs

**System access:** GitHub (write access), Tailscale (dev tag), Keycloak (user role), staging Docker stack  
**Not authorized:** Production deployments, secrets access, SOPS age key

---

### Contractor (future role)

**Responsibilities:**
- Scoped development work as defined in contract
- Must acknowledge and sign security policies before repo access

**System access:** Specific GitHub repos only; no infrastructure access  
**Duration:** Access expires at contract end and must be revoked in OFFBOARDING.md

---

## RACI Matrix

| Function | Jeremy (Owner) | Developer | Contractor |
|----------|---------------|-----------|-----------|
| Production deployment | **R/A** | I | — |
| Staging deployment | R/A | **R** | — |
| Security incident response | **R/A** | I | — |
| Backup monitoring | **R/A** | I | — |
| Code review | **A** | R | I |
| Secrets rotation | **R/A** | — | — |
| Access provisioning | **R/A** | — | — |
| Vendor management | **R/A** | I | — |
| Security checklist review | **R/A** | I | — |
| Documentation updates | **R/A** | R | I |

_R = Responsible · A = Accountable · C = Consulted · I = Informed_

---

## Security Officer Duties

The Security Officer (currently Jeremy) is responsible for:

1. **Quarterly:** Review SECURITY_CHECKLIST.md and update status on each item.
2. **Quarterly:** Run `make test-backup-restore`; confirm backups are healthy.
3. **Monthly:** Run `composer audit` on webcms and `npm audit` on ui; patch per UPDATE_CADENCE.md.
4. **Weekly:** Review Prometheus alert history and Drupal watchdog for errors.
5. **On hire:** Provision access per ONBOARDING.md; ensure training is completed within 30 days.
6. **On departure:** Execute OFFBOARDING.md within 24 hours of departure.
7. **On incident:** Lead response per INCIDENT_RESPONSE.md.
8. **Annually:** Review and update all compliance docs; review vendor risk; conduct tabletop exercise.

---

## Succession Planning

In the event the Owner (Jeremy) is unavailable for an extended period:

1. The secondary responder (see INCIDENT_RESPONSE.md contact tree) assumes the Security Officer role.
2. The SOPS age key must be recoverable from the password manager without Jeremy's participation — confirm this is the case.
3. All critical credentials are documented in ACCESS_CONTROL.md §5 and accessible via the password manager.

_Update this section as the team grows._
