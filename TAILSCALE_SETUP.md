# Tailscale Setup Guide

Tailscale provides the secure mesh VPN connecting the on-prem server and the Njalla VPS. It also serves as the access control layer for all internal (`*.int.wilkesliberty.com`) services via Split DNS.

## Architecture: Three-Layer Internal Access Control

Internal services are protected by three independent layers, all requiring Tailscale:

```
1. Tailscale Split DNS
   └─ *.int.wilkesliberty.com resolves ONLY when on Tailscale
      (non-Tailscale devices get NXDOMAIN)

2. CoreDNS (on on-prem server)
   └─ Binds on Tailscale IP only (100.x.x.x)
      (not reachable from public internet)

3. Internal Caddy (on on-prem server)
   └─ Binds on Tailscale IP only (100.x.x.x)
      (not reachable from public internet)
```

A client must be on the Tailscale network to resolve `*.int.wilkesliberty.com`, reach CoreDNS, and reach Caddy. Any single layer is sufficient to block external access; all three are active.

## Two-Host Mesh

| Host | Role | Tailscale function |
|------|------|--------------------|
| On-prem server | Backend services, CoreDNS, monitoring | Subnet router (advertises `10.10.0.0/24`), Split DNS nameserver |
| Njalla VPS | Public ingress, Next.js, Caddy (public) | Client; proxies `api`, `auth`, `search` to on-prem via Tailscale IP |

---

## Prerequisites

1. Tailscale account at https://tailscale.com
2. SOPS + AGE configured (`SOPS_AGE_KEY_FILE` set) — see `SECRETS_MANAGEMENT.md`

---

## Setup: On-prem Server

### Step 1: Generate a Tailscale Auth Key

1. Go to https://login.tailscale.com/admin/settings/keys
2. Click **Generate auth key**
3. Settings:
   - ✅ **Reusable** — so you can use for multiple hosts
   - ✅ **Preauthorized** — auto-approve without manual confirmation
   - ❌ **Ephemeral** — disable (keep nodes permanently)
   - **Expiration** — 90 days or longer
   - **Tags** — `tag:prod`, `tag:infra`
4. Copy the key (starts with `tskey-auth-`)

### Step 2: Store Auth Key in SOPS

```bash
cd ~/Repositories/infra

# Edit or create the encrypted secrets file
sops ansible/inventory/group_vars/tailscale_secrets.yml
```

Set the value:
```yaml
---
tailscale_auth_key: "tskey-auth-YOUR_ACTUAL_KEY_HERE"
```

Save and exit — SOPS encrypts automatically.

### Step 3: Install and Connect (On-prem server)

```bash
# Install via Homebrew (macOS)
brew install tailscale

# Start daemon
sudo tailscaled &

# Authenticate; advertise internal subnet for VPS access
sudo tailscale up \
  --authkey=<your_auth_key> \
  --advertise-routes=10.10.0.0/24 \
  --hostname=wilkesliberty-onprem

# Note the assigned Tailscale IP
tailscale ip -4
```

### Step 4: Approve Subnet Route in Admin Console

1. Go to https://login.tailscale.com (or `network.wilkesliberty.com` after DNS is live)
2. Find the `wilkesliberty-onprem` machine
3. Under **Subnet routes**, approve `10.10.0.0/24`
4. This allows the VPS to reach all on-prem Docker services directly

---

## Setup: Njalla VPS

```bash
# Install Tailscale (Linux)
curl -fsSL https://tailscale.com/install.sh | sh

# Connect
sudo tailscale up \
  --authkey=<your_auth_key> \
  --hostname=wilkesliberty-vps

# Note the assigned Tailscale IP
tailscale ip -4
```

---

## Configure Tailscale Split DNS

This is what makes `*.int.wilkesliberty.com` resolve only for Tailscale clients.

1. Go to https://login.tailscale.com/admin/dns
2. Under **Nameservers**, add a **Custom nameserver**:
   - **Domain**: `int.wilkesliberty.com`
   - **Nameserver IP**: `<on-prem Tailscale IP>` (the 100.x.x.x address)
3. Save

Now any Tailscale-connected device that queries `*.int.wilkesliberty.com` will be directed to CoreDNS on the on-prem server. Devices not on Tailscale cannot resolve these names.

---

## Verification

### Tailscale Mesh Connectivity

```bash
# From VPS — can we reach on-prem?
ping -c 3 <on-prem-tailscale-ip>

# From on-prem — can we reach VPS?
ping -c 3 <vps-tailscale-ip>
```

### Split DNS Resolution (from a Tailscale-connected device)

```bash
# Should resolve to 10.10.0.7 (on-prem LAN IP)
dig monitor.int.wilkesliberty.com
nslookup monitor.int.wilkesliberty.com

# Should NOT resolve from a non-Tailscale device:
# NXDOMAIN expected
```

### Internal Service Reachability (from Tailscale device)

```bash
# Grafana dashboard
curl -I https://monitor.int.wilkesliberty.com

# Drupal internal
curl -I https://app.int.wilkesliberty.com
```

### VPS → On-prem Proxy (verifies Tailscale routing)

```bash
# From VPS, reach Drupal directly via on-prem Tailscale IP
curl -I http://<on-prem-tailscale-ip>:8080
# Expected: Drupal response (Caddy VPS proxies this to users as api.wilkesliberty.com)
```

---

## CoreDNS Configuration

CoreDNS is deployed by the `wl-onprem` Ansible role. It serves `int.wilkesliberty.com` and binds **only on the Tailscale IP**:

```
coredns/
├── Corefile               # Server config — bind on Tailscale IP
└── zones/
    └── int.wilkesliberty.com.zone   # Zone file — all internal records
```

When modifying the zone file, increment the serial in `YYYYMMDDNN` format, then redeploy:

```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml
```

---

## Key Management

### Rotate Auth Key

1. Generate a new key in https://login.tailscale.com/admin/settings/keys
2. Update secrets: `sops ansible/inventory/group_vars/tailscale_secrets.yml`
3. Redeploy: `ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml --tags tailscale`
4. Revoke the old key in the Tailscale admin console

### Add a New Admin Device

Simply install Tailscale on the device, authenticate with your account, and it will automatically have access to `*.int.wilkesliberty.com` via Split DNS.

---

## Access Control Lists (ACLs)

In the Tailscale admin → **Access Controls**, restrict which nodes can communicate:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:prod"],
      "dst": ["tag:prod:*"]
    },
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["tag:prod:*"]
    }
  ],
  "tagOwners": {
    "tag:prod":  ["autogroup:admin"],
    "tag:infra": ["autogroup:admin"]
  }
}
```

---

## Troubleshooting

### Internal Names Not Resolving

```bash
# Check Tailscale is connected
tailscale status

# Check Split DNS is configured (Tailscale admin → DNS)
# Query CoreDNS directly by IP
dig @<on-prem-tailscale-ip> app.int.wilkesliberty.com

# Check CoreDNS is running
docker exec wl_coredns dig @127.0.0.1 app.int.wilkesliberty.com
```

### VPS Can't Reach On-prem Services

```bash
# Check Tailscale peers are connected
tailscale status

# Check subnet routes are approved in admin console
# Ping on-prem Tailscale IP from VPS
ping <on-prem-tailscale-ip>

# Try reaching on-prem Drupal directly
curl http://<on-prem-tailscale-ip>:8080
```

### Manually Reconnect a Host

```bash
sudo tailscale down
sudo tailscale up --authkey=tskey-auth-YOUR_KEY
```

### Network Diagnostics

```bash
sudo tailscale netcheck
sudo tailscale ping <peer-ip>
```

---

## Security Notes

- CoreDNS binds on Tailscale IP only — not reachable from the public internet
- Internal Caddy binds on Tailscale IP only — not reachable from the public internet
- Tailscale Split DNS ensures `*.int.wilkesliberty.com` cannot be resolved externally
- Enable MFA on your Tailscale account
- Rotate auth keys quarterly
- Use tags (`tag:prod`, `tag:infra`) and ACLs to restrict inter-host access

---

## Additional Resources

- **Tailscale Documentation**: https://tailscale.com/kb/
- **Subnet Routing**: https://tailscale.com/kb/1019/subnets/
- **Split DNS**: https://tailscale.com/kb/1054/dns/
- **ACLs**: https://tailscale.com/kb/1018/acls/
- `ansible/roles/tailscale/README.md` — Ansible role documentation
- `DNS_RECORDS.md` — Internal and public DNS record reference
