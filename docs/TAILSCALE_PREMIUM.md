# Tailscale Premium — Features & Operations

**Organization:** Wilkes & Liberty  
**Maintained by:** Jeremy (`3@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23  
**Account tier:** Premium (activated 2026-04-23)

---

## What's Enabled on Premium

The following features are now available that were not on the free tier:

| Feature | What it gives us | How we use it |
|---------|-----------------|---------------|
| **Tag-based ACLs** | Per-device access control by device type/role | Least-privilege network segmentation — see [TAILSCALE_ACL_DESIGN.md](TAILSCALE_ACL_DESIGN.md) |
| **Tailscale SSH** | Browser and CLI SSH without static keys; session logs | Replace static SSH keys for on-prem + VPS access; enable session recording |
| **Network flow logs** | Per-connection log of source/dest/port/bytes | Export to a SIEM or log aggregator for audit trail |
| **Config audit log** | Log of admin console changes (ACL edits, device changes) | Evidence for NIST 800-171 AU-3 (content of audit records) |
| **Device posture** | Tag devices with OS/patch version checks | Future: enforce that `tag:admin` devices have disk encryption enabled |
| **Custom DERP** | Self-hosted relay for latency optimization | Not needed now; option if connectivity degrades |
| **Priority support** | 24h response from Tailscale support | Use for any tailnet incident |

---

## How to Use Tag-Based ACLs

### Overview

Tag-based ACLs replace the default "all devices can reach all devices" policy. With ACLs:
- Each device is assigned one or more tags at enrollment
- ACL rules define what tags can reach what other tags on what ports
- No rule = no access (default-deny once ACLs are applied)

### Step 1 — Assign tags to devices

In the [Tailscale admin console](https://login.tailscale.com/admin/machines):

1. Click on each device.
2. Under **Machine tags**, add the appropriate tag(s):
   - On-prem server → `tag:onprem-server`
   - Njalla VPS → `tag:vps`
   - Your operator laptop → `tag:admin`

### Step 2 — Review the ACL design

Read [TAILSCALE_ACL_DESIGN.md](TAILSCALE_ACL_DESIGN.md) carefully. The HuJSON in that doc is the intended policy. Do not paste it until you've verified the device inventory and port numbers.

### Step 3 — Apply ACLs

1. Go to admin console → **Access Controls**.
2. Replace the default policy with the HuJSON from TAILSCALE_ACL_DESIGN.md.
3. Click **Save** — Tailscale validates the JSON before applying.
4. Run the built-in tests: the `"tests"` block in the JSON is evaluated on save; any failures block the apply.
5. Verify connectivity from each device type (see sign-off checklist in TAILSCALE_ACL_DESIGN.md).

### Step 4 — Verify

```bash
# From on-prem server: can we reach the VPS?
tailscale ping <vps-tailscale-ip>

# From operator laptop (tag:admin): can we reach on-prem Drupal?
curl -o /dev/null -sw "%{http_code}" http://<onprem-tailscale-ip>:8080/

# From VPS: can we reach on-prem Drupal? (Expected: 200/302)
curl -o /dev/null -sw "%{http_code}" http://<onprem-tailscale-ip>:8080/

# From VPS: can we reach on-prem DB? (Expected: connection refused)
nc -zv <onprem-tailscale-ip> 5432
```

---

## Tailscale SSH Setup

Tailscale SSH replaces traditional SSH keys for device access. Sessions can be logged and recorded.

### Enable on on-prem server

```bash
# Enable Tailscale SSH on the on-prem macOS server
tailscale set --ssh

# Verify SSH is enabled
tailscale status | grep -i ssh
```

### Enable on VPS (Debian)

The `tailscale` Ansible role already runs `tailscale up`. To enable SSH:

```bash
# On the VPS
tailscale set --ssh

# Or in the Ansible tailscale role, add to the tailscale up flags:
# --ssh
```

Update `ansible/roles/tailscale/tasks/main.yml` to add `--ssh` to the `tailscale up` command, so it persists across deployments.

### SSH Session Recording

Tailscale SSH can record sessions for audit purposes. Recordings are stored in Tailscale's cloud and accessible from the admin console.

To enable per-device recording, add a `"recorder"` block to the ACL SSH rules:

```hujson
"ssh": [
  {
    "action":   "accept",
    "src":      ["tag:admin"],
    "dst":      ["tag:onprem-server", "tag:vps"],
    "users":    ["autogroup:nonroot", "root"],
    "recorder": ["tag:admin"],  // Records sessions where src=admin
    "enforceRecorder": false    // true = deny SSH if recorder is unavailable
  }
]
```

> Set `enforceRecorder: false` until session recording is confirmed working, then switch to `true` for compliance.

### Connect via Tailscale SSH

```bash
# From admin device (after tailscale login)
ssh <hostname>           # Uses tailscale SSH; no key required
ssh jeremy@<onprem-ip>   # Explicit user
```

The Tailscale admin console → **Machines** → click device → **SSH** shows active sessions.

---

## Network Flow Logs

Network flow logs record every accepted/denied connection: source IP, destination IP, port, bytes transferred, and action. Useful for detecting lateral movement or unexpected connections.

### Configure log destination

Tailscale can stream flow logs to:
- An S3-compatible bucket (Proton Drive is not S3-compatible; use a local path or an S3-compatible service)
- A syslog endpoint
- HTTPS webhook

For a minimal setup that fits our stack, stream logs to a local file on the on-prem server via the Tailscale API (see [Tailscale docs: network flow logs](https://tailscale.com/kb/1255/network-flow-logs)):

```bash
# Enable flow logging via the Tailscale admin API (requires API key)
# This is a one-time admin operation; not yet automated
curl -s -X POST "https://api.tailscale.com/api/v2/tailnet/-/network-logs/enable" \
  -u "${TAILSCALE_API_KEY}:" \
  -H "Content-Type: application/json"
```

Once enabled, logs are accessible in the admin console → **Network logs** tab, and can be exported via the API.

### TODO

- [ ] Decide on a log destination (local file → logrotate, or external aggregator)
- [ ] Configure retention policy (NIST 800-171 §3.3.1 requires ≥90 days)
- [ ] Add network log export to the quarterly security review checklist

---

## Config Audit Log

The Tailscale admin console logs every change to the tailnet configuration (ACL edits, device enrollments, key rotations). This satisfies NIST 800-171 §3.3.1 (audit logging) for the Tailscale control plane.

**Access:** admin console → **Logs** tab.

**Export:** Available via the Tailscale API for integration into a SIEM or long-term storage.

---

## Ansible Role Updates Needed

To persist Tailscale Premium configuration across `make vps` deployments:

**`ansible/roles/tailscale/tasks/main.yml`** — add `--ssh` flag to the `tailscale up` command:

```yaml
# Before:
tailscale up --authkey "{{ tailscale_auth_key }}" --hostname "{{ inventory_hostname }}"

# After:
tailscale up --authkey "{{ tailscale_auth_key }}" --hostname "{{ inventory_hostname }}" --ssh
```

**`ansible/roles/common/tasks/main.yml`** (if it exists, for on-prem) — same `--ssh` flag addition.

---

## Key Expiry Policy

Recommended key expiry per tag (configure in admin console → **DNS** → **Key expiry**):

| Tag | Expiry |
|-----|--------|
| `tag:admin` | 90 days (re-authenticate quarterly) |
| `tag:dev` | 30 days |
| `tag:vps` | 180 days (VPS key; use a service key with longer TTL) |
| `tag:onprem-server` | 180 days |

---

## Tailscale Premium Activation Checklist

- [x] Upgraded to Premium tier (2026-04-23)
- [ ] Tags assigned to all enrolled devices
- [ ] ACL design reviewed and signed off (see TAILSCALE_ACL_DESIGN.md)
- [ ] ACLs applied to tailnet
- [ ] Tailscale SSH enabled on on-prem server
- [ ] Tailscale SSH enabled on VPS (via Ansible role update)
- [ ] SSH session recording configured
- [ ] Network flow logging enabled with retention ≥ 90 days
- [ ] Key expiry policy configured per tag
- [ ] SECURITY_CHECKLIST.md evidence updated
- [ ] SSP.md updated to reference Tailscale Premium controls (AC-3, AC-4, AC-6, AU-2, AU-3, AU-12, IA-2)
