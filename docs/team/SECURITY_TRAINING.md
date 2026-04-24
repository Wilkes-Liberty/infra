# Security Training Plan

**Organization:** Wilkes & Liberty  
**Maintained by:** Jeremias M. Cerda (`3@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23  
**Framework reference:** NIST SP 800-171 §3.2.1, §3.2.2, §3.2.3

---

## Overview

All staff with access to Wilkes & Liberty systems must complete initial security training within **30 days of hire** and annual refresher training thereafter. Contractors with system access must complete role-scoped training before receiving credentials.

The Security Officer (Jeremias M. Cerda) is responsible for maintaining this plan and confirming completion.

---

## Training Requirements by Role

| Role | Initial training | Annual refresher | Due |
|------|-----------------|------------------|-----|
| Owner / System Administrator | All modules below | All modules | Within 30 days of hire; annually thereafter |
| Developer | Modules 1–4 | Modules 1–4 | Within 30 days of hire; annually thereafter |
| Contractor | Modules 1–2 | Module 1 | Before credentials issued; annually at contract renewal |

---

## Training Modules

### Module 1 — Security Awareness (all roles, ~30 min)

**Objective:** Understand the organization's security posture and personal responsibilities.

Topics:
- Why security matters for a federal-adjacent organization
- What "Controlled Unclassified Information" (CUI) means and whether our work involves it
- Social engineering and phishing: what attacks look like
- Password hygiene: use a password manager; no password reuse; minimum 16 characters for privileged accounts
- Multi-factor authentication: required everywhere, no exceptions
- Incident reporting: what to report, how to report (see INCIDENT_RESPONSE.md)
- Clean desk / device lock: lock screens when stepping away

**Completion method:** Read [SECURITY_CHECKLIST.md](../SECURITY_CHECKLIST.md) and [DATA_CLASSIFICATION.md](../compliance/DATA_CLASSIFICATION.md). Answer the quiz below.

**Module 1 Quiz:**
1. What is the 24-hour rule for offboarding? (Answer: Access must be revoked within 24 hours of departure.)
2. You receive an email with a link to reset your Tailscale password. You didn't request a reset. What do you do? (Answer: Do not click. Report to `3@wilkesliberty.com`.)
3. Where should company credentials be stored? (Answer: In the shared password manager — never in code, docs, or personal storage.)
4. What data classification applies to Drupal form submissions? (Answer: Confidential — may contain PII.)

---

### Module 2 — Secrets and Credential Handling (all roles, ~20 min)

**Objective:** Handle credentials correctly and avoid accidental exposure.

Topics:
- SOPS+age encryption: what it is, how to use it (developers/admins only)
- Never commit plaintext secrets to git — pre-commit hook catches most cases, but understand why
- What to do if a secret is accidentally committed: see INCIDENT_RESPONSE.md §3.1
- Password manager usage: 1Password or equivalent; all shared credentials stored there
- API token lifecycle: request, rotate, revoke
- No secrets in Slack, email, or issue trackers

**Completion method:** Read [SECRETS_MANAGEMENT.md](../SECRETS_MANAGEMENT.md) in full. For admin role: complete the SOPS hands-on exercise in ONBOARDING.md Step 3.

---

### Module 3 — Access Control and Least Privilege (developers and above, ~20 min)

**Objective:** Understand the access control model and operate within it.

Topics:
- Tailscale tag-based ACLs: what your tag allows, what it does not allow
- Keycloak roles: user vs drupal-admin vs grafana-admin
- GitHub access: what you can push, what requires review
- Requesting elevated access: ask Jeremias M. Cerda; access is temporary and logged
- Never share credentials or device access, even with colleagues
- Report unauthorized access attempts immediately

**Completion method:** Read [ACCESS_CONTROL.md](../compliance/ACCESS_CONTROL.md) and [TAILSCALE_ACL_DESIGN.md](../TAILSCALE_ACL_DESIGN.md).

---

### Module 4 — Secure Development Practices (developers and above, ~30 min)

**Objective:** Write and review code with security in mind.

Topics:
- OWASP Top 10 applied to our stack (Drupal/PHP/GraphQL, Next.js)
- Input validation and output encoding: Drupal Form API, GraphQL input types
- Dependency management: `composer audit`, `npm audit`, Dependabot alerts — what to do when a CVE is flagged
- Secret scanning: what the pre-commit hooks catch, what they miss
- Code review for security: what to look for (hardcoded credentials, unvalidated input, IDOR, broken access control)
- Staging vs production: do not test with production data; do not copy live DB to personal devices

**Completion method:** Read [DEVELOPER_SECURITY.md](../compliance/DEVELOPER_SECURITY.md) in full.

---

### Module 5 — Incident Response (Owner/Admin role, ~30 min)

**Objective:** Be able to recognize and respond to a security incident.

Topics:
- What constitutes a reportable incident (see INCIDENT_RESPONSE.md §1)
- First response checklist: contain first, investigate second
- Communication: who to notify, when to notify them
- Evidence preservation: do not wipe or restart affected systems before snapshotting logs
- Post-incident reporting obligations
- Tabletop exercise walkthrough: walk through Scenario A (credential compromise) from INCIDENT_RESPONSE.md

**Completion method:** Read [INCIDENT_RESPONSE.md](../compliance/INCIDENT_RESPONSE.md) in full. Participate in the annual tabletop exercise.

---

## Acknowledgment Form

After completing all required modules, send an email to `3@wilkesliberty.com` with the following content:

```
Subject: Security training acknowledgment — [Your Name] — [Date]

I, [Full Name], confirm that I have completed the Wilkes & Liberty security
training required for my role ([Role]) as of [Date].

Modules completed:
- [ ] Module 1 — Security Awareness
- [ ] Module 2 — Secrets and Credential Handling
- [ ] Module 3 — Access Control and Least Privilege (if applicable)
- [ ] Module 4 — Secure Development Practices (if applicable)
- [ ] Module 5 — Incident Response (if applicable)

I understand my responsibilities as described in the training materials and
agree to follow the policies of Wilkes & Liberty.
```

---

## Training Records

The Security Officer maintains training completion records. For each staff member, record:

| Field | Value |
|-------|-------|
| Name | |
| Role | |
| Hire date | |
| Initial training completed | |
| Annual refresher due | |
| Acknowledgment email received | |

Training records are retained for the duration of employment plus 3 years.

---

## Annual Refresher

**Trigger:** 12 months after initial training completion.  
**Scope:** Same modules as initial training for the role.  
**Delivery:** Self-study via updated docs. The Security Officer sends a reminder email with a link to any docs that changed since last training.

If a significant security incident occurred in the prior year, the Security Officer may add a case-study module to the annual refresher.

---

## Training Content Currency

This plan and all linked documents must be reviewed annually (or after any significant incident) to ensure training content reflects current system state. Review is part of the Security Officer's annual duties (see ROLES.md).

**Next review due:** 2027-04-23
