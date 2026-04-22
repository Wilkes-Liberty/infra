# DNS Records Configuration

This document describes the DNS configuration for Wilkes Liberty — public records managed via Terraform, and internal records served by CoreDNS over Tailscale.

> **Variable notation**: Values shown as `{{ variable_name }}` are SOPS-encrypted in `ansible/inventory/group_vars/network_secrets.yml`. Decrypt with `sops -d ansible/inventory/group_vars/network_secrets.yml` to see actual values.

## Architecture Overview

```
Internet → wilkesliberty.com (public DNS)
               ↓
           Cloud VPS  ←── Tailscale mesh ──→  On-prem server
           (Caddy, Next.js)                    (Docker Compose)

Internal clients (Tailscale) → *.int.wilkesliberty.com (CoreDNS on on-prem)
```

All public records point to the **cloud VPS** IP. The VPS Caddy instance either serves traffic locally (Next.js) or reverse-proxies to the on-prem server over the Tailscale mesh (Drupal, Keycloak, Solr).

Internal `*.int.wilkesliberty.com` names are only resolvable on the Tailscale network via Tailscale Split DNS → CoreDNS on the on-prem server.

---

## Public DNS Records (Terraform-managed)

Source of truth: `records.tf`

### Apex

| Name | Type | Value | Notes |
|------|------|-------|-------|
| `wilkesliberty.com` | A | `{{ cloud_vps_ip }}` | Apex → VPS |
| `wilkesliberty.com` | AAAA | `{{ vps_ipv6 }}` | Optional; enabled when `vps_ipv6` variable is set |

### Services

| Subdomain | Type | Value | Purpose |
|-----------|------|-------|---------|
| `www` | A / AAAA | VPS IP | Next.js frontend |
| `api` | A / AAAA | VPS IP | Drupal CMS / GraphQL API (webcms repo, on-prem via Tailscale) |
| `auth` | A / AAAA | VPS IP | Keycloak SSO (on-prem via Tailscale) |
| `search` | A / AAAA | VPS IP | Solr search (on-prem via Tailscale; admin-CIDR restricted) |
| `network` | A / AAAA | VPS IP | VPN admin — Caddy on VPS redirects to `login.tailscale.com` |

> **Note**: `api`, `auth`, and `search` all resolve to the VPS IP. Caddy on the VPS proxies those requests over Tailscale to the on-prem server. The VPS is the single public ingress point.

### Mail (Proton Mail)

Managed in `mail_proton.tf`. Includes MX, SPF TXT, DKIM TXT, and DMARC TXT records. Do not edit manually — these are managed by Terraform.

### CAA Records (Manual — DNS provider web UI only)

The Terraform provider does not support CAA records. Add these manually in the DNS provider web interface:

| Name | Tag | Value |
|------|-----|-------|
| `wilkesliberty.com` | `issue` | `"letsencrypt.org"` |
| `wilkesliberty.com` | `issuewild` | `"letsencrypt.org"` |
| `wilkesliberty.com` | `iodef` | `"mailto:security@wilkesliberty.com"` |

Verify after adding:
```bash
dig CAA wilkesliberty.com
```

Monitor for unauthorized certificate issuance: https://crt.sh/?q=wilkesliberty.com

---

## Internal DNS Records (CoreDNS, Tailscale-only)

Source of truth: `coredns/zones/int.wilkesliberty.com.zone`

Internal names resolve only on the Tailscale network. Tailscale Split DNS routes `*.int.wilkesliberty.com` queries to CoreDNS (running on the on-prem server at its Tailscale IP). CoreDNS binds only on the Tailscale interface, and Caddy internal binds only on the Tailscale IP — three layers of Tailscale-only enforcement.

### DNS Server

| Name | Type | Value |
|------|------|-------|
| `ns.int.wilkesliberty.com` | A | `{{ coredns_ts_ip }}` |

### Application Services (on-prem server)

These names resolve to the on-prem server's LAN IP. Internal Caddy (`Caddyfile.internal.j2`) handles TLS termination and routing.

| Name | Type | Value | Public equivalent |
|------|------|-------|-------------------|
| `api.int.wilkesliberty.com` | A | `{{ onprem_int_ip }}` | `api.wilkesliberty.com` (Drupal/webcms) |
| `auth.int.wilkesliberty.com` | A | `{{ onprem_int_ip }}` | `auth.wilkesliberty.com` (Keycloak) |

### Data & Search Services (direct access, no Caddy)

| Name | Type | Value | Service |
|------|------|-------|---------|
| `db.int.wilkesliberty.com` | A | `{{ onprem_int_ip }}` | PostgreSQL |
| `search.int.wilkesliberty.com` | A | `{{ onprem_int_ip }}` | Solr (internal) |
| `cache.int.wilkesliberty.com` | A | `{{ onprem_int_ip }}` | Redis |

### Monitoring & Observability (via internal Caddy)

| Name | Type | Value | Service |
|------|------|-------|---------|
| `monitor.int.wilkesliberty.com` | A | `{{ onprem_int_ip }}` | Grafana dashboards |
| `metrics.int.wilkesliberty.com` | A | `{{ onprem_int_ip }}` | Prometheus metrics |
| `alerts.int.wilkesliberty.com` | A | `{{ onprem_int_ip }}` | Alertmanager |
| `uptime.int.wilkesliberty.com` | A | `{{ onprem_int_ip }}` | Uptime Kuma |

### Network Admin

| Name | Type | Value | Purpose |
|------|------|-------|---------|
| `network.int.wilkesliberty.com` | A | Tailscale IP | VPN admin — Caddy on on-prem redirects to `login.tailscale.com` |

### Admin Devices (LAN)

> **TODO**: Replace placeholder IPs with actual static/reserved DHCP IPs. Run `arp -a` or check your router's DHCP table.

| Name | Type | Placeholder IP | Device |
|------|------|---------------|--------|
| `nas.int.wilkesliberty.com` | A | `{{ onprem_int_ip }}` | Synology NAS |
| `modem.int.wilkesliberty.com` | A | `{{ modem_int_ip }}` | AT&T ISP modem admin UI (LAN gateway is Eero — cloud-managed, no web UI) |
| `switch.int.wilkesliberty.com` | A | `{{ switch_int_ip }}` | TP-Link managed switch |
| `print.int.wilkesliberty.com` | A | Tailscale IP | Network printer (proxied by Caddy → `{{ printer_int_ip }}`) |

---

## Traffic Flow Summary

### Public Request: `www.wilkesliberty.com`
```
Browser → DNS → VPS IP → Caddy (VPS) → Next.js (VPS) → response
```

### Public Request: `api.wilkesliberty.com` (Drupal)
```
Browser → DNS → VPS IP → Caddy (VPS) → Tailscale → Drupal:8080 (on-prem) → response
```

### Public Request: `auth.wilkesliberty.com` (Keycloak)
```
Browser → DNS → VPS IP → Caddy (VPS) → Tailscale → Keycloak:8081 (on-prem) → response
```

### Internal Request: `monitor.int.wilkesliberty.com` (Grafana)
```
Admin device (on Tailscale) → Tailscale Split DNS → CoreDNS → {{ onprem_int_ip }}
→ Caddy (on-prem, Tailscale-bound) → Grafana:3001 → response
```

Internal requests never leave the Tailscale network. External clients cannot resolve `*.int.wilkesliberty.com`.

---

## Management

### Terraform (Public Records)

```bash
# Preview changes
terraform plan

# Apply DNS changes
terraform apply

# View current state
terraform show
```

### CoreDNS (Internal Records)

Edit the zone file:
```bash
# Increment serial in YYYYMMDDNN format before deploying
vim coredns/zones/int.wilkesliberty.com.zone

# Deploy via Ansible
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml
```

### Importing Existing Records into Terraform State

See `import_existing_records.sh` for commands to import manually-created records into Terraform state.

---

## Related Documentation

- `TAILSCALE_SETUP.md` — Tailscale mesh VPN and Split DNS configuration
- `docs/DNS_AND_SSL_SETUP.md` — DNS setup walkthrough
- `docs/TERRAFORM_DNS_QUICKSTART.md` — Terraform DNS quick reference
- `LETSENCRYPT_SSL_GUIDE.md` — Wildcard TLS certificate management
