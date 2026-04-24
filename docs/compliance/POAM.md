# Plan of Action & Milestones (POA&M)

**Organization:** Wilkes & Liberty  
**Framework:** NIST SP 800-171 Rev 2  
**Maintained by:** Jeremy Michael Cerda (`jmcerda@wilkesliberty.com`)  
**Last updated:** 2026-04-23

This document tracks all partially-implemented and not-implemented NIST 800-171 controls identified in the [System Security Plan (SSP)](SSP.md). Each item has an owner, a remediation approach, and a target date.

**Relationship to OPEN_ISSUES.md:** POA&M items that are also operational risks are cross-listed in [OPEN_ISSUES.md](../OPEN_ISSUES.md). The POA&M is the compliance-focused view; OPEN_ISSUES is the operational view.

---

## Status Key
- 🔴 Not Started
- 🟡 In Progress
- ✅ Completed — move to Completed Items table

---

## Open Items

| ID | Control | Title | Status | Remediation approach | Owner | Target date |
|----|---------|-------|--------|---------------------|-------|------------|
| AC-1 | 3.1.1, 3.1.4, 3.1.7 | Keycloak realm not configured; no centralized IAM | 🟡 In Progress | Configure Keycloak realm per ADMIN_SETUP.md §3: create realm, user, brute-force detection, password policy, session timeouts. Then wire Grafana OAuth and Drupal OIDC. | Jeremy Michael Cerda | 2026-06-01 |
| AC-2 | 3.1.2 | No formal RBAC policy | 🔴 Not Started | Complete ACCESS_CONTROL.md with formal role definitions and access matrix. | Jeremy Michael Cerda | 2026-06-01 |
| AC-3 | 3.1.4 | Duty separation not enforced | 🔴 Not Started | Acceptable for single-operator phase. Define policy in ROLES.md: when team grows to 2+, enforce code-review-before-merge and separate deploy approval. | Jeremy Michael Cerda | When second employee joins |
| AC-4 | 3.1.9 | No system use banner / privacy notice | 🔴 Not Started | Add system use banner to Drupal login page via hook or block. Document acceptable use policy. | Jeremy Michael Cerda | 2026-07-01 |
| AC-5 | 3.1.10, 3.1.11 | No session lock / automatic session termination | 🔴 Not Started | Configure: Drupal `session.gc_maxlifetime`, Keycloak SSO session idle 30 min / max 10 hours. | Jeremy Michael Cerda | 2026-06-01 (with Keycloak setup) |
| AC-6 | 3.1.18 | No MDM for mobile devices | 🔴 Not Started | Tailscale Premium tag-based ACLs can restrict mobile device access. Define `tag:user-device` with limited access in ACL policy. | Jeremy Michael Cerda | After TAILSCALE_ACL_DESIGN.md review |
| AC-7 | 3.1.21, 3.8.7, 3.8.8 | No removable media / portable storage policy | 🔴 Not Started | Define acceptable use policy in DATA_CLASSIFICATION.md §5. | Jeremy Michael Cerda | 2026-07-01 |
| AT-1 | 3.2.1, 3.2.2, 3.2.3 | No formal security awareness training program | 🔴 Not Started | Implement per SECURITY_TRAINING.md: annual training, phishing awareness, incident reporting procedure. | Jeremy Michael Cerda | 2026-07-01 |
| AU-1 | 3.3.2 | Audit events not attributable to individual identities across services | 🟡 In Progress | Keycloak SSO (AC-1) will enable cross-service identity correlation. This item closes when AC-1 closes. | Jeremy Michael Cerda | 2026-06-01 |
| AU-2 | 3.3.3 | No formal log review schedule | 🔴 Not Started | Add weekly log review steps to DEPLOYMENT_CHECKLIST.md: drush watchdog:show, Caddy 4xx/5xx, Prometheus alert check. | Jeremy Michael Cerda | 2026-05-01 |
| AU-3 | 3.3.5 | No log aggregation / SIEM | 🔴 Not Started | Near-term: document manual correlation procedure in INCIDENT_RESPONSE.md. Long-term: evaluate Loki + Grafana or similar for log aggregation. | Jeremy Michael Cerda | Long-term (2027) |
| AU-4 | 3.3.8 | Logs could be modified by root | 🔴 Not Started | Forward Caddy logs to an immutable destination (Proton Drive, S3). Define log retention period (90 days minimum for federal work). | Jeremy Michael Cerda | 2026-07-01 |
| CM-1 | 3.4.2 | No formal component inventory / CMDB | 🔴 Not Started | Existing service table in AGENTS.md is sufficient for current scale. Formalize in CONFIG_MANAGEMENT.md when component count grows. | Jeremy Michael Cerda | 2026-06-01 |
| CM-2 | 3.4.4 | No formal change impact analysis | 🔴 Not Started | Add impact analysis checklist to DEPLOYMENT_CHECKLIST.md pre-deploy section. | Jeremy Michael Cerda | 2026-05-01 |
| CM-3 | 3.4.9 | No acceptable software policy for on-prem workstation | 🔴 Not Started | Define in DATA_CLASSIFICATION.md §5 / ACCESS_CONTROL.md. | Jeremy Michael Cerda | 2026-07-01 |
| CM-4 | 3.7.4 | Rollback procedure not documented | 🔴 Not Started | Write rollback one-pager in DEPLOYMENT_CHECKLIST.md or a dedicated doc. | Jeremy Michael Cerda | 2026-05-01 |
| IA-1 | 3.5.3, 3.7.5 | No MFA on any account | 🟡 In Progress | Keycloak OTP enforcement (ADMIN_SETUP §3I). This is a prerequisite for CUI authorization. Closes when AC-1 closes and Keycloak OTP is enforced. | Jeremy Michael Cerda | 2026-06-01 |
| IA-2 | 3.5.5, 3.5.6 | No identifier lifecycle management / inactivity deactivation | 🔴 Not Started | Define in ACCESS_CONTROL.md: inactivity period (90 days), deactivation procedure, reuse prohibition. | Jeremy Michael Cerda | 2026-06-01 |
| IA-3 | 3.5.7, 3.5.8 | No password complexity / history policy | 🟡 In Progress | Configure Keycloak password policy when realm is created (AC-1). | Jeremy Michael Cerda | 2026-06-01 |
| IR-1 | 3.6.2 | No incident tracking system | 🔴 Not Started | Use GitHub Issues as the incident record until a dedicated tool is needed. Create an `incident` label in the repo. | Jeremy Michael Cerda | 2026-05-01 |
| IR-2 | 3.6.3 | No incident response drill | 🔴 Not Started | Schedule annual tabletop exercise. First: 2027-04-23. | Jeremy Michael Cerda | 2027-04-23 |
| MA-1 | 3.7.3, 3.8.3 | No equipment sanitization / disposal procedure | 🔴 Not Started | Document in BCDR.md: disk wipe procedure (macOS Disk Utility secure erase, or physical destruction). | Jeremy Michael Cerda | 2026-07-01 |
| MP-1 | 3.8.9 | Encrypted Proton Drive backup not tested | 🔴 Not Started | Add optional `--encrypted` test path to test-backup-restore.sh. Test annually. | Jeremy Michael Cerda | 2026-07-01 |
| PE-1 | 3.10.1 | No physical access log | 🔴 Not Started | For home office: maintain a written log of visitors who are in the same space as the server. For CUI: consider a locked server cabinet. | Jeremy Michael Cerda | 2026-07-01 |
| PE-2 | 3.10.4 | No physical access log (automated) | 🔴 Not Started | See PE-1. | Jeremy Michael Cerda | 2026-07-01 |
| PS-1 | 3.9.1 | No background check procedure | 🔴 Not Started | Define in ONBOARDING.md: reference checks required for all hires; federal work requires NACI or equivalent. | Jeremy Michael Cerda | When first hire is planned |
| PS-2 | 3.9.2 | Offboarding procedure not yet executed | 🟡 In Progress | OFFBOARDING.md is drafted. Validate against all access points before first offboarding event. | Jeremy Michael Cerda | Ongoing |
| RA-1 | 3.11.1 | No formal annual risk assessment | 🔴 Not Started | Formalize SECURITY_CHECKLIST.md quarterly review as the risk assessment mechanism. Document findings. | Jeremy Michael Cerda | 2026-07-23 (first formal review) |
| SC-1 | 3.13.10 | No key management lifecycle document | 🔴 Not Started | Document age key generation, storage, backup, rotation, and destruction in SECRETS_MANAGEMENT.md update. | Jeremy Michael Cerda | 2026-06-01 |
| SI-1 | 3.11.2 | No infrastructure vulnerability scan | 🔴 Not Started | Evaluate OpenVAS or Nessus Essentials for quarterly infrastructure scan. Start with manual DISA STIG checklist review. | Jeremy Michael Cerda | 2026-07-01 |
| SI-2 | 3.5.3 (Container scanning) | No container image vulnerability scanning | 🔴 Not Started | Add `trivy image wilkesliberty/webcms:latest` to DEPLOYMENT_CHECKLIST.md. Long-term: CI pipeline. | Jeremy Michael Cerda | 2026-05-01 |
| SI-3 | 3.14.2, 3.14.5 | No malware scanning on file uploads | 🔴 Not Started | Evaluate ClamAV Drupal module for file upload scanning. | Jeremy Michael Cerda | 2026-07-01 |
| SI-4 | 3.14.6, 3.14.7 | No IDS / behavioral monitoring | 🔴 Not Started | Near-term: `fail2ban` + Prometheus anomaly alerts are partial coverage. Long-term: evaluate OSSEC or similar host-based IDS. | Jeremy Michael Cerda | Long-term (2027) |

---

## Completed Items

| ID | Control | Title | Closed | Resolution |
|----|---------|-------|--------|-----------|
| — | 3.1.5 | No least-privilege DB user | 2026-04-23 | `wl_app` role created; Drupal connects as wl_app; keycloak DB access revoked from PUBLIC. |
| — | 3.1.8 | No brute-force protection on SSH | 2026-04-23 | `fail2ban` deployed via `common` Ansible role; 5 failures → 1h ban. |
| — | 3.1.13 | Insufficient transport encryption enforcement | 2026-04-23 | TLS 1.2 minimum enforced in both Caddyfiles; WireGuard for all VPN. |
| — | 3.13.1 | No application-layer rate limiting | 2026-04-23 | Custom Caddy with `mholt/caddy-ratelimit`; 6 rate zones on public endpoints. |
| — | 3.4.1 | No documented baseline configuration | 2026-04-23 | All infra in git; `make onprem` is the idempotent baseline. |
| — | 3.7.1 | No documented update/maintenance cadence | 2026-04-23 | UPDATE_CADENCE.md written; first CVE patch cycle completed (drupal/core 11.3.8). |
| — | 3.6.1 | No incident response procedure | 2026-04-23 | INCIDENT_RESPONSE.md drafted; detection channels active. |
