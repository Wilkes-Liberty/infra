# Vendor Risk Management

**Organization:** Wilkes & Liberty  
**Maintained by:** Jeremy (`3@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23  
**Review cadence:** Annually or when a new vendor is added

---

## Purpose

This document inventories all third-party vendors, describes what data each can access, records their security certification status, and defines the review cadence. For federal contracting: a FedRAMP-authorized vendor is preferred wherever feasible.

---

## Vendor Inventory

### Tailscale
| Field | Value |
|-------|-------|
| **Purpose** | WireGuard VPN mesh — connects on-prem server to VPS and operator devices |
| **Data accessible** | Device metadata, IP addresses, network topology, DNS queries (if using MagicDNS); **no application data passes through Tailscale's servers** (only key exchange via coordination server; data plane is peer-to-peer encrypted) |
| **Data classification** | Internal (network metadata) |
| **Account tier** | Premium |
| **SOC 2 Type II** | Yes (as of 2023; verify current at tailscale.com/security) |
| **FedRAMP** | Not authorized |
| **MFA enabled** | Yes (required) |
| **Risk notes** | Tailscale coordination server sees device enrollment events and connection metadata but cannot decrypt application data. Compromise of the Tailscale account would expose network topology but not application data. |
| **Contractual controls** | Tailscale Terms of Service; review Data Processing Agreement at tailscale.com |

---

### Postmark (ActiveCampaign)
| Field | Value |
|-------|-------|
| **Purpose** | Transactional email delivery (Drupal SMTP, backup failure alerts, config snapshot notifications) |
| **Data accessible** | Email headers, body, and attachments of all emails sent through the server token. Bounce/complaint events received via webhook. |
| **Data classification** | Confidential (may contain PII in email body) |
| **SOC 2 Type II** | Yes (postmarkapp.com/security) |
| **FedRAMP** | Not authorized |
| **MFA enabled** | Yes (enable on account) |
| **Risk notes** | Postmark sees email content. Emails sent via Drupal may contain user names and contact information from webform submissions. Do not send CUI via email without encryption. |
| **Contractual controls** | Postmark Terms of Service; Data Processing Agreement available |

---

### Njalla (VPS + DNS registrar)
| Field | Value |
|-------|-------|
| **Purpose** | VPS hosting (Caddy + Next.js) and DNS registrar for `wilkesliberty.com` |
| **Data accessible** | VPS: disk contents of the VPS (Caddy configs, TLS certificates, Next.js built assets — no application data). DNS: domain registration records. |
| **Data classification** | Internal |
| **SOC 2 Type II** | Not publicly listed |
| **FedRAMP** | Not authorized |
| **MFA enabled** | Yes (enable on account) |
| **Risk notes** | Njalla is a privacy-focused provider registered in Sweden. The VPS contains no persistent application data (stateless). DNS control means Njalla could theoretically redirect traffic — mitigated by Tailscale mesh for critical services. |
| **Contractual controls** | Njalla Terms of Service. For federal work involving CUI, consider migrating VPS to a FedRAMP-authorized provider (AWS GovCloud, Azure Government). |

---

### Proton Drive (backup storage)
| Field | Value |
|-------|-------|
| **Purpose** | Offsite encrypted backup storage for daily database and file backups |
| **Data accessible** | Encrypted backup archives only. Proton Drive has zero-knowledge encryption — they cannot read the contents without the `BACKUP_ENCRYPTION_KEY`. |
| **Data classification** | Confidential (encrypted) |
| **SOC 2 Type II** | Not publicly listed (Proton AG is ISO 27001 certified) |
| **FedRAMP** | Not authorized |
| **MFA enabled** | Yes (required) |
| **Risk notes** | Backups are AES-256 encrypted before upload. Even if Proton Drive is compromised, backup contents cannot be read without the encryption key. The key risk is availability — if Proton Drive is unavailable, the offsite backup is inaccessible (local backup remains). |

---

### GitHub (source code hosting)
| Field | Value |
|-------|-------|
| **Purpose** | Source code version control for `infra`, `webcms`, and `ui` repos |
| **Data accessible** | All committed source code, commit history, pull requests, issues. SOPS-encrypted secrets files are committed (but encrypted). |
| **Data classification** | Internal (source code) / Confidential (encrypted secrets, commit metadata) |
| **SOC 2 Type II** | Yes (GitHub Enterprise; GitHub.com shared controls) |
| **FedRAMP** | GitHub Enterprise Cloud is FedRAMP Moderate authorized |
| **MFA enabled** | Yes (required on organization) |
| **Risk notes** | GitHub has access to all source code. Encrypted secrets files in the repo cannot be read without the age key. For federal work involving sensitive source code, consider GitHub Enterprise with FedRAMP authorization or an on-prem alternative. |

---

### Let's Encrypt (ACME certificate authority)
| Field | Value |
|-------|-------|
| **Purpose** | TLS certificate issuance for `*.wilkesliberty.com` and `*.int.wilkesliberty.com` |
| **Data accessible** | Domain names in certificate requests, ACME challenge responses |
| **Data classification** | Internal |
| **SOC 2 Type II** | Not applicable (nonprofit CA) |
| **FedRAMP** | Not applicable |
| **Risk notes** | Let's Encrypt is a widely-trusted CA operated by the Internet Security Research Group (ISRG). For federal systems requiring specific CA validation, a government-trusted CA may be required. |

---

## Vendor Review Process

**Annual review:** Confirm each vendor's SOC 2 / ISO certification is current. Check for any breach notifications or security incidents. Update this document.

**New vendor checklist (before adding any new vendor):**
1. Identify what data the vendor will access.
2. Review their security page, SOC 2 report, and Privacy Policy.
3. Determine if a Data Processing Agreement is available/required.
4. For CUI: confirm FedRAMP authorization status.
5. Add the vendor to this document before provisioning credentials.
6. Add the vendor's credentials to sops.

**Next review due:** 2027-04-23
