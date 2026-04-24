# System Security Plan (SSP)

**Organization:** Wilkes & Liberty  
**System name:** WilkesLiberty Content & Delivery Platform  
**System owner:** Jeremy Michael Cerda (`jmcerda` / `jmcerda@wilkesliberty.com`)  
**Framework:** NIST SP 800-171 Rev 2 (110 controls)  
**Last reviewed:** 2026-04-23  
**Document status:** Draft — requires legal review before submission to federal customer

> **Note:** This SSP is prospective. The WilkesLiberty platform does not currently process or store Controlled Unclassified Information (CUI). This document describes the current security posture and identifies gaps (referenced to POA&M items) that would need to be closed before the system is authorized to handle CUI.

---

## System Description

**Purpose:** Headless CMS and public website delivery platform for Wilkes & Liberty.  
**Architecture:** Two-host stack — on-prem macOS server (Docker Compose: Drupal, Keycloak, PostgreSQL, Redis, Solr, monitoring) connected via Tailscale WireGuard mesh to a Njalla cloud VPS (Caddy, Next.js). See [ENVIRONMENT_OVERVIEW.md](../ENVIRONMENT_OVERVIEW.md) and `CLAUDE.md`/`AGENTS.md` for full architecture details.  
**CUI categories handled:** None at present. Wilkes & Liberty, LLC must update this SSP before accepting work involving CUI under DFARS 252.204-7012 or equivalent clauses.  
**System boundary:** All components in `infra/` repo scope, including the webcms and ui repos that run on this infrastructure.  
**Authorization status:** Not yet authorized for CUI. Operating under commercial posture.

---

## Status Key

- ✅ **Implemented** — Control is fully satisfied by current implementation
- ⚠️ **Partially Implemented** — Control is partially satisfied; see POA&M reference
- ❌ **Not Implemented** — Control is not yet in place; see POA&M reference
- N/A **Not Applicable** — Control does not apply to this system (with justification)

---

## 3.1 — Access Control

### 3.1.1 — Limit system access to authorized users and processes
**Status:** ⚠️ Partially Implemented — POA&M #AC-1  
**Implementation:** All on-prem services are accessible only via Tailscale WireGuard VPN. VPS public ports are limited to 80/443. SSH is public-key only (`PasswordAuthentication no`). Drupal admin UI is Tailscale-only. Application access requires OAuth2 tokens issued by `simple_oauth`.  
**Gap:** No formal user access list or periodic access review procedure is documented. Keycloak identity provider (which would centralize user authentication) is deployed but not yet configured. See [ACCESS_CONTROL.md](ACCESS_CONTROL.md).

### 3.1.2 — Limit system access to types of transactions and functions authorized users are permitted to execute
**Status:** ⚠️ Partially Implemented — POA&M #AC-2  
**Implementation:** Drupal connects to PostgreSQL as `wl_app` (non-superuser, `drupal` database only). Keycloak database has `CONNECT` revoked from `PUBLIC`. Caddy restricts admin-adjacent endpoints (`search.int`, `metrics.int`, `alerts.int`) to admin IP CIDRs. Rate limiting restricts request volumes per endpoint type.  
**Gap:** Application-level role enforcement (Drupal roles, Keycloak realm roles) is not fully configured. No formal RBAC policy document exists.

### 3.1.3 — Control the flow of CUI in accordance with approved authorizations
**Status:** N/A — No CUI is currently processed  
**Implementation:** When CUI is designated, all CUI must flow only within the Tailscale mesh (encrypted WireGuard transport). Public-facing Next.js is not authorized to store CUI. This SSP must be updated.

### 3.1.4 — Separate the duties of individuals to reduce the risk of malevolent activity
**Status:** ⚠️ Partially Implemented — POA&M #AC-3  
**Implementation:** A single operator currently owns both development and production access. There is no technical enforcement of duty separation with a one-person team.  
**Gap:** As the team grows, establish separate roles for code merge approval vs. production deployment. See [ROLES.md](../team/ROLES.md).

### 3.1.5 — Employ the principle of least privilege, including for specific security functions and privileged accounts
**Status:** ✅ Implemented  
**Implementation:** `wl_app` PostgreSQL role has no superuser attributes and only `drupal` DB access. SSH on VPS allows only root via key auth (no password). Caddy serves admin endpoints only on Tailscale IP. Docker containers run as non-root users. Tailscale restricts VPN mesh membership to enrolled devices.  
**Evidence:** `ansible/roles/wl-onprem/tasks/main.yml` lines ~570–632 (wl_app setup); `ansible/roles/vps-proxy/templates/Caddyfile.production.j2` (remote_ip restrictions).

### 3.1.6 — Use non-privileged accounts or roles when accessing non-security functions
**Status:** ✅ Implemented  
**Implementation:** Drupal application connects as `wl_app` (non-privileged). Day-to-day operator work uses standard macOS user account; `sudo` or `become` is only invoked by Ansible for specific privileged tasks.

### 3.1.7 — Prevent non-privileged users from executing privileged functions and capture the execution of such functions in audit logs
**Status:** ⚠️ Partially Implemented — POA&M #AC-3  
**Implementation:** PostgreSQL privilege separation is enforced. UFW on VPS blocks unauthenticated access.  
**Gap:** Audit log for privileged Ansible operations is in git commit history, not a dedicated audit log. No centralized SIEM captures sudo/privileged command events.

### 3.1.8 — Limit unsuccessful logon attempts
**Status:** ✅ Implemented  
**Implementation:** VPS SSH: `fail2ban` bans source IPs after 5 failed attempts in 600 seconds, ban duration 1 hour. Caddy rate limiting: login endpoints restricted to 10 req/min per IP (equivalent to brute-force throttling for HTTP-based auth).  
**Evidence:** `ansible/roles/common/tasks/main.yml` (fail2ban); `ansible/roles/vps-proxy/templates/Caddyfile.production.j2` (rate limiting).

### 3.1.9 — Provide privacy and security notices consistent with CUI rules
**Status:** ❌ Not Implemented — POA&M #AC-5  
**Implementation:** No privacy notice or system use banner is configured.  
**Action:** Add a system use banner to the Drupal login page and document acceptable use policy when CUI designation applies.

### 3.1.10 — Use session lock with pattern-hiding displays after inactivity
**Status:** ❌ Not Implemented — POA&M #AC-6  
**Implementation:** Drupal's default session timeout applies but is not explicitly configured. Grafana, Keycloak session timeouts are not yet set.  
**Action:** Configure Drupal `session.gc_maxlifetime`, Keycloak SSO session idle/max timeout (30 min / 10 hours as documented in ADMIN_SETUP §3C).

### 3.1.11 — Terminate (automatically) a user session after a defined condition
**Status:** ⚠️ Partially Implemented — POA&M #AC-6  
**Implementation:** Tailscale sessions expire per the key expiry setting. Drupal PHP sessions are subject to garbage collection. Keycloak token lifetimes are configurable.  
**Gap:** No explicit session termination policy is documented or uniformly enforced across all services.

### 3.1.12 — Monitor and control remote access sessions
**Status:** ✅ Implemented  
**Implementation:** All remote access occurs via Tailscale WireGuard VPN. Tailscale provides device enrollment visibility, connection state, and (on Premium tier) network flow logs. SSH sessions to VPS are logged by the OS.  
**Evidence:** Tailscale admin console; `ssh root@<vps>` with `last -20` shows session history.

### 3.1.13 — Employ cryptographic mechanisms to protect the confidentiality of remote access sessions
**Status:** ✅ Implemented  
**Implementation:** Tailscale uses WireGuard (ChaCha20-Poly1305 + Curve25519 key exchange) for all mesh traffic. SSH uses Ed25519 host keys and requires public-key authentication. HTTPS enforces TLS 1.2 minimum.

### 3.1.14 — Route remote access via managed access control points
**Status:** ✅ Implemented  
**Implementation:** All internal service access routes through Tailscale. The only public entry point to on-prem services is the Caddy reverse proxy on the VPS, which proxies via Tailscale to on-prem.

### 3.1.15 — Authorize remote execution of privileged commands via remote access only for documented operational needs
**Status:** ✅ Implemented  
**Implementation:** Privileged remote execution (Ansible `become`) requires knowledge of the `ansible_become_pass` SOPS-encrypted value and access to the age private key. This is documented in `Makefile` and `SECRETS_MANAGEMENT.md`.

### 3.1.16 — Authorize wireless access prior to allowing connections
**Status:** ✅ Implemented  
**Implementation:** Tailscale device enrollment requires explicit admin approval or a valid auth key. Devices not in the Tailscale tailnet cannot reach any on-prem services.

### 3.1.17 — Protect wireless access using authentication and encryption
**Status:** ✅ Implemented  
**Implementation:** See 3.1.16. WireGuard provides authenticated encrypted tunnels for all wireless/internet-traversing connections.

### 3.1.18 — Control connection of mobile devices
**Status:** ⚠️ Partially Implemented — POA&M #AC-7  
**Implementation:** Mobile devices can be enrolled in Tailscale and will have the same access as other enrolled devices.  
**Gap:** No MDM (Mobile Device Management) policy exists. No separation between personal-use mobile and work-use mobile Tailscale access. Tailscale Premium tag-based ACLs will enable per-device-type access control — see [TAILSCALE_ACL_DESIGN.md](../TAILSCALE_ACL_DESIGN.md).

### 3.1.19 — Encrypt CUI on mobile devices and mobile computing platforms
**Status:** N/A — No CUI is currently processed  
**Implementation:** When CUI is designated, only organization-owned and MDM-enrolled devices will be permitted to cache CUI.

### 3.1.20 — Verify and control all connections to external systems
**Status:** ✅ Implemented  
**Implementation:** External connections are: Tailscale coordination server (for key exchange only — no data passes through), Let's Encrypt ACME (certificate renewal), Postmark API (email delivery), Proton Drive (backup sync). All use TLS. No outbound connections from within Docker containers to untrusted endpoints.

### 3.1.21 — Limit use of portable storage devices on external systems
**Status:** ⚠️ Partially Implemented — POA&M #AC-8  
**Implementation:** No USB storage policy exists.  
**Gap:** Define acceptable use policy for portable storage. For CUI, prohibit USB storage on systems that process it.

### 3.1.22 — Control CUI posted or processed on publicly accessible systems
**Status:** N/A — No CUI is currently processed  
**Implementation:** When CUI is designated, this SSP must be updated to confirm that the public-facing Next.js application does not cache or serve any CUI.

---

## 3.2 — Awareness and Training

### 3.2.1 — Ensure personnel are aware of security risks
**Status:** ⚠️ Partially Implemented — POA&M #AT-1  
**Implementation:** Security practices are documented in this repo. No formal training program or acknowledgment process exists yet.  
**Gap:** See [SECURITY_TRAINING.md](../team/SECURITY_TRAINING.md) for the planned training program.

### 3.2.2 — Ensure personnel are trained to carry out assigned security responsibilities
**Status:** ⚠️ Partially Implemented — POA&M #AT-1  
**Implementation:** The primary operator is familiar with all security controls through direct implementation. No formal training records exist.

### 3.2.3 — Provide security awareness training on recognizing and reporting threats
**Status:** ❌ Not Implemented — POA&M #AT-2  
**Implementation:** No phishing or social engineering awareness training program.  
**Action:** See [SECURITY_TRAINING.md](../team/SECURITY_TRAINING.md).

---

## 3.3 — Audit and Accountability

### 3.3.1 — Create and retain system audit logs to enable monitoring, analysis, investigation, and reporting
**Status:** ✅ Implemented  
**Implementation:** Caddy writes JSON access logs for each vhost (`/var/log/caddy/*.log`). Drupal watchdog captures application events. PostgreSQL has standard logging enabled. Docker container logs are accessible via `docker compose logs`. Prometheus retains metrics for 15 days (default).  
**Evidence:** `ansible/roles/vps-proxy/templates/Caddyfile.production.j2` (log block); `docker exec wl_drupal drush watchdog:show`.

### 3.3.2 — Ensure individual user actions can be traced to those users
**Status:** ⚠️ Partially Implemented — POA&M #AU-1  
**Implementation:** Drupal watchdog associates events with user accounts (uid). Caddy logs include IP addresses. Git commits are attributed to `jmcerda`.  
**Gap:** No centralized user identity provider (Keycloak) is active yet, so application actions across multiple services cannot be correlated to a single identity.

### 3.3.3 — Review and update logged events
**Status:** ❌ Not Implemented — POA&M #AU-2  
**Implementation:** No formal log review schedule is documented.  
**Action:** Add weekly log review steps to DEPLOYMENT_CHECKLIST.md. See [OPEN_ISSUES.md §2](../OPEN_ISSUES.md).

### 3.3.4 — Alert in the event of audit logging process failure
**Status:** ⚠️ Partially Implemented  
**Implementation:** Prometheus alerts on service health. If Caddy stops running, an alert fires. No specific alert for log write failure.  
**Gap:** No alert for log partition full or log agent crash.

### 3.3.5 — Correlate audit record review, analysis, and reporting processes
**Status:** ❌ Not Implemented — POA&M #AU-3  
**Implementation:** Logs are in separate locations (Caddy on VPS, watchdog in Drupal DB, Prometheus metrics). No SIEM or log aggregator correlates them.  
**Action:** Long-term: ship logs to a central aggregator. Near-term: document manual correlation steps in the incident response playbook.

### 3.3.6 — Provide audit record reduction and report generation to support analysis
**Status:** ⚠️ Partially Implemented  
**Implementation:** Grafana dashboards provide metrics aggregation and visualization. Drupal's `/admin/reports/dblog` provides filterable watchdog UI.

### 3.3.7 — Provide a system capability that compares and synchronizes internal clocks
**Status:** ✅ Implemented  
**Implementation:** macOS NTP is active by default. VPS uses systemd-timesyncd (Ubuntu default). Docker container clocks inherit from the host.

### 3.3.8 — Protect audit information and tools from unauthorized access, modification, and deletion
**Status:** ⚠️ Partially Implemented — POA&M #AU-4  
**Implementation:** Caddy logs on VPS are root-owned. Drupal watchdog is in the database (protected by wl_app role restrictions). Git history is immutable (GitHub).  
**Gap:** No log forwarding to a write-once destination. Logs on the VPS could be modified by the root account (which is the only SSH account).

### 3.3.9 — Limit management of audit logging to a subset of privileged users
**Status:** ⚠️ Partially Implemented  
**Implementation:** Only the root user on the VPS and the Ansible operator can modify log configuration.

---

## 3.4 — Configuration Management

### 3.4.1 — Establish and maintain baseline configurations for information technology products
**Status:** ✅ Implemented  
**Implementation:** All infrastructure configuration is in the `infra` git repo. Ansible playbooks are the authoritative definition of system state. `make onprem` produces a known, repeatable state. See [CONFIG_MANAGEMENT.md](CONFIG_MANAGEMENT.md).  
**Evidence:** `ansible/` directory; `Makefile`.

### 3.4.2 — Establish and maintain a system component inventory
**Status:** ⚠️ Partially Implemented — POA&M #CM-1  
**Implementation:** Component inventory exists in `AGENTS.md` (service table), `ENVIRONMENT_OVERVIEW.md`, and `docker-compose.yml`. No formal CMDB.  
**Gap:** No automated inventory discovery or drift detection.

### 3.4.3 — Track, review, approve, and log changes to systems
**Status:** ✅ Implemented  
**Implementation:** All infrastructure changes are committed to git with descriptive commit messages. `make onprem` is the only sanctioned method for applying changes — no ad-hoc manual changes on live systems.  
**Evidence:** `git log --oneline -20`.

### 3.4.4 — Analyze security impact of changes prior to implementation
**Status:** ⚠️ Partially Implemented — POA&M #CM-2  
**Implementation:** Staging environment exists for testing changes before production deployment. Security impact analysis is informal (operator judgment).  
**Gap:** No formal change impact analysis checklist. Add to DEPLOYMENT_CHECKLIST.md.

### 3.4.5 — Define, document, approve, and enforce physical and logical access restrictions associated with changes
**Status:** ⚠️ Partially Implemented  
**Implementation:** Logical: SOPS encryption requires the age key to decrypt and deploy. Physical: on-prem server is in a secured location.  
**Gap:** No formal change approval workflow (single operator today; process needed as team grows).

### 3.4.6 — Employ the principle of least functionality
**Status:** ✅ Implemented  
**Implementation:** Docker containers run only the services they need. UFW on VPS allows only required ports. Docker services bind to `localhost` or the Tailscale IP, not `0.0.0.0`. Unnecessary services are not installed on the VPS.

### 3.4.7 — Restrict, disable, or prevent the use of nonessential programs, functions, ports, protocols, and services
**Status:** ✅ Implemented  
**Implementation:** UFW default-deny policy. No unnecessary packages on VPS (`apt` installs are only `fail2ban`, `unattended-upgrades`, `tailscale`, `caddy`, `certbot`). Prometheus `--web.enable-lifecycle` disabled (prevents unauthenticated config reload).

### 3.4.8 — Apply deny-by-default / allow-by-exception policy
**Status:** ✅ Implemented  
**Implementation:** UFW: `ufw default deny incoming`. Caddy: all requests not matching a defined route receive a 404. PostgreSQL: databases not explicitly granted to `wl_app` are inaccessible.

### 3.4.9 — Control and monitor user-installed software
**Status:** ⚠️ Partially Implemented — POA&M #CM-3  
**Implementation:** Ansible controls all installed software on the VPS. On-prem macOS packages are managed via Homebrew; no policy prevents installation of unauthorized software.  
**Gap:** Define acceptable software installation policy for on-prem workstation.

---

## 3.5 — Identification and Authentication

### 3.5.1 — Identify information system users, processes acting on behalf of users, and devices
**Status:** ✅ Implemented  
**Implementation:** Users: Drupal user accounts, Tailscale device enrollment. Processes: `wl_app` PostgreSQL role identifies the Drupal application process. Devices: Tailscale device registration.

### 3.5.2 — Authenticate users, processes, or devices before allowing access
**Status:** ✅ Implemented  
**Implementation:** SSH: public-key only. Drupal: password or OAuth2. API calls: OAuth2 bearer token. PostgreSQL: password authentication for all roles. Redis: password authentication. Tailscale: device certificate + user authentication.

### 3.5.3 — Use multifactor authentication for local and network access to privileged accounts
**Status:** ❌ Not Implemented — POA&M #IA-1  
**Implementation:** No MFA is currently enforced on any account.  
**Action:** Keycloak SSO with OTP is planned and documented in ADMIN_SETUP §3I. This is a critical gap for CUI authorization.

### 3.5.4 — Employ replay-resistant authentication mechanisms
**Status:** ✅ Implemented  
**Implementation:** SSH public-key authentication is replay-resistant (challenge-response). OAuth2 access tokens have short expiry. TLS prevents replay at the transport layer.

### 3.5.5 — Employ identifier management
**Status:** ⚠️ Partially Implemented — POA&M #IA-2  
**Implementation:** Drupal user IDs are unique. Tailscale device IDs are unique.  
**Gap:** No formal identifier lifecycle management (assignment, reuse prevention, deactivation). See [ACCESS_CONTROL.md](ACCESS_CONTROL.md).

### 3.5.6 — Disable identifiers after defined inactivity period
**Status:** ❌ Not Implemented — POA&M #IA-2  
**Implementation:** No automated account deactivation after inactivity.  
**Action:** Add inactivity-based deactivation policy to ACCESS_CONTROL.md.

### 3.5.7 — Enforce minimum password complexity
**Status:** ⚠️ Partially Implemented — POA&M #IA-3  
**Implementation:** Passwords for service accounts (PostgreSQL, Redis, Keycloak) are high-entropy random strings generated at setup. No password complexity policy is enforced in Drupal or Keycloak (Keycloak not yet configured).  
**Action:** Configure Keycloak password policy (min 12 chars, not username, not email) per ADMIN_SETUP §3C.

### 3.5.8 — Prohibit password reuse for specified generations
**Status:** ❌ Not Implemented — POA&M #IA-3  
**Action:** Configure Keycloak password history policy when realm is created.

### 3.5.9 — Allow temporary password use with immediate change requirement
**Status:** ⚠️ Partially Implemented  
**Implementation:** Keycloak supports temporary passwords (ADMIN_SETUP §3G). Not yet configured.

### 3.5.10 — Store and transmit only cryptographically-protected passwords
**Status:** ✅ Implemented  
**Implementation:** Drupal stores passwords as bcrypt (cost factor 10). Keycloak uses PBKDF2/bcrypt. Passwords are never transmitted in plaintext (all connections over TLS or WireGuard).

### 3.5.11 — Obscure feedback of authentication information during authentication
**Status:** ✅ Implemented  
**Implementation:** Drupal login form obscures password input (standard browser behavior). Terminal SSH key auth does not display key material.

---

## 3.6 — Incident Response

### 3.6.1 — Establish an operational incident-handling capability
**Status:** ✅ Implemented  
**Implementation:** See [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md). Detection channels are active (Prometheus, Alertmanager, watchdog, backup failure alerts). Response playbooks cover credential compromise, container intrusion, service outage, and data breach.

### 3.6.2 — Track, document, and report incidents
**Status:** ⚠️ Partially Implemented — POA&M #IR-1  
**Implementation:** Incident report template exists in INCIDENT_RESPONSE.md §4.2. No dedicated incident tracking system (JIRA, etc.) is configured.  
**Gap:** Define where incident records are stored and retained. GitHub Issues can serve this purpose until a dedicated tool is needed.

### 3.6.3 — Test the organizational incident response capability
**Status:** ❌ Not Implemented — POA&M #IR-2  
**Implementation:** No tabletop or live drill has been conducted.  
**Action:** Annual tabletop exercise scheduled for 2027-04-23. See INCIDENT_RESPONSE.md §5.

---

## 3.7 — Maintenance

### 3.7.1 — Perform maintenance on organizational systems
**Status:** ✅ Implemented  
**Implementation:** `make onprem` is the maintenance vehicle. Update cadence is documented in UPDATE_CADENCE.md. `unattended-upgrades` handles OS security patches on the VPS.

### 3.7.2 — Provide controls on tools, techniques, mechanisms, and personnel for system maintenance
**Status:** ✅ Implemented  
**Implementation:** All maintenance is performed over Tailscale (authenticated, encrypted). SSH public-key only on VPS. Ansible `become` requires SOPS-protected password.

### 3.7.3 — Ensure equipment removed for maintenance is sanitized
**Status:** ⚠️ Partially Implemented — POA&M #MA-1  
**Implementation:** If the on-prem macOS server is removed for maintenance, the Docker volumes contain Drupal and PostgreSQL data. No formal sanitization procedure is documented.  
**Action:** Document disk wipe procedure for hardware maintenance/disposal in BCDR.md.

### 3.7.4 — Check media containing diagnostic and test programs for malicious code
**Status:** ⚠️ Partially Implemented  
**Implementation:** No media is routinely used for maintenance. Software is fetched from authenticated sources (HTTPS, verified checksums where available).

### 3.7.5 — Require MFA for remote maintenance sessions
**Status:** ❌ Not Implemented — POA&M #IA-1  
**Implementation:** See 3.5.3. MFA is not yet implemented.

### 3.7.6 — Supervise maintenance activities of personnel without required access authorization
**Status:** N/A — Single operator; no third-party maintenance personnel.

---

## 3.8 — Media Protection

### 3.8.1 — Protect system media containing CUI (paper and digital)
**Status:** N/A — No CUI is currently processed.

### 3.8.2 — Limit access to CUI on system media to authorized users
**Status:** N/A — No CUI is currently processed.

### 3.8.3 — Sanitize or destroy system media before disposal
**Status:** ⚠️ Partially Implemented — POA&M #MA-1  
**Implementation:** No formal media sanitization procedure.  
**Action:** Document in BCDR.md when hardware is decommissioned.

### 3.8.4 — Mark media with necessary CUI markings
**Status:** N/A — No CUI is currently processed.

### 3.8.5 — Control access to media containing CUI
**Status:** N/A — No CUI is currently processed.

### 3.8.6 — Implement cryptographic mechanisms to protect CUI during transport
**Status:** N/A — No CUI is currently processed. When applicable: all data transport occurs over TLS 1.2+. Backups are AES-256 encrypted before transfer to Proton Drive.

### 3.8.7 — Control the use of removable media on system components
**Status:** ❌ Not Implemented — POA&M #AC-8  
**Implementation:** No removable media policy.

### 3.8.8 — Prohibit the use of portable storage devices when such devices have no identifiable owner
**Status:** ❌ Not Implemented — POA&M #AC-8

### 3.8.9 — Protect the confidentiality of backup CUI at storage locations
**Status:** ✅ Implemented (for non-CUI backups)  
**Implementation:** Daily backups are AES-256 encrypted before Proton Drive sync. The encryption key is SOPS-protected. The Proton Drive account requires MFA.

---

## 3.9 — Personnel Security

### 3.9.1 — Screen individuals prior to authorizing access to organizational systems
**Status:** ❌ Not Implemented — POA&M #PS-1  
**Implementation:** No formal background check process for employees or contractors. Required for federal contracts involving CUI.  
**Action:** Define screening requirements in ONBOARDING.md. Federal work may require security clearance sponsorship or NACI/NACLC checks.

### 3.9.2 — Ensure CUI is protected during and after personnel actions such as terminations and transfers
**Status:** ⚠️ Partially Implemented — POA&M #PS-2  
**Implementation:** Offboarding runbook ([OFFBOARDING.md](../team/OFFBOARDING.md)) covers credential revocation and access termination. No formal offboarding checklist has been executed yet.

---

## 3.10 — Physical Protection

### 3.10.1 — Limit physical access to systems containing CUI to authorized individuals
**Status:** ⚠️ Partially Implemented — POA&M #PE-1  
**Implementation:** On-prem server is in a secured home office / dedicated location. Access is limited to the operator.  
**Gap:** No documented physical access log or formal visitor control procedure.

### 3.10.2 — Protect and monitor the physical facility and support infrastructure
**Status:** ⚠️ Partially Implemented  
**Implementation:** Standard residential/office building security. No dedicated CCTV or environmental monitoring beyond the on-prem server itself.

### 3.10.3 — Escort visitors and monitor visitor activity in facilities containing CUI
**Status:** N/A — No CUI is currently processed. Visitor escort policy needed before CUI handling.

### 3.10.4 — Maintain audit logs of physical access
**Status:** ❌ Not Implemented — POA&M #PE-2  
**Implementation:** No physical access log.

### 3.10.5 — Control and manage physical access devices
**Status:** ⚠️ Partially Implemented  
**Implementation:** Building key/door access is managed by the building. No dedicated server room access log.

### 3.10.6 — Enforce safeguarding measures for CUI at alternate work sites
**Status:** N/A — No CUI is currently processed. Policy needed before CUI handling at remote work sites.

---

## 3.11 — Risk Assessment

### 3.11.1 — Periodically assess the risk to organizational operations, assets, and individuals
**Status:** ⚠️ Partially Implemented — POA&M #RA-1  
**Implementation:** SECURITY_CHECKLIST.md serves as an informal risk assessment. No formal annual risk assessment process.  
**Action:** Formalize quarterly security checklist review as the risk assessment mechanism.

### 3.11.2 — Scan for vulnerabilities in systems periodically and when new vulnerabilities affecting those systems are identified
**Status:** ⚠️ Partially Implemented — POA&M #SI-2  
**Implementation:** `composer audit` and `npm audit` provide application-level vulnerability scanning. GitHub Dependabot provides automated dependency CVE notifications.  
**Gap:** No infrastructure-level vulnerability scan (Nessus, OpenVAS, or equivalent).

### 3.11.3 — Remediate vulnerabilities in accordance with risk assessments
**Status:** ✅ Implemented  
**Implementation:** UPDATE_CADENCE.md defines remediation windows: critical/high within 24h, medium within 7 days. First demonstrated 2026-04-23: three drupal/core CVEs patched within the cadence.

---

## 3.12 — Security Assessment

### 3.12.1 — Periodically assess security controls to determine if effective
**Status:** ⚠️ Partially Implemented — POA&M #CA-1  
**Implementation:** SECURITY_CHECKLIST.md is reviewed quarterly (or after significant changes). This SSP represents the first comprehensive control assessment.  
**Gap:** No third-party penetration test or independent assessment.

### 3.12.2 — Develop and implement plans of action to correct deficiencies
**Status:** ✅ Implemented  
**Implementation:** See [POAM.md](POAM.md). All control gaps identified in this SSP are tracked with owners and remediation dates.

### 3.12.3 — Monitor security controls on an ongoing basis
**Status:** ⚠️ Partially Implemented  
**Implementation:** Prometheus monitors service health. Dependabot monitors dependencies. Manual quarterly checklist review.  
**Gap:** No continuous compliance monitoring tool.

### 3.12.4 — Develop, document, and periodically update system security plans
**Status:** ✅ Implemented  
**Implementation:** This SSP. Updated at least annually or after significant architecture changes.

---

## 3.13 — System and Communications Protection

### 3.13.1 — Monitor, control, and protect communications at external boundaries
**Status:** ✅ Implemented  
**Implementation:** VPS: UFW default-deny + Caddy reverse proxy + TLS termination. On-prem: zero public ports; Tailscale is the only ingress path. All external API connections use TLS.

### 3.13.2 — Employ architectural designs, software development techniques, and systems engineering principles that promote security
**Status:** ✅ Implemented  
**Implementation:** Headless CMS pattern separates public content delivery (Next.js, read-only) from the CMS backend (Drupal, write access). Database is not internet-reachable. Secrets management via SOPS enforces separation of code and credential.

### 3.13.3 — Separate user functionality from system management functionality
**Status:** ✅ Implemented  
**Implementation:** Drupal admin UI is Tailscale-only (`api.int.wilkesliberty.com`). Public API is a separate domain (`api.wilkesliberty.com`). Admin-only endpoints use Caddy `remote_ip` restrictions.

### 3.13.4 — Prevent unauthorized and unintended information transfer
**Status:** ✅ Implemented  
**Implementation:** Docker containers are on isolated networks with explicit inter-service allow-listing. Drupal's `wl_app` DB role cannot reach the Keycloak database.

### 3.13.5 — Implement subnetworks for publicly accessible system components
**Status:** ✅ Implemented  
**Implementation:** Docker networks: `wl_frontend`, `wl_backend`, `wl_monitoring` are separate subnets. Next.js on VPS is isolated from on-prem services except via the explicitly proxied Caddy routes.

### 3.13.6 — Deny network communications traffic by default and allow communications by exception
**Status:** ✅ Implemented  
**Implementation:** UFW default-deny on VPS. Docker networks: services only reach networks they're explicitly joined to. Caddy route-based allow-listing.

### 3.13.7 — Prevent remote devices from simultaneously tunneling to the system and to other resources on the Internet
**Status:** ⚠️ Partially Implemented  
**Implementation:** Tailscale split tunneling is the default — devices can simultaneously reach the Tailscale network and the public internet. Full-tunnel mode would be more restrictive but is not required.  
**Gap:** For CUI handling, consider Tailscale exit node or full-tunnel mode for admin sessions.

### 3.13.8 — Implement cryptographic mechanisms to prevent unauthorized disclosure of CUI during transmission
**Status:** ✅ Implemented  
**Implementation:** TLS 1.2+ for all HTTP traffic. WireGuard for all VPN traffic. No plaintext transmission of any credentials or sensitive data.

### 3.13.9 — Terminate network connections after defined period of inactivity
**Status:** ⚠️ Partially Implemented  
**Implementation:** Caddy: idle connection timeout is Caddy's default (5 minutes). Tailscale: connections expire per key expiry. PostgreSQL: connection timeout not explicitly configured.

### 3.13.10 — Establish and manage cryptographic keys for required cryptography employed
**Status:** ⚠️ Partially Implemented — POA&M #SC-1  
**Implementation:** Age private key (`~/.config/sops/age/keys.txt`) is the root key for all SOPS-encrypted secrets. TLS keys are managed by Caddy/Let's Encrypt automatically.  
**Gap:** No formal key management lifecycle document (generation, distribution, rotation, destruction). Age key has no documented off-host backup.

### 3.13.11 — Employ FIPS-validated cryptography when used to protect CUI
**Status:** N/A — No CUI is currently processed  
**Note:** WireGuard's ChaCha20-Poly1305 is not FIPS-validated. If FIPS compliance is required by contract, TLS-based transport with OpenSSL (FIPS mode) would be needed.

### 3.13.12 — Prohibit remote activation of collaborative computing devices and provide indication to present users
**Status:** N/A — No collaborative computing devices (cameras/microphones) are part of this system boundary.

### 3.13.13 — Control and monitor the use of mobile code
**Status:** ✅ Implemented  
**Implementation:** Next.js bundles are built from audited source. CSP headers restrict mobile code execution on the browser side. No untrusted mobile code is loaded by server-side components.

### 3.13.14 — Control and monitor the use of VoIP technologies
**Status:** N/A — No VoIP is part of this system.

### 3.13.15 — Protect the authenticity of communications sessions
**Status:** ✅ Implemented  
**Implementation:** TLS provides session authenticity via certificate validation. Tailscale device certificates provide VPN session authenticity.

### 3.13.16 — Protect CUI at rest
**Status:** ✅ Implemented (for non-CUI backups)  
**Implementation:** Daily database backups are AES-256 encrypted before Proton Drive transfer. Docker volumes on the on-prem server are on the host filesystem — full-disk encryption depends on the macOS host (FileVault must be enabled).  
**Gap:** Confirm FileVault is enabled on the on-prem macOS server. Document in physical protection section.

---

## 3.14 — System and Information Integrity

### 3.14.1 — Identify, report, and correct information and information system flaws
**Status:** ✅ Implemented  
**Implementation:** UPDATE_CADENCE.md defines the vulnerability identification and patching process. GitHub Dependabot provides automated flaw notification. `composer audit` and `npm audit` provide application-level flaw detection.

### 3.14.2 — Provide protection from malicious code at entry points and exit points
**Status:** ⚠️ Partially Implemented — POA&M #SI-3  
**Implementation:** Rate limiting at Caddy entry point. Drupal's Form API validates and sanitizes all user input. No dedicated malware scanning on uploads.  
**Gap:** No antivirus or endpoint detection and response (EDR) on the on-prem macOS server or VPS.

### 3.14.3 — Monitor system security alerts and advisories and take action in response
**Status:** ✅ Implemented  
**Implementation:** GitHub Dependabot alerts. NIST NVD RSS / drupal.org security advisories (tracked per UPDATE_CADENCE.md). Prometheus alert on anomalous traffic patterns.

### 3.14.4 — Update malicious code protection mechanisms
**Status:** N/A — No dedicated malicious code protection is deployed. See 3.14.2.

### 3.14.5 — Perform periodic scans and real-time scans of files from external sources
**Status:** ❌ Not Implemented — POA&M #SI-3  
**Implementation:** No file upload scanning is implemented.  
**Action:** For file upload endpoints (Drupal media library), consider ClamAV or equivalent.

### 3.14.6 — Monitor systems to detect attacks and indicators of compromise
**Status:** ⚠️ Partially Implemented — POA&M #SI-4  
**Implementation:** Prometheus alerts on service anomalies. Caddy access logs are available for forensic review. `fail2ban` detects and blocks SSH brute-force.  
**Gap:** No SIEM or intrusion detection system (IDS) provides real-time indicator-of-compromise detection.

### 3.14.7 — Identify unauthorized use of systems
**Status:** ⚠️ Partially Implemented — POA&M #SI-4  
**Implementation:** Tailscale provides device visibility. Drupal watchdog captures access-denied events. `fail2ban` detects brute-force attempts.  
**Gap:** No behavioral analytics or anomaly detection baseline.

---

## Control Summary

| Family | Implemented | Partially Implemented | Not Implemented | N/A |
|--------|------------|----------------------|-----------------|-----|
| 3.1 Access Control (22) | 10 | 7 | 3 | 2 |
| 3.2 Awareness & Training (3) | 0 | 2 | 1 | 0 |
| 3.3 Audit & Accountability (9) | 2 | 5 | 2 | 0 |
| 3.4 Configuration Management (9) | 5 | 4 | 0 | 0 |
| 3.5 Identification & Authentication (11) | 5 | 3 | 3 | 0 |
| 3.6 Incident Response (3) | 1 | 1 | 1 | 0 |
| 3.7 Maintenance (6) | 2 | 3 | 1 | 0 |
| 3.8 Media Protection (9) | 1 | 1 | 2 | 5 |
| 3.9 Personnel Security (2) | 0 | 1 | 1 | 0 |
| 3.10 Physical Protection (6) | 0 | 3 | 1 | 2 |
| 3.11 Risk Assessment (3) | 1 | 1 | 1 | 0 |
| 3.12 Security Assessment (4) | 2 | 2 | 0 | 0 |
| 3.13 System & Comms Protection (16) | 10 | 5 | 0 | 1 |
| 3.14 System & Info Integrity (7) | 2 | 3 | 2 | 0 |
| **Total (110)** | **41** | **41** | **18** | **10** |

_Score: 41/100 implemented (N/A controls excluded). With partial credit, approximately 61/100. Target before CUI authorization: 90+/100._
