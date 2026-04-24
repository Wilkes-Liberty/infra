# Physical Security Policy — Home Office

**Organization:** Wilkes & Liberty, LLC  
**Maintained by:** Jeremy Michael Cerda (`jmcerda@wilkesliberty.com`)  
**Last reviewed:** 2026-04-24  
**Applies to:** WFH home office supporting W&L infra operations and the principal's Tier 4 Public Trust continuous-evaluation posture  
**Framework:** NIST SP 800-171 Rev 2 — PE control family (PE-1 through PE-17 as applicable)

> **Scope note:** This environment does not currently process Controlled Unclassified Information (CUI). The controls documented here reflect good-hygiene practices appropriate for a home office where: (a) the principal holds a Tier 4 Public Trust position subject to continuous evaluation, (b) W&L infra hardware is physically located, and (c) the environment is the aspirational operations base for future W&L federal work. These controls demonstrate physical security readiness; they are not currently required by any active federal contract.

---

## 1. Work Area Definition

The **W&L work area** consists of two contiguous spaces:

| Space | Description |
|-------|-------------|
| **Office** | Dedicated room with door that locks; contains work desk, work laptop, W2-EPA device, and primary work monitors |
| **Server closet** | Closet within or adjacent to the office; contains the W&L infra rack (on-prem macOS server, networking hardware) |

Together these two spaces form the physical boundary of W&L's operational environment. All controls in this document apply to both spaces as a single work area.

---

## 2. Access Control — Work Area

### 2.1 Who may enter

| Session type | Authorized persons |
|-------------|-------------------|
| **Active work session (sensitive)** — W2 EPA work, Keycloak/credential management, SOPS secrets, Tailscale admin, code reviews with sensitive data | Principal only (Jeremy Michael Cerda). No other person in the room. |
| **Non-sensitive work session** — general development, doc writing, non-credential tooling | Principal; spouse (Aleksandra Cerda) may enter briefly. No extended presence without awareness. |
| **Server closet — active hardware work** | Principal only. |
| **Server closet — idle** | Closet door locked. |
| **Casual visitors / guests** | Not admitted to work area during any work session. Work area door closed and locked when visitors are present elsewhere in home. |

### 2.2 Physical controls

- Office door: **lockable**. Lock when leaving for extended periods or when guests are present in the home.
- Server closet: **lockable**. Keep locked when not actively working on hardware. Close and lock after every maintenance session.
- Monitors: position screens so they are not visible through the office door when ajar or through any window.
- Printed materials: no sensitive printed materials left unattended on desk. Shred before disposal.

### 2.3 Cohabitant policy

Aleksandra Cerda is Jeremy's spouse and cohabitant. She holds a Tailscale break-glass account (`acerda`) for business continuity (see `docs/team/ROLES.md` and `docs/PROJECT_PLAN.md` Phase D). She is not a W&L employee and is not authorized for routine access to the work area, server closet, or W2 EPA device. Her presence in the home is already disclosed in Jeremy's SF-86 (Section 18 cohabitant scope) as required for Tier 4 Public Trust.

---

## 3. Trust Zone Model

The home network is partitioned into three trust zones. **The current state is a flat network; the target state requires the network rewrite described in `docs/NETWORK_PLAN.md` (Path 2 — Firewalla Gold SE).**

| Zone | VLAN (target) | Devices | Inter-zone rules |
|------|--------------|---------|-----------------|
| **Work** | `work` | W&L on-prem server, W2-EPA device, work laptop | No inbound from IoT or Personal. Outbound to internet unrestricted (Tailscale manages VPN overlay). |
| **IoT-HomeKit** | `iot-homekit` | Aqara cameras, Logitech Circle View doorbell, HomePods, Eve devices, Ecobee | mDNS reflection enabled (HomeKit requires local discovery). No access to Work VLAN. |
| **IoT-Untrusted** | `iot-untrusted` | Emporia Vue, Sensibo, LG WashTower, Moen Flo, Samsung Frame TV, Sony Bravia TV | Egress-only; cloud-dependent devices with no LAN access requirement. No access to Work or IoT-HomeKit VLANs. |
| **Personal** | `personal` | Phones, tablets, family devices | No access to Work VLAN. Limited IoT access (Apple Home app needs to reach HomeKit hub). |
| **Guest** | `guest` | Visitor devices | Internet-only; no LAN access. |

**Current state gap:** The flat network means IoT devices and work systems share a broadcast domain. This is tracked as a HIGH-priority open issue — see `docs/OPEN_ISSUES.md` §Physical Security & Network. Mitigation until segmentation is live: Tailscale provides encrypted overlay for W&L server traffic regardless of local network topology; EPA device is kept physically separate.

---

## 4. Device Inventory

### 4.1 Camera inventory

All cameras are HomeKit-compatible and record to iCloud via HomeKit Secure Video (HKSV). HKSV recordings are end-to-end encrypted. Advanced Data Protection should be enabled on the Apple ID used for HomeKit to extend E2E encryption to iCloud Backup (see OPEN_ISSUES.md).

| # | Camera | Type | Placement | Line-of-sight to work area? | Audio in work area? | Notes |
|---|--------|------|-----------|---------------------------|--------------------|----|
| 1 | Aqara G5 Pro PoE | Wired, outdoor | [FILL IN — outdoor placement] | No | No | Wired; network segment: target `iot-homekit` VLAN |
| 2 | Aqara G5 Pro PoE | Wired, outdoor | [FILL IN — outdoor placement] | No | No | |
| 3 | Aqara G5 Pro PoE | Wired, outdoor | [FILL IN — outdoor placement] | No | No | |
| 4 | Aqara G5 Pro PoE | Wired | [FILL IN] | **Verify: No** | **Verify: No** | If indoor, confirm no LOS to monitors or keyboard |
| 5 | Aqara G5 Pro PoE | Wired | [FILL IN] | **Verify: No** | **Verify: No** | |
| 6 | Aqara G5 Pro WiFi | WiFi | [FILL IN] | **Verify: No** | **Verify: No** | |
| 7 | Aqara G5 Pro WiFi | WiFi | [FILL IN] | **Verify: No** | **Verify: No** | |
| 8 | Aqara G5 Pro WiFi | WiFi | [FILL IN] | **Verify: No** | **Verify: No** | |
| 9 | Netatmo camera + siren | WiFi | [FILL IN] | **Verify: No** | **Verify: No** | Has siren; confirm placement is not adjacent to office |
| 10 | Logitech Circle View | Wired doorbell | Front door / entry | No | No | Doorbell — outdoors; audio captures entry area only |

**Camera policy:**
- No camera may have a direct line of sight to work monitors, keyboard, printed materials on desk, or the server closet interior when open.
- No camera with a microphone may be positioned where it could capture audio from the work area during a sensitive work session.
- Aqara G5 Pro supports local HomeKit hub recording without cloud egress for HKSV — confirm in Aqara app that cloud sync is disabled if HomeKit hub is present (preferred local mode).
- All camera placements must be re-verified after any furniture rearrangement or camera repositioning.

### 4.2 Smart speakers

| Device | Count | Location | Policy |
|--------|-------|----------|--------|
| HomePod (full-size) | 1 | **Not in office** — physically relocated to another room | "Listen for Hey Siri" disabled. Siri disabled. |
| HomePod mini | 3 | **Not in office** — physically relocated to other rooms | "Listen for Hey Siri" disabled. Siri disabled. |

**Smart speaker rule:** No HomePods, HomePod minis, Amazon Echo, Google Nest, or any always-listening smart speaker is permitted in the office or server closet — ever. If a HomePod is used as a HomeKit hub, it must remain in a non-work room. Verify "Listen for Hey Siri" is off on every HomePod via **Home app → Home Settings → [HomePod] → Hey Siri → Off**. Also verify in **Settings → Siri & Search** on any Apple TV used as a HomeKit hub.

See OPEN_ISSUES.md for the action item to confirm physical relocation is complete.

### 4.3 Televisions

| Device | Location | Always-listening? | Action required |
|--------|----------|------------------|----------------|
| Samsung Frame TV | [FILL IN — room] | Samsung Bixby + ACR/Samba TV analytics | Disable: **Settings → Support → Terms & Privacy → Viewing Information Services (ACR/Samba) → Off**. Also disable Bixby Voice. Confirm microphone indicator is off. |
| Sony Bravia | [FILL IN — room] | Google Assistant (if enabled) + Sony telemetry | Disable: **Settings → Device Preferences → Google Assistant → Off**. Disable Sony's SonyCrackle/Bravia telemetry via **Settings → About → Legal Information → Usage and Diagnostics → Off**. |

**TV rule:** Neither TV may be positioned in the office or with a line of sight into the office. Both TVs should have all ACR (Automatic Content Recognition), voice assistant, and analytics features disabled. Verify annually. See OPEN_ISSUES.md for the action item.

### 4.4 Other smart devices

| Device | Cloud dependency | Placement concern | Target VLAN |
|--------|-----------------|-------------------|-------------|
| Ecobee thermostat | Ecobee cloud (has mic — check model for Alexa) | Not in office; hallway/common area | `iot-homekit` (HomeKit-compatible) |
| Sensibo AC controller | Sensibo cloud | Near minisplit — not in office | `iot-untrusted` |
| LG WashTower | LG ThinQ cloud | Laundry — not in office | `iot-untrusted` |
| Moen Flo | Moen cloud | Near water main | `iot-untrusted` |
| Emporia Vue (×3 panels) | Emporia cloud | Circuit panels — utility space | `iot-untrusted` — note: sends panel energy data to cloud; low-severity pattern inference possible |
| Eve devices (switches, outlets, leak sensor) | Local HomeKit / Thread — no cloud dependency | Throughout home | `iot-homekit` — no cloud; Thread runs locally |
| Homebridge server (planned) | Local | Dedicated Pi or mini-PC — **NOT on W&L server** | `iot-homekit` — keep strictly separated from Work VLAN |

> **Homebridge isolation rule:** Homebridge (if/when deployed) must run on a dedicated host — a Raspberry Pi, N100 mini-PC, or equivalent — on the `iot-homekit` VLAN. It must never be co-hosted on the W&L infra server. IoT automation is an untrusted personal domain; W&L server is the operations base for aspirational federal work. Mixing them violates the trust zone model and could expose W&L infra to home-automation vulnerabilities.

---

## 5. Server Rack Physical Security

| Control | Current state | Target state |
|---------|--------------|-------------|
| Location | Office closet (rack mounted above closet) | Same — no change planned |
| Closet lock | [FILL IN — confirm lock exists and key is secured] | Locked when not actively working on hardware |
| Ventilation / temperature | [FILL IN — current monitoring status] | Temperature sensor reporting to Prometheus/Alertmanager (see OPEN_ISSUES.md) |
| Cable management | [FILL IN] | All cables labeled; no dangling connections that could be inadvertently pulled |
| Authorized access | Jeremy only | Same |

**Procedure:** Before leaving the office at end of day, confirm the server closet door is closed and locked. Do not prop the door open for airflow — use a dedicated ventilation solution if needed.

---

## 6. NIST 800-171 Rev 2 — PE Control Cross-Reference

| Control | Title | Implementation status | Notes |
|---------|-------|-----------------------|-------|
| PE-1 | Physical and environmental protection policy | ⚠️ Partial | This document is the policy; no formal review cadence yet |
| PE-2 | Physical access authorizations | ⚠️ Partial | Defined in §2 (access rules table); no formal access log |
| PE-3 | Physical access control | ⚠️ Partial | Lockable door and closet; no electronic badge/keycard system |
| PE-6 | Monitoring physical access | ⚠️ Partial | Camera coverage of exterior and entry; no interior work-area camera (by design — §4.1 camera policy) |
| PE-11 | Emergency power | ❌ Not implemented | No UPS documented for server rack. Add to OPEN_ISSUES. |
| PE-12 | Emergency lighting | N/A | Home office; standard residential lighting in place |
| PE-13 | Fire protection | ⚠️ Partial | Residential smoke detectors; no server-grade suppression system |
| PE-14 | Temperature and humidity controls | ⚠️ Partial | Office HVAC (Ecobee); no automated monitoring of server closet temp (see OPEN_ISSUES.md) |
| PE-15 | Water damage protection | ⚠️ Partial | Eve water leak sensor and Moen Flo (water main shutoff); not specifically positioned at server rack |
| PE-17 | Alternate work site | ⚠️ Partial | Tailscale remote access allows operations from any location; no formal alternate-site policy |

_Controls PE-4, PE-5, PE-7, PE-8, PE-9, PE-10, PE-16 are not applicable or not yet relevant at the current scale._

---

## 7. Review Cadence

| Trigger | Action |
|---------|--------|
| **Annual** | Review this document end-to-end; update camera inventory, device list, and NIST cross-reference table |
| **Home network changes** | Re-verify trust zone model reflects current VLAN assignments; update §3 |
| **New IoT device added** | Add to §4, assess trust zone placement and LOS risk before installation |
| **Camera repositioned** | Immediately re-verify LOS compliance per §4.1 camera policy |
| **Gridiron IT security review** | Confirm home-office controls satisfy Gridiron IT WFH physical security requirements for Tier 4 holders |

_Next scheduled review: 2027-04-24_

---

## 8. Related Documents

| Document | Relationship |
|----------|-------------|
| `docs/NETWORK_PLAN.md` | Path 2 network segmentation implementation (Firewalla Gold SE) — required to achieve target VLAN state in §3 |
| `docs/OPEN_ISSUES.md` | Open action items referenced throughout this document |
| `docs/compliance/SSP.md` | System Security Plan — PE controls cross-referenced |
| `docs/compliance/ACCESS_CONTROL.md` | Logical access controls complementing these physical controls |
| `docs/compliance/INCIDENT_RESPONSE.md` | Physical-breach scenarios covered in incident response |
| `docs/PROJECT_PLAN.md` | Active initiatives — network rewrite deferred until after Keycloak Phase A |
| `docs/COMPANY_PROFILE.md` | Continuous-evaluation obligations that make this posture load-bearing |
