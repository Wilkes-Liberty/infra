# DNS Records Configuration

This document describes the DNS configuration for Wilkes Liberty — public records managed via Terraform + Njalla, and internal records served by CoreDNS over Tailscale.

## Architecture Overview

```
Internet → wilkesliberty.com (public DNS, Njalla)
               ↓
           Njalla VPS  ←── Tailscale mesh ──→  On-prem server
           (Caddy, Next.js)                     (Docker Compose)

Internal clients (Tailscale) → *.int.wilkesliberty.com (CoreDNS on on-prem)
```

All public records point to the **Njalla VPS** IP. The VPS Caddy instance either serves traffic locally (Next.js) or reverse-proxies to the on-prem server over the Tailscale mesh (Drupal, Keycloak, Solr).

Internal `*.int.wilkesliberty.com` names are only resolvable on the Tailscale network via Tailscale Split DNS → CoreDNS on the on-prem server.

---

## Public DNS Records (Terraform-managed, Njalla)

Source of truth: `records.tf`

### Apex

| Name | Type | Value | Notes |
|------|------|-------|-------|
| `wilkesliberty.com` | A | `<VPS_IPV4>` | Apex → VPS |
| `wilkesliberty.com` | AAAA | `<VPS_IPV6>` | Optional; enabled when `vps_ipv6` variable is set |

### Services

| Subdomain | Type | Value | Purpose |
|-----------|------|-------|---------|
| `www` | A / AAAA | VPS IP | Next.js frontend |
| `api` | A / AAAA | VPS IP | Drupal CMS / GraphQL API (webcms repo, on-prem via Tailscale) |
| `auth` | A / AAAA | VPS IP | Keycloak SSO (on-prem via Tailscale) |
| `search` | A / AAAA | VPS IP | Solr search (on-prem via Tailscale; admin-CIDR restricted) |
| `network` | CNAME | `login.tailscale.com.` | Tailscale/VPN admin console |

> **Note**: `api`, `auth`, and `search` all resolve to the VPS IP. Caddy on the VPS proxies those requests over Tailscale to the on-prem server. The VPS is the single public ingress point.

### Mail (Proton Mail)

Managed in `mail_proton.tf`. Includes MX, SPF TXT, DKIM TXT, and DMARC TXT records. Do not edit manually — these are managed by Terraform.

### CAA Records (Manual — Njalla web UI only)

The Njalla Terraform provider (`sighery/njalla` v0.10.0) does not support CAA records. Add these manually in the Njalla web interface:

| Name | Tag | Value |
|------|-----|-------|
| `wilkesliberty.com` | `issue` | `"letsencrypt.org"` |
| `wilkesliberty.com` | `issuewild` | `"letsencrypt.org"` |
| `wilkesliberty.com` | `iodef` | `"mailto:admin@wilkesliberty.com"` |

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
| `ns.int.wilkesliberty.com` | A | `10.10.0.10` |

### Application Services (on-prem server)

These names resolve to the on-prem server's LAN IP. Internal Caddy (`Caddyfile.internal.j2`) handles TLS termination and routing.

| Name | Type | Value | Public equivalent |
|------|------|-------|-------------------|
| `app.int.wilkesliberty.com` | A | `10.10.0.2` | `api.wilkesliberty.com` (Drupal/webcms) |
| `sso.int.wilkesliberty.com` | A | `10.10.0.8` | `auth.wilkesliberty.com` (Keycloak) |

### Data & Search Services (direct access, no Caddy)

| Name | Type | Value | Service |
|------|------|-------|---------|
| `db.int.wilkesliberty.com` | A | `10.10.0.3` | PostgreSQL |
| `search.int.wilkesliberty.com` | A | `10.10.0.4` | Solr (internal) |
| `cache.int.wilkesliberty.com` | A | `10.10.0.9` | Redis |

### Monitoring & Observability (via internal Caddy)

| Name | Type | Value | Service |
|------|------|-------|---------|
| `monitor.int.wilkesliberty.com` | A | `10.10.0.7` | Grafana dashboards |
| `metrics.int.wilkesliberty.com` | A | `10.10.0.7` | Prometheus metrics |
| `alerts.int.wilkesliberty.com` | A | `10.10.0.7` | Alertmanager |
| `uptime.int.wilkesliberty.com` | A | `10.10.0.7` | Uptime Kuma |

### Network Admin

| Name | Type | Value | Purpose |
|------|------|-------|---------|
| `network.int.wilkesliberty.com` | CNAME | `login.tailscale.com.` | Tailscale/VPN admin console |

### Admin Devices (LAN)

> **TODO**: Replace placeholder IPs with actual static/reserved DHCP IPs. Run `arp -a` or check your router's DHCP table.

| Name | Type | Placeholder IP | Device |
|------|------|---------------|--------|
| `nas.int.wilkesliberty.com` | A | `10.10.0.20` | Synology NAS |
| `router.int.wilkesliberty.com` | A | `10.10.0.1` | AT&T router/gateway |
| `switch.int.wilkesliberty.com` | A | `10.10.0.50` | TP-Link managed switch |
| `printer.int.wilkesliberty.com` | A | `10.10.0.30` | Network printer |
| `print.int.wilkesliberty.com` | CNAME | → `printer.int.wilkesliberty.com` | Alias for printer |

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
Admin device (on Tailscale) → Tailscale Split DNS → CoreDNS → 10.10.0.7
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
