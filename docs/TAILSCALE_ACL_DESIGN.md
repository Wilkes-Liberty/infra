# Tailscale ACL Design

**Organization:** Wilkes & Liberty  
**Maintained by:** Jeremy (`jmcerda@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23  
**Status:** Design — requires sign-off before applying to the tailnet

---

## Overview

This document defines the tag taxonomy and ACL rules for Wilkes & Liberty's Tailscale tailnet. ACLs implement least-privilege access: each device and user class can only reach the services it requires.

Tailscale tag-based ACLs are a Premium feature. The design below assumes Tailscale Premium is active. See [TAILSCALE_PREMIUM.md](TAILSCALE_PREMIUM.md) for Premium feature details and activation checklist.

**Before applying these ACLs to the tailnet**, review this document and confirm the rules reflect the current device inventory. Apply via the Tailscale admin console → Access Controls, or commit the JSON to the tailnet's policy file and push via the Tailscale API.

---

## Tag Taxonomy

### User Tags
Assigned to operator and developer devices. One tag per person; determined by role.

| Tag | Who | What it grants |
|-----|-----|---------------|
| `tag:admin` | Jeremy (Owner/Admin) | Full access to all on-prem services, VPS SSH, monitoring, staging |
| `tag:business-continuity` | Aleksandra Cerda (spouse / continuity contact) | Broad read + SSH access to all on-prem services and VPS; no production deploy or SOPS key. Reserved for the owner's designated continuity contact. Not for routine use — logins are audited. |
| `tag:dev` | Developers (future hires) | Staging services only; no production DB or secrets |
| `tag:contractor` | Contractors (scoped work) | Specific repos via GitHub only; no tailnet access unless explicitly provisioned |
| `tag:readonly` | Auditors / stakeholders | Read-only access to monitoring dashboards (Grafana, Uptime Kuma) |

> **`tag:business-continuity` policy:** This tag exists solely for the owner's designated emergency contact (currently Aleksandra Cerda). It grants broad read/SSH access because business-continuity scenarios require reaching into the network from anywhere in the world without knowing in advance which service needs attention. Tailscale connections are global by default — no special routing or exit node is required. Logins from this tag generate audit log entries in Tailscale and should be reviewed whenever the account is activated. The tag is not used for routine work; if it appears in flow logs outside an acknowledged emergency, treat it as an anomaly.

### Service / Device Tags
Assigned to infrastructure nodes. A device gets its service tag at enrollment.

| Tag | Device | Role |
|-----|--------|------|
| `tag:onprem-server` | On-prem macOS server | Hosts all Docker services; primary data plane |
| `tag:vps` | Njalla VPS | Caddy reverse proxy + Next.js UI |
| `tag:prod-drupal` | wl_drupal container (via host) | Drupal :8080 |
| `tag:prod-keycloak` | wl_keycloak container (via host) | Keycloak :8081 |
| `tag:prod-db` | wl_postgres container (via host) | PostgreSQL :5432 (admin access only) |
| `tag:prod-monitoring` | Grafana/Prometheus/Alertmanager | Monitoring stack |
| `tag:stg-drupal` | wl_stg_drupal (via host) | Staging Drupal :8090 |
| `tag:stg-keycloak` | wl_stg_keycloak (via host) | Staging Keycloak :8091 |
| `tag:user-device` | Any enrolled personal device | User's own device; access controlled by user tag |

> **Note:** Container-level tags are conceptual — Tailscale is installed on the macOS host, not inside containers. ACL rules use the host's tags and port-level restrictions to represent container-level segmentation.

---

## ACL Rules

The policy below is expressed in HuJSON (Tailscale's ACL format). This is the intended final state, not the current state.

```hujson
{
  // ============================================================
  // Tag owners
  // Only tag owners can assign a tag to a device.
  // ============================================================
  "tagOwners": {
    "tag:admin":                ["autogroup:owner"],
    "tag:business-continuity":  ["autogroup:owner"],
    "tag:dev":                  ["autogroup:owner"],
    "tag:contractor":           ["autogroup:owner"],
    "tag:readonly":             ["autogroup:owner"],
    "tag:onprem-server": ["autogroup:owner"],
    "tag:vps":           ["autogroup:owner"],
    "tag:prod-drupal":   ["autogroup:owner"],
    "tag:prod-keycloak": ["autogroup:owner"],
    "tag:prod-db":       ["autogroup:owner"],
    "tag:prod-monitoring":["autogroup:owner"],
    "tag:stg-drupal":    ["autogroup:owner"],
    "tag:stg-keycloak":  ["autogroup:owner"],
    "tag:user-device":   ["autogroup:owner"]
  },

  // ============================================================
  // ACL rules — evaluated top-to-bottom; first match wins
  // ============================================================
  "acls": [

    // ── Admin: full access to everything ──────────────────────
    {
      "action": "accept",
      "src":    ["tag:admin"],
      "dst":    ["*:*"]
    },

    // ── Business continuity: broad read + SSH, no deploy ─────
    // Reserved for spouse / designated continuity contact (acerda).
    // Grants same service reach as admin but no production deploy
    // capability (enforced at the application layer — Keycloak role
    // grants nothing active; SOPS key not provisioned).
    {
      "action": "accept",
      "src":    ["tag:business-continuity"],
      "dst":    ["tag:onprem-server:*", "tag:vps:*"]
    },

    // ── VPS → on-prem: reverse proxy traffic ──────────────────
    // Caddy on the VPS proxies to Drupal and Keycloak on-prem.
    {
      "action": "accept",
      "src":    ["tag:vps"],
      "dst":    ["tag:onprem-server:8080"]  // Drupal
    },
    {
      "action": "accept",
      "src":    ["tag:vps"],
      "dst":    ["tag:onprem-server:8081"]  // Keycloak
    },

    // ── Developers: staging services only ─────────────────────
    {
      "action": "accept",
      "src":    ["tag:dev"],
      "dst":    ["tag:onprem-server:8090"]  // Staging Drupal
    },
    {
      "action": "accept",
      "src":    ["tag:dev"],
      "dst":    ["tag:onprem-server:8091"]  // Staging Keycloak
    },
    {
      "action": "accept",
      "src":    ["tag:dev"],
      "dst":    ["tag:onprem-server:8993"]  // Staging Solr
    },
    {
      "action": "accept",
      "src":    ["tag:dev"],
      "dst":    ["tag:onprem-server:3010"]  // Staging Next.js
    },
    // Dev → Grafana (monitoring dashboards — read-only in Grafana RBAC)
    {
      "action": "accept",
      "src":    ["tag:dev"],
      "dst":    ["tag:onprem-server:3001"]
    },

    // ── Readonly: monitoring dashboards only ──────────────────
    {
      "action": "accept",
      "src":    ["tag:readonly"],
      "dst":    ["tag:onprem-server:3001"]  // Grafana
    },
    {
      "action": "accept",
      "src":    ["tag:readonly"],
      "dst":    ["tag:onprem-server:3002"]  // Uptime Kuma
    },

    // ── On-prem server → internet (egress) ────────────────────
    // Needed for Let's Encrypt ACME, Docker pull, Postmark SMTP.
    // Tailscale doesn't restrict egress by default; this is a
    // reminder that egress is intentionally unrestricted.
    {
      "action": "accept",
      "src":    ["tag:onprem-server"],
      "dst":    ["autogroup:internet:*"]
    },

    // ── VPS → internet (egress) ───────────────────────────────
    {
      "action": "accept",
      "src":    ["tag:vps"],
      "dst":    ["autogroup:internet:*"]
    }

    // ── Contractor: no tailnet access ─────────────────────────
    // tag:contractor devices are enrolled but granted no routes.
    // Access is solely via GitHub (managed outside Tailscale).

  ],

  // ============================================================
  // SSH rules (Tailscale SSH — requires SSH enabled on device)
  // ============================================================
  "ssh": [
    // Admin can SSH to any device
    {
      "action":      "accept",
      "src":         ["tag:admin"],
      "dst":         ["tag:onprem-server", "tag:vps"],
      "users":       ["autogroup:nonroot", "root"]
    },
    // Business continuity: SSH to on-prem and VPS for emergency reach
    {
      "action":      "accept",
      "src":         ["tag:business-continuity"],
      "dst":         ["tag:onprem-server", "tag:vps"],
      "users":       ["autogroup:nonroot", "root"],
      "checkPeriod": "1h"  // Re-check authorization every hour during emergency use
    },
    // Dev can SSH to VPS only (for Next.js troubleshooting)
    {
      "action":      "accept",
      "src":         ["tag:dev"],
      "dst":         ["tag:vps"],
      "users":       ["autogroup:nonroot"],
      "checkPeriod": "8h"  // Re-check authorization every 8h
    }
  ],

  // ============================================================
  // Tests — verify the ACL behaves as intended
  // Run: tailscale acl test (requires tailscale CLI v1.44+)
  // ============================================================
  "tests": [
    // Admin can reach production Drupal
    {
      "src":    "tag:admin",
      "accept": ["tag:onprem-server:8080"]
    },
    // Dev cannot reach production Drupal
    {
      "src":    "tag:dev",
      "deny":   ["tag:onprem-server:8080"]
    },
    // Dev can reach staging Drupal
    {
      "src":    "tag:dev",
      "accept": ["tag:onprem-server:8090"]
    },
    // Readonly can reach Grafana but not production services
    {
      "src":    "tag:readonly",
      "accept": ["tag:onprem-server:3001"],
      "deny":   ["tag:onprem-server:8080", "tag:onprem-server:8081"]
    },
    // VPS can reach Drupal and Keycloak
    {
      "src":    "tag:vps",
      "accept": ["tag:onprem-server:8080", "tag:onprem-server:8081"]
    },
    // VPS cannot reach the database port directly
    {
      "src":    "tag:vps",
      "deny":   ["tag:onprem-server:5432"]
    },
    // Business continuity can reach on-prem services
    {
      "src":    "tag:business-continuity",
      "accept": ["tag:onprem-server:8080", "tag:onprem-server:8081", "tag:onprem-server:3001"]
    }
  ]
}
```

---

## Current vs Target State

| State | Description |
|-------|-------------|
| **Current** | No tag-based ACLs. Default Tailscale policy: all enrolled devices can reach all other enrolled devices on all ports. |
| **Target** | The HuJSON above. Least-privilege: each role can only reach the ports it needs. |

**Migration steps (do not apply until signed off):**

1. Enroll all devices in the tailnet (currently: on-prem server, VPS, operator laptop; Aleksandra's device when Phase D is executed).
2. Assign tags to all enrolled devices in the Tailscale admin console.
3. Verify device inventory matches tag assignments — check [ACCESS_CONTROL.md](compliance/ACCESS_CONTROL.md) §2.
4. Apply the ACL JSON to the tailnet (admin console → Access Controls → paste JSON → Save).
5. Run `tailscale acl test` from the CLI to confirm the built-in tests pass.
6. Verify: from the VPS, `curl http://<onprem-tailscale-ip>:8080/` should succeed; `curl http://<onprem-tailscale-ip>:5432/` should fail.
7. Verify: from a `tag:business-continuity` device, confirm on-prem services are reachable; review Tailscale audit log to confirm login events are captured.
8. Verify: from a dev-tagged device (once hired), confirm staging access works and production is blocked.

---

## Known Gaps / TODOs

- **No devices tagged yet** — tags must be assigned in the admin console before ACLs take effect.
- **Exit node** — if an exit node is provisioned in the future, add explicit rules for which devices can use it.
- **Key expiry** — configure key expiry enforcement per tag: `admin` devices 90-day expiry; `dev` devices 30-day.
- **Node sharing** — if a vendor or auditor needs temporary tailnet access, use Tailscale node sharing (not a new `tag:contractor` enrollment) to limit exposure.
- **Network flow logs** — configure Tailscale network flow log destination once the ACLs are stable (see TAILSCALE_PREMIUM.md).

---

## Sign-off

Before applying these ACLs:

- [ ] Device inventory confirmed (all enrolled devices and their intended tags listed above)
- [ ] VPS → on-prem proxy ports verified to be correct (8080, 8081)
- [ ] Staging port numbers confirmed (8090, 8091, 8993, 3010)
- [ ] ACL JSON reviewed line-by-line by the Owner
- [ ] Test assertions verified in a staging tailnet or with `tailscale acl test` first

**Owner sign-off:** Jeremy — _______ (date)
