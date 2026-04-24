# Home Network Rewrite Plan — Path 2 (Firewalla Gold SE)

**Organization:** Wilkes & Liberty, LLC  
**Maintained by:** Jeremy Michael Cerda (`jmcerda@wilkesliberty.com`)  
**Last reviewed:** 2026-04-24  
**Status:** Deferred — starts after Keycloak Phase A lands (see `docs/PROJECT_PLAN.md`)  
**Estimated effort:** 1–2 evenings for setup; 1 weekend for VLAN migration and tuning

---

## 1. Why This Matters

The current home network is flat — work systems (W&L server, W2-EPA device, work laptop), IoT devices (cameras, smart speakers, cloud-connected appliances), and personal devices share a single broadcast domain. This violates the trust zone model defined in `docs/compliance/PHYSICAL_SECURITY.md` §3 and creates real operational risk:

- A compromised IoT device can reach the W&L server directly on the local network.
- HomeKit cameras and smart speakers on the same subnet as work systems expand the attack surface for lateral movement.
- Cloud-dependent appliances (LG WashTower, Emporia Vue, etc.) have no egress control — they can beacon to arbitrary cloud endpoints.

Firewalla Gold SE resolves this by adding a proper firewall with VLAN support upstream of the existing Eero mesh, which then operates as APs only (bridge mode).

---

## 2. Current State

| Component | Details |
|-----------|---------|
| **ISP** | AT&T Fiber |
| **Modem/ONT** | AT&T gateway (bridge-mode status: **unconfirmed** — see Open Questions) |
| **Router / Mesh** | Eero Pro 7 Max mesh (3 indoor + 1 outdoor extender) — Wi-Fi 7, 10GbE WAN port, built-in Thread border router |
| **VLAN capability** | None. Eero supports only a single Guest Network; does not support 802.1Q VLANs or multiple SSIDs with VLAN tagging. |
| **Guest Network** | Available but insufficient: no mDNS reflection (breaks HomeKit discovery), no per-device ACLs |
| **Switch** | [FILL IN — confirm whether current switch is managed or unmanaged; PoE status] |
| **Cabling** | [FILL IN — which Eero nodes and server rack ports are wired vs WiFi] |

**Consequence:** All work and IoT devices are on a flat `192.168.x.0/24` or equivalent. No inter-segment firewall. All devices can reach all devices.

---

## 3. Target State — Path 2

```
AT&T ONT / gateway (bridge mode)
        │
   [WAN port]
  Firewalla Gold SE  ◄── router, firewall, VLAN trunk, DNS filter, mDNS reflector
   [LAN port / trunk]
        │ (802.1Q trunk)
   Eero mesh (bridge mode — APs only, no routing)
        ├── SSID: work        → VLAN 10
        ├── SSID: iot-homekit → VLAN 20
        ├── SSID: iot-cloud   → VLAN 30
        ├── SSID: personal    → VLAN 40
        └── SSID: guest       → VLAN 50
```

> **Note on Eero bridge mode:** Eero bridge mode disables Eero's DHCP and routing; Eero nodes become 802.11 access points that pass VLAN-tagged traffic to Firewalla. The Eero Pro 7 Max supports bridge mode — confirmed.

### 3.1 VLAN Design

| VLAN | Name | Subnet | Devices | Inter-VLAN rules |
|------|------|--------|---------|-----------------|
| 10 | `work` | `10.0.10.0/24` | W&L on-prem server, W2-EPA device, work laptop, wired server rack ports | No inbound from any other VLAN. Unrestricted internet egress (Tailscale handles VPN overlay). |
| 20 | `iot-homekit` | `10.0.20.0/24` | Aqara PoE cameras (wired), Aqara WiFi cameras, Logitech Circle View doorbell, HomePods (HomeKit hub role), Eve devices (Thread via HomePod), Ecobee | mDNS reflection enabled (required for HomeKit discovery). No access to `work` VLAN. Limited outbound: Apple push (APN), Aqara cloud (if enabled), Ecobee cloud. |
| 30 | `iot-untrusted` | `10.0.30.0/24` | Emporia Vue, Sensibo, LG WashTower, Moen Flo, Samsung Frame TV, Sony Bravia TV | Egress allowlist only — each device allowed to its known cloud endpoint(s); all other outbound blocked. No inbound from any VLAN. No LAN access. |
| 40 | `personal` | `10.0.40.0/24` | iPhones, iPads, Macs (personal), family devices | Internet unrestricted. Access to `iot-homekit` VLAN on HomeKit ports only (Home app discovery). No access to `work` VLAN. |
| 50 | `guest` | `10.0.50.0/24` | Visitor devices | Internet only. No LAN access. Rate-limited. |
| 99 | `mgmt` (future) | `10.0.99.0/24` | Switch management interface, Firewalla management | Admin-only; no internet egress. |

### 3.2 Firewalla Gold SE — Key Capabilities Used

| Feature | Use |
|---------|-----|
| VLAN creation and tagging | Defines all zones in §3.1 |
| Per-VLAN firewall rules | Inter-VLAN access control and egress allowlists |
| mDNS reflection | Lets Home app on `personal` VLAN discover HomeKit accessories on `iot-homekit` VLAN — required for HomeKit |
| DNS filtering (Firewalla built-in) | Ad/tracker blocking per VLAN; blocks known malicious domains |
| Flow logging / traffic monitor | Per-device outbound traffic visibility; surfacing unexpected beaconing |
| Egress allowlist mode | Restrict `iot-untrusted` devices to known cloud endpoints only |
| Built-in Tailscale | May allow Tailscale to run on Firewalla itself — simplifies remote admin; evaluate during setup |
| Intrusion detection (IDS) | Passthrough IDS for anomaly detection; lightweight, built-in |

### 3.3 Pros of Current Gear for the New Design

The Eero Pro 7 Max is a strong foundation for this architecture:

| Feature | Benefit |
|---------|---------|
| **Wi-Fi 7 (802.11be)** | Future-proof wireless; handles high-density IoT + multi-device work load with headroom to spare |
| **10GbE WAN port** | Can fully utilize a multi-gig AT&T fiber plan (1Gbps, 2Gbps, or higher) — but see Procurement §4 for Firewalla WAN-speed note |
| **Built-in Thread border router** | Eero Pro 7 Max acts as a native Thread border router (Matter-compatible). Eve devices running Thread can route through the Eero's native Thread BR rather than requiring a HomePod as the sole Thread hub. This may simplify the `iot-homekit` VLAN design: Thread mesh operates at L2 and is separate from IP routing, so Eve accessories may remain reachable from the Eero/HomePod Thread BR even after VLAN changes — but verify behavior in bridge mode (see Open Questions and Step 6). |
| **Mesh backhaul** | Tri-band backhaul on indoor nodes; outdoor extender extends coverage without additional APs |

---

## 4. Procurement

**AT&T plan confirmed: Internet 5000 (5 Gbps symmetric).** The Eero Pro 7 Max has a 10GbE WAN port and can deliver full line rate. Any firewall with a sub-10GbE WAN port will cap throughput. Choose model before ordering.

### 4.1 Firewall Model Comparison

| Model | Price | WAN port | Notes |
|-------|-------|---------|-------|
| **Firewalla Gold SE** | ~$450 | 4× 2.5GbE | Caps WAN at ~2.3 Gbps — roughly half of paid line speed. Acceptable if 2.5 Gbps is enough for realistic workloads (most internet destinations can't sustain more than 1 Gbps to a single host anyway). Same Firewalla UX as Gold Pro; native Tailscale integration; easiest setup. |
| **Firewalla Gold Pro** | ~$900 | 2× 10GbE + 2× 2.5GbE | Full 5 Gbps line-rate. Same Firewalla UX, DNS filtering, mDNS reflector, built-in Tailscale. Best choice for line-speed preservation within the Firewalla ecosystem. |
| **UniFi Dream Machine Pro Max** | ~$600 | 10GbE SFP+ WAN + 10GbE SFP+ LAN + 8× 2.5GbE | Full line-rate. Richer platform: unified GUI across firewall, switches, and APs; deeper IDS/IPS; advanced logging. No native Tailscale (WireGuard site-to-site supported). Steeper learning curve. Best long-term if you want one managed-network platform. |
| **UniFi Cloud Gateway Fiber** | ~$279–500 | 10GbE SFP+ WAN | Cheapest 10GbE option; less capable than UDM Pro Max; historically limited stock. |
| **pfSense / OPNsense on Protectli** | ~$800+ | 10GbE NIC (varies) | Maximum flexibility; maximum effort. Not recommended unless you want to invest deeply in network administration. |

> **Recommendation:** The **Firewalla Gold Pro** is the default balanced choice for this environment. It preserves full 5 Gbps line rate, keeps the same Firewalla UX and configuration model described throughout this plan, includes built-in Tailscale (which fits the existing Tailscale-heavy architecture), and requires no re-learning. The ~$450 premium over the Gold SE buys full line-rate preservation and headroom for any future AT&T speed tier upgrade.
>
> If you want to invest in a managed-network platform for the long term — a single GUI for switches, APs, and firewall — the **UniFi Dream Machine Pro Max** is the stronger long-term bet at a lower price point. The tradeoffs are real: learning curve, no native Tailscale integration, and adding UniFi mid-project increases scope. Best considered after Phases A–D are complete and the network rewrite is your primary focus.
>
> The **Firewalla Gold SE** remains reasonable if capping at 2.5 Gbps is acceptable and you want the lowest cost and simplest setup. For most home-office workloads — including simultaneous 4K streaming, VoIP, and heavy cloud sync across multiple devices — 2.5 Gbps is not a practical bottleneck.

### 4.2 Items to Procure

| Item | Purpose | Estimated cost | Status |
|------|---------|---------------|--------|
| **Firewall** *(model TBD — see §4.1 and Open Questions)* | Router/firewall replacing Eero's routing role | ~$450–900 | **Decide model before ordering** |
| **Managed PoE switch** (if needed) | VLAN-aware switch for wired server rack ports and wired Aqara cameras | ~$100–200 | Evaluate during pre-migration survey — only needed if current switch is unmanaged and wired VLAN tagging is required |
| **Cat6 patch cables** (if needed) | Clean up rack cabling to labeled-and-tidy standard | ~$20 | Evaluate |

> **Managed switch decision:** If the wired Aqara cameras and server rack currently connect through an unmanaged switch, that switch cannot do VLAN tagging — all wired ports will land on the native/untagged VLAN. Options: (a) replace with a VLAN-aware managed switch, (b) trunk directly from Firewalla to each device with a VLAN-aware port, or (c) accept that wired cameras are on the same VLAN as WiFi IoT (acceptable if `iot-homekit` is already isolated from work). Decide during pre-migration survey.

---

## 5. Pre-Requisites Before Starting

1. **Keycloak Phase A complete** (`docs/PROJECT_PLAN.md` Phase A) — identity foundation stable before changing network topology.
2. **Tailscale Phase B complete** — Tailscale OIDC wired to Keycloak so Tailscale connectivity is stable through network changes.
3. **Current network documented** — record all device IPs, MAC addresses, and physical connections before touching anything. Paste into a local scratch doc.
4. **AT&T gateway IP Passthrough verified** — Jeremy reports this is likely already enabled. Confirm before inserting the new firewall: log into `192.168.1.254` → **Firewall → IP Passthrough** — check that Passthrough is active. Quick sanity check: compare Eero's current WAN IP to `whatismyipaddress.com`; if they match, single-NAT is confirmed and IP Passthrough is already working. If Eero shows `192.168.x.x` on its WAN, double-NAT is in place — enable Passthrough and reassign the passthrough target to the new firewall's MAC when it arrives. See Step 2.
5. **Eero bridge mode confirmed** — Confirmed: Eero Pro 7 Max supports bridge mode.
6. **New firewall received** — decide model per §4.1 before purchasing; allow 3–5 days delivery after ordering.

---

## 6. Migration Steps

Execute in order. Each step has a rollback path. Do not skip ahead.

### Step 1 — Document current state
- Run `arp -a` and Firewalla's (pre-install) scan, or use your router's DHCP table, to get a complete device list with IPs and MAC addresses.
- Note which Eero nodes are wired (via ethernet backhaul) vs wireless.
- Confirm which switch ports serve the server rack and which serve cameras.
- **Rollback:** Nothing changed — no rollback needed.

### Step 2 — Enable IP Passthrough on AT&T gateway
- Log into AT&T gateway admin page (`192.168.1.254` default).
- Navigate to **Firewall → IP Passthrough**. Set mode to **Passthrough**, select the new firewall's MAC address as the passthrough device, and save.
- **AT&T hardware note:** BGW320 and BGW620 (standard hardware for Internet 5000) do not support true bridge mode — IP Passthrough is the correct equivalent and is fully supported. The gateway continues to handle the ONT/fiber handoff; the new firewall takes over all routing from its WAN port.
- Verify: after enabling passthrough, the new firewall's WAN interface should show a public IP (not `192.168.x.x`).
- **Rollback:** Disable IP Passthrough in AT&T gateway UI — the gateway resumes NAT and Eero can be reconnected directly. Internet restored.

### Step 3 — Place new firewall between AT&T gateway and Eero
- Power off Eero (all nodes).
- Connect firewall WAN port to AT&T gateway LAN port (IP Passthrough will hand the public IP to the firewall's MAC).
- Connect firewall LAN port to Eero primary node's WAN port.
- Power on firewall. Confirm it receives the public IP from AT&T via IP Passthrough (not a `192.168.x.x` address).
- Confirm the firewall's management app shows WAN connected.
- Power on Eero. Confirm Eero sees the new firewall as upstream and gets an IP.
- **Do not put Eero into bridge mode yet** — wait until VLANs are tested.
- **Rollback:** Remove new firewall, reconnect Eero directly to AT&T gateway, disable IP Passthrough (or re-point it to Eero's MAC). Internet restored.

### Step 4 — Verify basic connectivity before any VLAN work
- From a device connected to Eero: confirm internet access.
- From work laptop: confirm Tailscale is still connected and on-prem server is reachable.
- This validates the basic routing chain before anything is segmented.

### Step 5 — Define VLANs on Firewalla
- In the Firewalla app: create VLANs 10, 20, 30, 40, 50 per §3.1.
- Assign subnet, DHCP range, and DNS for each.
- Do **not** apply firewall rules or assign devices yet — just define the VLANs.

### Step 6 — Put Eero into bridge mode
- In Eero app: **Settings → Network Settings → DHCP & NAT → Bridge Mode → Enable**.
- Confirm: Eero nodes are now APs only; they pass VLAN-tagged frames to Firewalla.
- Confirm: internet access still works from a device connected to Eero.
- **Thread border router sub-check:** The Eero Pro 7 Max has a built-in Thread border router. Verify that Thread devices (Eve switches, outlets, water leak sensor) remain reachable from the Home app after Eero goes into bridge mode. Thread mesh operates at 802.15.4 (L2), separate from IP routing, so the Thread BR *may* continue to function in bridge mode — but this is not explicitly documented by Eero. If Eve devices go offline: check whether a HomePod on `iot-homekit` VLAN is taking over the Thread BR role (HomePods also act as Thread BRs and will do so automatically). If neither is working, consult Eero support forums or contact Eero support directly. Do not declare Step 6 complete until Eve devices are confirmed reachable from the Home app.
- **Rollback:** Re-enable DHCP & NAT in Eero app.

### Step 7 — Create SSIDs on Firewalla and tag to VLANs
- Firewalla does not serve WiFi directly — SSIDs are still served by Eero APs.
- Set up SSID-to-VLAN mapping: Eero supports per-SSID VLAN tagging in bridge mode.
  - `wl-work` → VLAN 10
  - `wl-iot-hk` → VLAN 20
  - `wl-iot-cloud` → VLAN 30
  - `wl-personal` → VLAN 40 (or rename to household SSID)
  - `wl-guest` → VLAN 50
- **Keep the existing Eero SSID active** and on VLAN 40 (`personal`) until all devices are migrated. Rename it last.

### Step 8 — Migrate devices VLAN by VLAN (least critical first)

| Order | VLAN | First devices to move |
|-------|------|-----------------------|
| 1 | `personal` (40) | Phones, tablets — easy to fix if something breaks |
| 2 | `iot-homekit` (20) | HomePods first (they're the HomeKit hub — move hub before accessories), then cameras, then Eve, then Ecobee |
| 3 | `iot-untrusted` (30) | Emporia Vue, Sensibo, LG WashTower, Moen Flo, TVs |
| 4 | `work` (10) | W&L server last — highest stakes, ensure everything else is stable first |

For wired devices: re-patch to VLAN-tagged switch port or directly to Firewalla LAN port for that VLAN.

### Step 9 — Verify HomeKit across VLANs
See §7 HomeKit Compatibility Test Plan. Must pass before declaring Step 8 complete.

### Step 10 — Apply inter-VLAN firewall rules and egress allowlists
- Block all inter-VLAN traffic by default.
- Add specific allow rules per §3.1 (VPS→on-prem ports, personal→iot-homekit HomeKit discovery ports).
- Apply egress allowlists to `iot-untrusted` VLAN (Emporia cloud, LG servers, Moen cloud, Sensibo cloud, Samsung / Sony update endpoints).
- Enable Firewalla DNS filtering per VLAN.
- Enable IDS (intrusion detection).

### Step 11 — Lock down and document
- Enable Firewalla flow logging.
- Document final IP assignments for all static/reserved devices.
- Update `docs/compliance/PHYSICAL_SECURITY.md` §3 — mark trust zone model as "implemented."
- Update `docs/OPEN_ISSUES.md` to close the network segmentation items.
- Retire the old flat SSID.

---

## 7. HomeKit Compatibility Test Plan

HomeKit requires mDNS for local device discovery. VLANs break mDNS by default; Firewalla's mDNS reflector bridges discovery across VLANs.

| Test | Expected result | Fail action |
|------|----------------|-------------|
| Home app on iPhone (`personal` VLAN) sees all accessories | ✅ All accessories listed in Home app | Check Firewalla mDNS reflection config — ensure `personal` and `iot-homekit` VLANs are included |
| Aqara cameras record clips to iCloud (HKSV) | ✅ Clips appear in Home app after motion events | Check that cameras have internet egress on `iot-homekit` VLAN (Apple APN + Aqara cloud if enabled) |
| HomePod(s) show as active HomeKit hub | ✅ HomePod listed as "Connected" in Home app | HomePod must be on `iot-homekit` VLAN; Home app device on `personal` — mDNS reflector must bridge these |
| Eve accessories reachable from Home app | ✅ Eve devices respond to commands | Eve uses Thread over HomePod — confirm HomePod can see Eve devices on same VLAN |
| Ecobee thermostat reachable from Home app | ✅ Ecobee controls work from Home app | Ecobee must be on `iot-homekit` VLAN with Ecobee cloud egress allowed |
| Home automations fire correctly | ✅ Location-based, time-based, sensor-triggered automations work | Automation failures often indicate a hub connectivity issue — check HomePod status first |

---

## 8. Rollback and Known Risks

| Risk | Mitigation | Rollback |
|------|-----------|---------|
| HomeKit breaks after VLAN migration | Execute §7 test plan at each step; move HomePod (hub) to `iot-homekit` VLAN first | Move all HomeKit devices back to flat SSID; remove VLAN rules; re-test |
| VLAN misconfiguration locks out management access | Keep a device on the native/untagged VLAN until Firewalla is confirmed reachable | Factory reset Firewalla (last resort); Eero reverts to its own DHCP when Firewalla is removed |
| AT&T gateway double-NAT resurfaces | Test Tailscale connectivity after Step 3; Tailscale is NAT-traversal-aware and tolerates double-NAT | No action needed for Tailscale; port forwarding would need adjustment if required |
| Eero bridge mode drops | Eero may revert to NAT mode on reboot in some firmware versions | Check Eero app after every reboot; re-enable bridge mode if reverted |
| EPA device loses connectivity | Test EPA device on `work` VLAN before completing migration; keep old SSID available | Move EPA device back to `personal` VLAN temporarily |

---

## 9. Open Questions (Jeremy to answer before starting)

| # | Question | Why it matters |
|---|----------|---------------|
| 1 | Is AT&T gateway currently in IP Passthrough / bridge mode? | Determines whether Firewalla gets the public IP directly or needs to handle double-NAT |
| 2 | Which firewall model: Firewalla Gold Pro (~$900), Gold SE (~$450), or UniFi Dream Machine Pro Max (~$600)? | **Decide before ordering.** AT&T is confirmed at 5 Gbps; Gold SE caps WAN at 2.5 Gbps; Gold Pro and UDM Pro Max preserve full line rate. See §4.1 comparison and recommendation. |
| 3 | Is the current switch managed or unmanaged? PoE or non-PoE? | Determines whether VLAN tagging on wired ports requires a switch replacement |
| 4 | Are the Aqara PoE cameras powered by a PoE injector or PoE switch? | Affects whether a managed PoE switch is needed as part of procurement |
| 5 | Which room is each camera currently in / what is its physical placement? | Required to complete the camera inventory table in PHYSICAL_SECURITY.md §4.1 |
| 6 | Where is Ecobee mounted? Does your Ecobee model have an Alexa mic? | Mic-enabled Ecobee (Ecobee SmartThermostat with Voice Control) has always-listening considerations |
| 7 | Where are the HomePods currently located? Are any in the office? | Confirms physical relocation from PHYSICAL_SECURITY.md §4.2 is complete |
| 8 | Homebridge — do you want to set it up, and if so, on what hardware? | Homebridge host must be a dedicated device on `iot-homekit` VLAN, not the W&L server |
| 9 | What is the intended home SSID naming scheme? | Affects Step 7 SSID setup |

---

## 10. Related Documents

| Document | Relationship |
|----------|-------------|
| `docs/compliance/PHYSICAL_SECURITY.md` | Trust zone model this plan implements; camera and device inventory |
| `docs/NEXT_STEPS.md` | Execution sequencing — network rewrite is deferred until after Keycloak Phase A |
| `docs/PROJECT_PLAN.md` | Decision log entry for Path 2 selection |
| `docs/OPEN_ISSUES.md` | Open pre-reqs and action items tracked separately |
