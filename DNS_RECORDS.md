# DNS Records Configuration

This document outlines the DNS configuration for Wilkes Liberty infrastructure, managed via Terraform and Njalla.

## Public DNS Records (Managed by Terraform)

### Primary Domain (wilkesliberty.com)

#### Apex Records
- `@` (apex) → `80.78.30.4` (A) / `2a0a:3840:8078:30::504e:1e04:1337` (AAAA)
- Points to cache1 for root domain access

#### Service Aliases (CNAME Records)
- `www.wilkesliberty.com` → `cache1.prod.wilkesliberty.com`
- `api.wilkesliberty.com` → `cache1.prod.wilkesliberty.com`  
- `stats.wilkesliberty.com` → `analytics1.prod.wilkesliberty.com`
- `sso.wilkesliberty.com` → `sso1.prod.wilkesliberty.com`

#### Infrastructure Host Records (A + AAAA)
- `cache1.prod.wilkesliberty.com` → `80.78.30.4` / `2a0a:3840:8078:30::504e:1e04:1337`
- `app1.prod.wilkesliberty.com` → `80.78.28.105` / `2a0a:3840:8078:28::504e:1c69:1337`
- `db1.prod.wilkesliberty.com` → `80.78.28.129` / `2a0a:3840:8078:28::504e:1c81:1337`
- `search1.prod.wilkesliberty.com` → `80.78.28.140` / `2a0a:3840:8078:28::504e:1c8c:1337`
- `analytics1.prod.wilkesliberty.com` → `80.78.28.148` / `2a0a:3840:8078:28::504e:1c94:1337`
- `sso1.prod.wilkesliberty.com` → `80.78.28.217` / `2a0a:3840:8078:28::504e:1cd9:1337`
- `dns1.prod.wilkesliberty.com` → [DNS_SERVER_IP] / [DNS_SERVER_IPv6]

## Internal DNS (int.wilkesliberty.com)

### Managed by CoreDNS (10.10.0.10)

#### Forward Zone (host.int.wilkesliberty.com)
- `dns1.int.wilkesliberty.com` → `10.10.0.10`
- `app1.int.wilkesliberty.com` → `10.10.0.2`
- `db1.int.wilkesliberty.com` → `10.10.0.3`
- `search1.int.wilkesliberty.com` → `10.10.0.4`
- `analytics1.int.wilkesliberty.com` → `10.10.0.7`
- `sso1.int.wilkesliberty.com` → `10.10.0.8`
- `cache1.int.wilkesliberty.com` → `10.10.0.9`

#### Service Aliases (Internal)
- `app.int.wilkesliberty.com` → `app1.int.wilkesliberty.com`
- `db.int.wilkesliberty.com` → `db1.int.wilkesliberty.com`
- `search.int.wilkesliberty.com` → `search1.int.wilkesliberty.com`
- `cache.int.wilkesliberty.com` → `cache1.int.wilkesliberty.com`
- `monitor.int.wilkesliberty.com` → `analytics1.int.wilkesliberty.com`
- `uptime.int.wilkesliberty.com` → `analytics1.int.wilkesliberty.com`

#### Reverse Zone (0.10.10.in-addr.arpa)
- `10.10.10.0.10.in-addr.arpa` → `dns1.int.wilkesliberty.com`
- `2.0.10.10.in-addr.arpa` → `app1.int.wilkesliberty.com`
- `3.0.10.10.in-addr.arpa` → `db1.int.wilkesliberty.com`
- `4.0.10.10.in-addr.arpa` → `search1.int.wilkesliberty.com`
- `7.0.10.10.in-addr.arpa` → `analytics1.int.wilkesliberty.com`
- `8.0.10.10.in-addr.arpa` → `sso1.int.wilkesliberty.com`
- `9.0.10.10.in-addr.arpa` → `cache1.int.wilkesliberty.com`

## Architecture Notes

### Public Traffic Flow
1. **Web requests** (www, api) → cache1.prod.wilkesliberty.com (Varnish + Caddy)
2. **Cache backend** → app1.int.wilkesliberty.com (internal network)
3. **Service access** → Direct to service hosts via CNAME records

### Internal Communication
- All services communicate via `.int.wilkesliberty.com` domain
- CoreDNS provides forward and reverse resolution
- WireGuard mesh enables secure inter-service connectivity

### Mail Configuration
- Proton Mail DKIM records managed separately (mail_proton.tf)
- DKIM signing keys configured via Terraform variables

## Management

### Terraform Commands
```bash
# View current DNS state
terraform show

# Plan DNS changes  
terraform plan

# Apply DNS updates
terraform apply
```

### CoreDNS Management
```bash
# Deploy DNS server configuration
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/coredns.yml

# Configure DNS clients
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/resolved.yml
```
