# Data Classification & Handling Policy

**Organization:** Wilkes & Liberty  
**Maintained by:** Jeremy (`3@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23  
**Framework reference:** NIST SP 800-171 §3.1.3, §3.8, §3.11.3; NIST SP 800-60

---

## 1. Purpose

This policy defines the categories of data that Wilkes & Liberty handles, the classification of each category, and the handling requirements for each classification level. It establishes the boundaries for what data can flow through the development infrastructure described in the System Security Plan.

---

## 2. Classification Tiers

| Tier | Label | Description | Examples |
|------|-------|-------------|---------|
| 1 | **Public** | Information intended for public consumption; no harm if disclosed | Website content, published articles, public API responses |
| 2 | **Internal** | Non-sensitive business information; not for external sharing but low impact if disclosed | Internal documentation, configuration (non-secret), deployment logs |
| 3 | **Confidential** | Sensitive business information; disclosure would cause business harm | Customer PII, credentials, API tokens, business strategy |
| 4 | **CUI** | Controlled Unclassified Information as defined by the National Archives and Records Administration | Data received under a federal contract with a CUI designation (not currently handled — see §6) |

---

## 3. Data Inventory

### 3.1 Data currently handled by this system

| Data type | Classification | Where stored | Who can access | Retention |
|-----------|---------------|--------------|----------------|-----------|
| Website content (articles, pages) | Public | Drupal DB (PostgreSQL) | Public (read); admin (write) | Indefinite |
| Next.js rendered pages | Public | VPS filesystem (ephemeral) | Public | Build-time only |
| Drupal user accounts (email, username) | Confidential | Drupal DB | Drupal admin | Until deletion request |
| Webform submissions (name, email, message) | Confidential | Drupal DB | Drupal admin | 90 days (see §4.3) |
| Watchdog logs (IP addresses, user actions) | Internal | Drupal DB | Drupal admin | 30 days then truncated |
| Caddy access logs (IP, URL, timestamp) | Internal | VPS filesystem | Root; operator via SSH | 90 days then rotated |
| PostgreSQL backup dumps | Confidential | `~/Backups/wilkesliberty/daily/` (local) · Proton Drive (encrypted) | Operator (local); Proton Drive account | 30 days (rolling) |
| Drupal configuration exports | Internal | webcms git repo (`config/sync/`) | GitHub org members | Git history |
| SOPS-encrypted secrets | Confidential | `ansible/inventory/group_vars/*_secrets.yml` | SOPS age key holder | Indefinite (encrypted) |
| Tailscale device/network metadata | Internal | Tailscale SaaS | Tailscale admin console | Per Tailscale retention policy |

### 3.2 Data NOT handled by this system (explicit exclusions)

The following data types are **not** present in this system and must not be introduced without updating this policy and the SSP:

- Controlled Unclassified Information (CUI) — any federal contract data
- Payment Card Industry (PCI) data — no payment processing
- Protected Health Information (PHI) — no healthcare data
- Export-controlled information (EAR/ITAR)
- Classified national security information

---

## 4. Handling Requirements by Classification

### 4.1 Public

- No special handling required.
- May be stored, transmitted, and backed up without encryption.
- May be cached on CDN or public edge servers.

### 4.2 Internal

- Do not share externally without explicit approval.
- May be transmitted over encrypted channels (TLS, WireGuard) or plaintext on private networks.
- Retain as long as operationally useful; delete when no longer needed.
- Configuration files at this tier are stored in git (public or private repo as appropriate).

### 4.3 Confidential

- **Storage:** Encrypt at rest (SOPS+age for secrets; AES-256 for backups; PostgreSQL data volume protected by host FileVault).
- **Transmission:** TLS 1.2+ or WireGuard only. No plaintext transmission over any network.
- **Access:** Role-based; minimum necessary access. Log access where feasible.
- **Retention (PII):**
  - Webform submissions: review at 90 days; delete if no longer needed for business purposes.
  - User accounts: deactivate after 6 months of inactivity; delete on explicit request.
  - Watchdog logs: truncated to last 30 days in production; wiped entirely on staging refresh.
  - Caddy access logs: retain 90 days; rotate older logs.
- **Disposal:** Shred printed materials. Securely erase digital media (see §5).
- **Third-party sharing:** Only to vendors with appropriate data processing agreements (see [VENDOR_RISK.md](VENDOR_RISK.md)).

### 4.4 CUI (when applicable)

> **CUI handling is not currently authorized on this system.** This section defines the requirements that must be met before CUI can be introduced.

Before any CUI can be processed on this system:
1. Update the SSP to reflect CUI handling.
2. Achieve a POA&M score of 90+/100 on NIST 800-171 controls.
3. Obtain independent security assessment (3PA or self-assessment with SPRS score submitted to PIEE).
4. Ensure all personnel with CUI access have passed appropriate background checks (NACI minimum).
5. Enable FIPS-validated cryptography on all CUI data paths (note: WireGuard is not FIPS-validated; TLS with OpenSSL FIPS mode would be required).
6. Configure CUI marking on all documents and data fields containing CUI.
7. Review all third-party vendors for FedRAMP authorization (see VENDOR_RISK.md).

---

## 5. Media Sanitization & Disposal

### 5.1 Digital media

When storage media containing Confidential or higher data is decommissioned:
- **macOS hard drive / SSD:** Use Apple's Erase Assistant (System Settings → General → Transfer or Reset → Erase All Content) or `diskutil secureErase` for older drives.
- **Docker volumes:** `docker volume rm <volume>` removes the data. For the underlying filesystem, use the above macOS procedure.
- **Cloud volumes / VPS:** Destroy the VPS via the Njalla control panel. Confirm via Njalla that the volume is wiped.

### 5.2 Physical media

- Paper documents containing Confidential data: cross-cut shredding.
- No USB drives or optical media are used in this system (see portable storage policy below).

---

## 6. Portable Storage & Mobile Device Policy

- USB storage devices are not used to transport or store Confidential or higher data.
- If a USB device must be used (e.g., OS reinstall media), it must be encrypted (macOS FileVault USB) and wiped after use.
- Mobile devices (phones, tablets) with access to the Tailscale network are subject to Tailscale ACL tag restrictions (see [TAILSCALE_ACL_DESIGN.md](../TAILSCALE_ACL_DESIGN.md)).
- Mobile devices must have device-level encryption (screen lock + FileVault/FDE).

---

## 7. Privacy

Wilkes & Liberty collects limited personal information through the public website (webform submissions, contact requests). The following principles apply:
- Collect only what is necessary for the stated purpose.
- Do not sell or share PII with third parties except as required to operate the service (Postmark for email delivery).
- Honor deletion requests.
- The Postmark sandbox server used for staging cannot deliver to real users (prevents accidental PII leakage from testing).
