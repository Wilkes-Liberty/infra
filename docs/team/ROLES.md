# Roles & Responsibilities

**Organization:** Wilkes & Liberty  
**Maintained by:** Jeremy Michael Cerda (`jmcerda@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23

---

## Current Team

| Name | Username | Role | Email |
|------|----------|------|-------|
| Jeremy Michael Cerda | `jmcerda` | Owner / CTO / Security Lead / Privacy Officer / DR Lead | `jmcerda@wilkesliberty.com` |
| Aleksandra Cerda | `acerda` | Break-glass / Business Continuity Contact (spouse) | `acerda@wilkesliberty.com` |

_Note: Aleksandra Cerda's account is a spousal break-glass account for business continuity only — not an employee role. See Succession Planning and PROJECT_PLAN.md Phase D for details._

---

## Role Definitions

### Owner / CTO / Security Lead

Currently: Jeremy Michael Cerda (`jmcerda`)

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

The Security Officer (currently Jeremy Michael Cerda) is responsible for:

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

In the event the Owner (Jeremy Michael Cerda) is unavailable for an extended period:

1. **Immediate:** Aleksandra Cerda (spouse / business continuity contact) can be reached at `acerda@wilkesliberty.com`. Her Keycloak break-glass account can be activated to allow minimum-necessary access if required. See INCIDENT_RESPONSE.md for the activation procedure.
2. **Within 48 hours:** Engage an external consultant or trusted technical contact to assist with any operational tasks requiring infra access.
3. The SOPS age key must be recoverable from the password manager without Jeremy's participation — confirm this is the case and that Aleksandra knows how to retrieve it.
4. All critical credentials are documented in ACCESS_CONTROL.md §5 and accessible via the password manager.

_Aleksandra's break-glass account grants no standing access. It must be explicitly enabled when needed and disabled when the emergency is resolved. See PROJECT_PLAN.md Phase D for provisioning details._

_Update this section as the team grows to include a qualified technical successor._
