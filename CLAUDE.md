# WilkesLiberty Infrastructure

Ansible + Terraform monorepo for a two-host stack: an on-prem macOS server and a Njalla cloud VPS.

## Architecture

```
Internet → Njalla VPS (Caddy, public TLS) ──Tailscale──→ On-prem macOS (Docker stack)
                                                              └─ CoreDNS (Split DNS)
                                                              └─ Caddy internal (*.int.wilkesliberty.com)
```

- **On-prem:** Drupal (`:8080`), Keycloak (`:8081`), PostgreSQL, Redis, Solr (`:8983`), Grafana (`:3001`), Prometheus (`:9090`), Alertmanager (`:9093`), Uptime Kuma (`:3002`)
- **VPS:** Caddy reverse-proxy only — no services run here except the Next.js UI (`:3000`)
- **Networking:** Tailscale mesh; CoreDNS serves `*.int.wilkesliberty.com` via Split DNS; all internal traffic Tailscale-only
- **DNS:** Njalla registrar managed by Terraform (`records.tf`)
- **TLS:** Let's Encrypt wildcard `*.int.wilkesliberty.com` (certbot on VPS, synced to on-prem); Caddy auto-HTTPS for public `*.wilkesliberty.com`

## Key commands

```bash
make check      # validate local environment before deploying
make onprem     # deploy on-prem: CoreDNS zone + Caddyfile.internal + Docker stack
make vps        # deploy VPS: Caddyfile.production + letsencrypt + wl-vps-ui
make deploy     # onprem + vps in sequence
terraform apply # push DNS record changes to Njalla
make bootstrap  # install local operator tools (first-time setup)
```

## Secrets

All `*_secrets.yml` files under `ansible/inventory/group_vars/` are SOPS+age encrypted.

```bash
# Edit any secrets file (decrypts in $EDITOR, re-encrypts on save)
sops ansible/inventory/group_vars/network_secrets.yml

# Required env var (add to ~/.zshrc)
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
```

Key secrets files:
- `network_secrets.yml` — `onprem_tailscale_ip`, `onprem_tailscale_ipv6` (optional, enables IPv6), device LAN IPs (`nas_int_ip`, `router_int_ip`, etc.)
- `app_secrets.yml` — Drupal OAuth2 consumer, Postmark token, revalidation secrets
- `sso_secrets.yml` — Keycloak admin password, DB password, Redis password
- `tailscale_secrets.yml` — Tailscale auth key

Terraform secrets live in `terraform_secrets.yml` (SOPS-encrypted, same age key).

## Internal domains (`*.int.wilkesliberty.com`)

Tailscale Split DNS resolves these only for tailnet members. CoreDNS zone template: `ansible/roles/wl-onprem/templates/int.wilkesliberty.com.zone.j2`. Caddy template: `ansible/roles/wl-onprem/templates/Caddyfile.internal.j2`.

All A records point to `onprem_tailscale_ip` (Caddy terminates TLS, proxies to Docker ports). IPv6 AAAA records are emitted when `onprem_tailscale_ipv6` is set in `network_secrets.yml`.

| Hostname | Backend |
|---|---|
| `api.int.…` | Drupal `:8080` |
| `auth.int.…` | Keycloak `:8081` |
| `search.int.…` | Solr `:8983` (admin-CIDR only) |
| `monitor.int.…` | Grafana `:3001` |
| `metrics.int.…` | Prometheus `:9090` (admin-CIDR only) |
| `alerts.int.…` | Alertmanager `:9093` (admin-CIDR only) |
| `uptime.int.…` | Uptime Kuma `:3002` |
| `nas/router/switch/print.int.…` | LAN device admin UIs (TLS skip-verify) |
| `network.int.…` | Redirect → `login.tailscale.com` |
| `stg/api-stg/sso-stg/search-stg.int.…` | Staging stack (offset ports) |

## Public domains (`*.wilkesliberty.com`)

Managed by `records.tf` (Njalla). VPS Caddy template: `ansible/roles/vps-proxy/templates/Caddyfile.production.j2`.

| Hostname | Backend |
|---|---|
| `www.wilkesliberty.com` | Next.js UI on VPS `:3000` |
| `api.wilkesliberty.com` | Drupal on-prem via Tailscale `:8080` |
| `auth.wilkesliberty.com` | Keycloak on-prem via Tailscale `:8081` |
| `network.wilkesliberty.com` | Redirect → `login.tailscale.com` |

## Sibling repos

Assume cloned at the same level as this repo (`../webcms`, `../ui`):
- `webcms` — Drupal headless CMS (Docker image built for `api.*`)
- `ui` — Next.js frontend (deployed as systemd service on VPS)

## Playbook structure

```
ansible/
  inventory/
    hosts.ini               # on-prem + cloud-vps hosts
    group_vars/
      all.yml               # shared non-secret vars
      network_secrets.yml   # IPs, Tailscale addresses (SOPS)
      app_secrets.yml       # app credentials (SOPS)
  playbooks/
    onprem.yml              # entry point for make onprem
    vps.yml                 # entry point for make vps
  roles/
    wl-onprem/              # CoreDNS + internal Caddy + Docker Compose
    vps-proxy/              # public Caddy config
    letsencrypt/            # certbot wildcard + cert sync hook
    tailscale/              # tailscale up + Split DNS
    wl-vps-ui/              # Next.js build + sync to VPS
```
