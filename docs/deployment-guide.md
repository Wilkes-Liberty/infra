# WilkesLiberty Infrastructure — Deployment Guide

**Version 3.0 · April 2026**

> ⚠ Read this entire guide before starting. Follow the phases in order — each depends on the previous. A fresh deployment takes approximately 2–3 hours end to end.

---

# Architecture Overview

WilkesLiberty uses a two-host architecture:

- **On-prem server (macOS)** — runs all backend services in Docker Compose: Drupal CMS, Keycloak SSO, PostgreSQL, Redis, Solr, Prometheus, Grafana, Alertmanager, CoreDNS, and internal Caddy.
- **Njalla VPS (Ubuntu 24.04)** — the sole public ingress point. Runs Caddy to serve Next.js directly and reverse-proxy all other services to the on-prem server over a Tailscale mesh VPN.

## Traffic Flow

| Service | Public URL | Served By | Backend |
| --- | --- | --- | --- |
| Next.js frontend | https://www.wilkesliberty.com | VPS (directly) | ui repo |
| Drupal CMS / API | https://api.wilkesliberty.com | VPS Caddy → Tailscale | on-prem, port 8080 |
| Keycloak SSO | https://auth.wilkesliberty.com | VPS Caddy → Tailscale | on-prem, port 8081 |
| Solr search | https://search.wilkesliberty.com | VPS Caddy → Tailscale | on-prem, port 8983 |
| VPN admin | https://network.wilkesliberty.com | CNAME → Tailscale | login.tailscale.com |

## Internal Services (Tailscale-only)

All `*.int.wilkesliberty.com` services are accessible only over Tailscale. Three layers enforce this: Tailscale Split DNS (the domain doesn't resolve outside Tailscale), CoreDNS bound to the Tailscale IP only, and internal Caddy bound to the Tailscale IP only.

| Internal URL | Service | Port |
| --- | --- | --- |
| https://app.int.wilkesliberty.com | Drupal admin | 8080 |
| https://sso.int.wilkesliberty.com | Keycloak admin | 8081 |
| https://monitor.int.wilkesliberty.com | Grafana dashboards | 3001 |
| https://metrics.int.wilkesliberty.com | Prometheus | 9090 |
| https://alerts.int.wilkesliberty.com | Alertmanager | 9093 |
| https://uptime.int.wilkesliberty.com | Uptime Kuma | 3002 |

## Admin Device Proxies (Tailscale-only)

Internal Caddy reverse-proxies to LAN devices, re-wrapping their self-signed or HTTP admin UIs in the trusted wildcard cert. Device IPs are configured in `ansible/group_vars/all/coredns.yml` and `network_secrets.yml`.

| Internal URL | Device | Backend |
| --- | --- | --- |
| https://nas.int.wilkesliberty.com | Synology NAS (DSM) | 192.168.4.60:5001 (HTTPS) |
| https://router.int.wilkesliberty.com | Router | 192.168.1.254:80 |
| https://switch.int.wilkesliberty.com | Switch | 192.168.4.20:80 |
| https://printer.int.wilkesliberty.com | Printer | 192.168.4.250:80 |

## Docker Compose Services (On-prem)

| Container | Port | Purpose |
| --- | --- | --- |
| wl_drupal | 8080 | Headless CMS, JSON:API, GraphQL |
| wl_postgres | internal | PostgreSQL 16 |
| wl_redis | internal | Object cache (auth required) |
| wl_keycloak | 8081 / 9000 | SSO, OAuth2 / metrics |
| wl_solr | 8983 | Full-text search |
| wl_prometheus | 9090 | Metrics collection |
| wl_grafana | 3001 | Dashboards |
| wl_alertmanager | 9093 | Alert routing |
| wl_node_exporter | 9100 | Host metrics |
| wl_cadvisor | 8082 | Container metrics |
| wl_postgres_exporter | 9187 | DB metrics |

---

# Phase 1 — Local Machine Setup

## 1.1 Install Required Tools

From the `infra/` repo root, run the bootstrap script. It is idempotent — safe to re-run.

```bash
./scripts/bootstrap.sh
```

This installs: `sops`, `age`, `terraform`, `ansible`, and the required Ansible Galaxy collections (`community.sops`, `community.general`).

**Verify everything installed correctly:**

```bash
make check
```

This runs `scripts/dev-environment-check.sh`, which validates all tools, SOPS config, `.env` secrets, sibling repos, Ansible inventory, and Terraform. Fix any failures before continuing.

## 1.2 Configure the AGE Private Key

SOPS uses AGE for encryption. Place the private key at the expected path:

```bash
mkdir -p ~/.config/sops/age
# Copy your private key file here:
~/.config/sops/age/keys.txt
```

Add the following to `~/.zshrc` (or `~/.bash_profile`) so it persists across sessions:

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
```

Reload your shell, then verify SOPS can decrypt all secrets files:

```bash
sops -d ansible/inventory/group_vars/sso_secrets.yml
sops -d ansible/inventory/group_vars/tailscale_secrets.yml
sops -d ansible/inventory/group_vars/network_secrets.yml
sops -d ansible/inventory/group_vars/app_secrets.yml
sops -d terraform_secrets.yml
```

All must decrypt without errors before you continue.

**Secret consolidation — each variable has exactly one home:**

| Secret | File | Used by |
| --- | --- | --- |
| `njalla_api_token` | `terraform_secrets.yml` | Terraform (DNS records), `make vps` (certbot DNS-01 challenge) |
| `drupal_db_password`, `drupal_hash_salt`, `redis_password`, `grafana_admin_password`, `backup_encryption_key`, `keycloak_*`, `alert_smtp_*` | `sso_secrets.yml` | `make onprem` |
| `drupal_client_id`, `drupal_client_secret`, `drupal_revalidate_secret`, `drupal_preview_secret` | `app_secrets.yml` | `make onprem` (after Drupal install) |
| `tailscale_auth_key` | `tailscale_secrets.yml` | `make vps`, `make onprem` |
| LAN IPs, Tailscale IPs | `network_secrets.yml` | `make vps`, `make onprem` |

> **Edit a secrets file:** `sops ansible/inventory/group_vars/sso_secrets.yml` — opens the file in your editor decrypted; saves it re-encrypted on exit.
>
> **Generate a strong password:** `openssl rand -base64 32`

## 1.3 Clone Sibling Repositories

Docker images are built from a context of `~/Repositories/`. Both repos must be cloned as siblings to `infra/`:

```bash
git clone git@github.com:wilkesliberty/webcms.git ~/Repositories/webcms
git clone git@github.com:wilkesliberty/ui.git ~/Repositories/ui
```

## 1.4 Populate SOPS Secrets

`~/nas_docker/.env` is **auto-generated by Ansible** from SOPS-encrypted secrets — you no longer create or edit it manually. Before running `make onprem`, all required secrets must be present in the encrypted group_vars files.

The following secrets in `sso_secrets.yml` are required for the initial deployment. Add each one with SOPS:

```bash
sops ansible/inventory/group_vars/sso_secrets.yml
```

| Key | Notes |
| --- | --- |
| `drupal_db_password` | Strong random password — `openssl rand -base64 32` |
| `drupal_hash_salt` | Long random salt — `openssl rand -base64 55` — **never change after launch** |
| `redis_password` | Strong random password — `openssl rand -base64 32` |
| `grafana_admin_password` | Strong random password — `openssl rand -base64 32` |
| `backup_encryption_key` | Strong random key — `openssl rand -base64 32` — keep a copy in your password manager |

`keycloak_db_password` and `keycloak_admin_password` must also be present — they are likely already set in `sso_secrets.yml`. Confirm with `sops -d ansible/inventory/group_vars/sso_secrets.yml`.

`app_secrets.yml` (`drupal_client_id`, `drupal_client_secret`, `drupal_revalidate_secret`, `drupal_preview_secret`) can be left empty until Drupal is installed — see Phase 6.4.

> ⚠ `~/nas_docker/.env` is created by Ansible with `chmod 600`. Never commit it to git — it is in `.gitignore`.

## 1.5 Verify Ansible Connectivity

Confirm the inventory is correct and SSH access works:

```bash
ansible-inventory -i ansible/inventory/hosts.ini --graph
ansible -i ansible/inventory/hosts.ini all -m ping
```

> **SSH key:** The inventory uses `~/.ssh/id_ed25519`. Ensure this key is present and the VPS has its corresponding public key in `root`'s `authorized_keys`.

---

# Phase 2 — DNS Records (Terraform)

All public DNS records for `wilkesliberty.com` are managed via Terraform with the Njalla provider. This must be done before deploying the VPS, since the Let's Encrypt wildcard certificate uses a DNS-01 challenge that requires the `_acme-challenge` record to resolve.

## 2.1 Load Terraform Secrets

```bash
source scripts/load-terraform-secrets.sh
```

This decrypts `terraform_secrets.yml` and exports all values as `TF_VAR_*` environment variables. Must be run in every new terminal session before using Terraform.

## 2.2 Apply DNS Records

```bash
terraform init        # Download Njalla provider; only needed once
terraform plan        # Preview all changes — review carefully
terraform apply       # Apply when satisfied
```

## 2.3 Add CAA Records Manually

The Njalla Terraform provider does not support CAA records. Add these manually in the Njalla web interface for `wilkesliberty.com`:

| Tag | Value |
| --- | --- |
| issue | "letsencrypt.org" |
| issuewild | "letsencrypt.org" |
| iodef | "mailto:security@wilkesliberty.com" |

Verify after adding:

```bash
dig CAA wilkesliberty.com   # Expect 3 records
```

Monitor for unauthorized certificate issuance: https://crt.sh/?q=wilkesliberty.com

## 2.4 DNS Records Created by Terraform

| Subdomain | Type | Value | Purpose |
| --- | --- | --- | --- |
| wilkesliberty.com | A / AAAA | VPS IP | Apex |
| www | A / AAAA | VPS IP | Next.js frontend |
| api | A / AAAA | VPS IP | Drupal CMS |
| auth | A / AAAA | VPS IP | Keycloak SSO |
| search | A / AAAA | VPS IP | Solr (CIDR-restricted) |
| network | CNAME | login.tailscale.com. | VPN admin console |

> **Wait ~15 minutes after applying** for DNS propagation before proceeding to Phase 3. The Let's Encrypt challenge will fail if records haven't propagated.

---

# Phase 3 — Deploy the VPS (`make vps`)

This single command handles everything on the VPS: connects Tailscale, obtains the wildcard TLS certificate, and deploys Caddy. All steps are idempotent.

```bash
make vps
```

**What it does:**

1. Installs Tailscale on the VPS and connects it to the tailnet as `wl-vps`
2. Installs certbot with the custom Njalla DNS plugin
3. Obtains a wildcard Let's Encrypt certificate for `*.wilkesliberty.com` via DNS-01 (fully automated — no TXT record pasting required)
4. Obtains a second wildcard certificate for `*.int.wilkesliberty.com` (internal services) and deploys a sync script that copies it to on-prem over Tailscale SSH after each renewal
5. Sets up a daily auto-renewal cron job with a Caddy reload hook
6. Installs Caddy from the apt repository
7. Deploys the production Caddyfile with TLS, security headers, and reverse proxy rules

> **Internal wildcard cert:** The `*.int.wilkesliberty.com` cert is obtained on the VPS (which has the Njalla DNS plugin) and synced to on-prem at `/etc/letsencrypt/live/int.wilkesliberty.com/` via the deploy hook at `/etc/letsencrypt/renewal-hooks/deploy/sync-int-cert-to-onprem.sh`. The on-prem internal Caddy uses this cert. Run `make vps` before `make onprem` on a fresh deploy to ensure the cert is present.

**Verify the certificate was issued:**

```bash
ssh root@<VPS_IP> "openssl x509 -in /etc/letsencrypt/live/wilkesliberty.com/fullchain.pem -noout -dates"
```

**Verify Caddy is serving:**

```bash
curl -I https://www.wilkesliberty.com   # Expect: HTTP/2 200
```

> **Note on Tailscale hostname:** If Tailscale was already connected on the VPS before this run (e.g., from a previous deployment), the hostname may not have updated automatically. Force it manually if needed:
> ```bash
> ssh root@<VPS_IP> "tailscale set --hostname=wl-vps"
> ```

---

# Phase 4 — Deploy the On-Prem Server (`make onprem`)

> ⚠ **Prerequisites before running this command:**
> - `SOPS_AGE_KEY_FILE` must be exported in your shell (Phase 1.2) — `make onprem` uses it to decrypt both secrets and the become password (`become.sops.yml`)
> - All required SOPS secrets must be populated (Phase 1.4)
> - Tailscale must already be connected on the VPS (Phase 3)
> - The internal wildcard cert must be synced to on-prem (run `make vps` first)
> - The on-prem Tailscale IP must be recorded in `ansible/inventory/group_vars/network_secrets.yml` as `coredns_ts_ip`

```bash
make onprem
```

**What it does:**

1. Creates `~/nas_docker/`, `~/nas_docker_staging/`, `~/Scripts/`, `~/Backups/` directory structure
2. Installs Docker Desktop via Homebrew (skips if already installed)
3. Installs Tailscale via Homebrew Cask (skips if already installed)
4. Installs ProtonVPN via Homebrew Cask (skips if already installed)
5. Deploys CoreDNS with zone file for `int.wilkesliberty.com` (binds on Tailscale IP only)
6. Deploys internal Caddy (`Caddyfile.internal.j2`) with wildcard TLS for `*.int.wilkesliberty.com` (binds on Tailscale IP only)
7. Deploys Alertmanager, Prometheus, and Grafana configurations
8. Deploys the Docker Compose stack (production + staging)
9. Installs the launchd plist for daily encrypted backups at 02:00 AM

> **macOS — Tailscale Network Extension:** On the first Tailscale install, macOS requires you to manually approve the network extension at **System Settings → Privacy & Security → Network Extensions → Allow Tailscale**. The playbook cannot do this for you. Approve it when prompted, then re-run `make onprem` to continue.

> **macOS — ProtonVPN and Docker Desktop:** Homebrew Cask installations of GUI apps require interactive sudo and a TTY. If the playbook skips them because the pre-check fails, install manually:
> ```bash
> brew install --cask docker
> brew install --cask protonvpn
> ```

**After the playbook completes, get the on-prem Tailscale IP:**

```bash
tailscale ip -4
```

Record this value — you will need it in Phase 5 to configure Split DNS and approve subnet routes.

---

# Phase 5 — Tailscale Admin Console (Manual Steps)

These two steps cannot be automated. They require logging into the Tailscale admin console.

Open: https://login.tailscale.com/admin (or https://network.wilkesliberty.com once DNS and Caddy are live)

## 5.1 Approve Subnet Routes

The on-prem server advertises its LAN subnet over Tailscale so the VPS can reach on-prem Docker services by LAN IP. This must be explicitly approved:

1. Go to **Machines** tab
2. Find the on-prem machine
3. Click the three-dot menu → **Edit route settings**
4. Under **Subnet routes**, approve the LAN subnet

Without this approval, the VPS's Caddy reverse proxy cannot reach the on-prem Docker services.

## 5.2 Configure Split DNS

This routes all `*.int.wilkesliberty.com` DNS queries to CoreDNS on the on-prem server, but only for Tailscale-connected devices. Devices not on Tailscale cannot resolve these names at all.

1. Go to **DNS** tab
2. Under **Nameservers** → click **Add nameserver** → **Custom**
3. Set:
   - **Domain:** `int.wilkesliberty.com`
   - **Nameserver:** `<ON_PREM_TAILSCALE_IP>` (the `100.x.x.x` IP from Phase 4)

## 5.3 Verify Tailscale Mesh Connectivity

From the VPS, confirm it can reach the on-prem server:

```bash
ssh root@<VPS_IP> "ping -c 3 <ON_PREM_TAILSCALE_IP>"
```

From any Tailscale-connected device, confirm internal DNS resolves:

```bash
dig monitor.int.wilkesliberty.com   # Expect: on-prem Tailscale IP (100.x.x.x)
```

From a device NOT on Tailscale, confirm internal DNS is isolated:

```bash
dig monitor.int.wilkesliberty.com   # Expect: NXDOMAIN
```

---

# Phase 6 — One-Time Post-Deploy Setup

These steps are required once on a fresh deployment and do not need to be repeated on re-deployments.

## 6.1 Create the Solr Core

Solr does not create the Drupal core automatically. Run this once after the Docker stack is up:

```bash
docker exec -it wl_solr bash -c "solr create -c drupal"
```

Verify:

```bash
curl http://localhost:8983/solr/admin/cores?action=STATUS
```

## 6.2 Verify Keycloak Database Exists

The init script at `docker/postgres/init/01-init-databases.sh` only runs when the Postgres data directory is first created. If Postgres was already initialized (e.g., from a prior `make onprem` run) before the init script existed, the `keycloak` database and user will be missing, and Keycloak will crash-loop with `FATAL: password authentication failed for user "keycloak"`.

Check if the keycloak role exists:

```bash
docker exec wl_postgres psql -U drupal -d drupal -c "\du"
```

If `keycloak` is not listed, create it manually using the password from the container environment:

```bash
KEYCLOAK_PW=$(docker exec wl_postgres env | grep KEYCLOAK_DB_PASSWORD | cut -d= -f2-)
docker exec wl_postgres psql -U drupal -d drupal -c "CREATE USER keycloak WITH PASSWORD '$KEYCLOAK_PW';"
docker exec wl_postgres psql -U drupal -d drupal -c "CREATE DATABASE keycloak OWNER keycloak ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE template0;"
docker exec wl_postgres psql -U drupal -d drupal -c "GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;"
docker restart wl_keycloak
```

## 6.3 Verify Container Health

All 11 containers should report `healthy` or `running`. Allow 2–3 minutes after stack start for health checks to pass.

```bash
cd ~/nas_docker
docker compose ps
```

If any containers are unhealthy, check logs:

```bash
docker compose logs -f <service_name>
```

## 6.3 Verify Redis Authentication

```bash
# Without password — must fail:
docker exec wl_redis redis-cli ping
# Expected: NOAUTH Authentication required.

# With password — must succeed:
docker exec wl_redis redis-cli -a "$REDIS_PASSWORD" ping
# Expected: PONG
```

## 6.4 Set Up Keycloak

Access the Keycloak admin console (Tailscale required):

```
https://sso.int.wilkesliberty.com
```

Or via public DNS: https://auth.wilkesliberty.com

Login: `admin` / `KEYCLOAK_ADMIN_PASSWORD` (from `~/nas_docker/.env`)

1. Click **Add realm**
2. Name: `wilkesliberty`
3. Click **Create**

**6.4a — Configure Drupal OAuth2 credentials (Next.js integration)**

After Drupal is installed and the Next.js module is enabled:

1. In Drupal, go to `/admin/config/services/consumer` and create an OAuth2 consumer
2. Note the **Client ID** and **Client Secret**
3. Go to `/admin/config/services/next` and set the **Revalidation Secret** and **Preview Secret**
4. Add all four values to `app_secrets.yml` and re-encrypt:

```bash
sops ansible/inventory/group_vars/app_secrets.yml
```

5. Re-run to render an updated `.env`:

```bash
make onprem
```

**Optional — Grafana OAuth2 via Keycloak:**

1. In the `wilkesliberty` realm, create a new client:
   - Client ID: `grafana`
   - Valid Redirect URI: `https://monitor.int.wilkesliberty.com/login/generic_oauth`
2. Copy the client secret
3. Uncomment the `GF_AUTH_GENERIC_OAUTH_*` variables in `~/nas_docker/.env` and fill in the secret
4. Restart Grafana: `docker compose restart grafana`

---

# Phase 7 — Post-Deployment Validation

Run through every item below to confirm a complete and correct deployment.

## 7.1 Public Endpoints (No Tailscale Required)

```bash
curl -I https://www.wilkesliberty.com    # Expect: 200 OK (Next.js)
curl -I https://api.wilkesliberty.com    # Expect: 200 OK (Drupal JSON:API)
curl -I https://auth.wilkesliberty.com   # Expect: 200 OK (Keycloak login)
```

## 7.2 Internal Endpoints (Tailscale Required)

| URL | Expected |
| --- | --- |
| https://app.int.wilkesliberty.com | Drupal admin (200 OK) |
| https://sso.int.wilkesliberty.com | Keycloak admin (200 OK) |
| https://monitor.int.wilkesliberty.com | Grafana login (200 OK) |
| https://metrics.int.wilkesliberty.com | Prometheus UI (200 OK) |
| https://alerts.int.wilkesliberty.com | Alertmanager (200 OK) |
| https://nas.int.wilkesliberty.com | Synology DSM login (200 OK) |
| https://router.int.wilkesliberty.com | Router admin (200/302) |
| https://switch.int.wilkesliberty.com | Switch admin (200 OK) |
| https://printer.int.wilkesliberty.com | Printer admin (200 OK) |

## 7.3 Security Checks

```bash
# TLS 1.1 must be rejected:
openssl s_client -connect www.wilkesliberty.com:443 -tls1_1 2>&1 | grep alert
# Expected: handshake failure

# Security headers must be present:
curl -I https://www.wilkesliberty.com | grep -i "strict-transport\|x-frame\|permissions"

# CAA records must show 3 entries:
dig CAA wilkesliberty.com

# Internal DNS must NOT resolve outside Tailscale:
dig monitor.int.wilkesliberty.com   # Expected: NXDOMAIN (from non-Tailscale device)
```

## 7.4 Full Success Checklist

- [ ] All 11 Docker containers running and healthy on on-prem (`docker compose ps`)
- [ ] https://www.wilkesliberty.com loads Next.js frontend
- [ ] https://api.wilkesliberty.com returns Drupal JSON:API response
- [ ] https://auth.wilkesliberty.com shows Keycloak login
- [ ] https://monitor.int.wilkesliberty.com shows Grafana (Tailscale required)
- [ ] https://metrics.int.wilkesliberty.com — all targets UP in Prometheus
- [ ] Redis authentication working (`docker exec wl_redis redis-cli -a "$REDIS_PASSWORD" ping` → PONG)
- [ ] TLS 1.1 rejected; TLS 1.2 accepted on public endpoints
- [ ] Security headers (HSTS, X-Frame-Options, Permissions-Policy) on all public vhosts
- [ ] CAA records in Njalla (`dig CAA wilkesliberty.com` → 3 records)
- [ ] `*.int.wilkesliberty.com` NOT resolvable from non-Tailscale devices
- [ ] Automated backups scheduled at 02:00 AM (`launchctl list | grep wilkesliberty`)
- [ ] No critical alerts firing in Alertmanager

---

# Reference

## Commands

All local commands run from the `infra/` repo root. Load Terraform secrets before any `terraform` command (`source scripts/load-terraform-secrets.sh`).

| Task | Command | Where |
| --- | --- | --- |
| Install all tools | `./scripts/bootstrap.sh` | Local |
| Pre-flight check | `make check` | Local |
| Edit SOPS secrets | `sops ansible/inventory/group_vars/sso_secrets.yml` | Local |
| Load Terraform secrets | `source scripts/load-terraform-secrets.sh` | Local |
| Preview DNS changes | `terraform plan` | Local |
| Apply DNS changes | `terraform apply` | Local |
| Deploy VPS | `make vps` | Local |
| Deploy on-prem | `make onprem` | Local |
| Deploy both | `make deploy` | Local |
| Start production stack | `cd ~/nas_docker && docker compose up -d` | On-prem |
| Check service health | `docker compose ps` | On-prem |
| Stream logs | `docker compose logs -f <service>` | On-prem |
| Restart a service | `docker compose restart <service>` | On-prem |
| Rebuild Docker image | `docker compose build --no-cache <service>` | On-prem |
| Create Solr core | `docker exec -it wl_solr bash -c "solr create -c drupal"` | On-prem |
| Test Redis auth | `docker exec wl_redis redis-cli -a "$REDIS_PASSWORD" ping` | On-prem |
| Run Drush command | `docker exec -it wl_drupal bash -c 'drush <cmd>'` | On-prem |
| Manual backup | `~/Scripts/backup-onprem.sh` | On-prem |
| Check backup job | `launchctl list \| grep wilkesliberty` | On-prem |
| Reload Caddy | `systemctl reload caddy` | VPS |
| Validate Caddyfile | `caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile` | VPS |
| Check TLS cert dates | `openssl x509 -in /etc/letsencrypt/live/wilkesliberty.com/fullchain.pem -noout -dates` | VPS |
| Force cert renewal | `certbot renew --force-renewal` | VPS |
| Reload Prometheus | `docker compose restart prometheus` | On-prem |
| Update Drupal modules | `docker exec -it wl_drupal bash -c 'composer update drupal/core && drush updb -y && drush cr'` | On-prem |

> **Note:** Prometheus does NOT have `--web.enable-lifecycle` enabled. The unauthenticated `/-/reload` endpoint was intentionally disabled. Reload config with `docker compose restart prometheus`.

## Key File Locations

| File | Purpose |
| --- | --- |
| `docker/docker-compose.yml` | Production stack definition |
| `docker/.env.j2` | Ansible template that renders `~/nas_docker/.env` from SOPS secrets |
| `docker/.env.example` | Human reference — documents all variables and how to generate values |
| `docker/drupal/settings.docker.php` | Drupal runtime config (trusted hosts, Redis) |
| `ansible/playbooks/onprem.yml` | On-prem deployment playbook |
| `ansible/playbooks/vps.yml` | VPS deployment playbook |
| `ansible/roles/vps-proxy/templates/Caddyfile.production.j2` | Public Caddy config |
| `ansible/roles/wl-onprem/templates/Caddyfile.internal.j2` | Internal Caddy config |
| `coredns/zones/int.wilkesliberty.com.zone` | Internal DNS zone file |
| `records.tf` | Public DNS records (Terraform) |
| `ansible/inventory/group_vars/all.yml` | Non-secret Ansible variables |
| `ansible/inventory/group_vars/sso_secrets.yml` | SOPS-encrypted: Drupal, Keycloak, Redis, Grafana, backup, SMTP credentials |
| `ansible/inventory/group_vars/app_secrets.yml` | SOPS-encrypted: Drupal OAuth2 client + Next.js integration secrets (populated post-Drupal) |
| `ansible/inventory/group_vars/tailscale_secrets.yml` | SOPS-encrypted: Tailscale auth key |
| `ansible/inventory/group_vars/network_secrets.yml` | SOPS-encrypted: LAN IPs, Tailscale IPs |
| `ansible/group_vars/all/coredns.yml` | Device ports and non-secret network vars |
| `become.sops.yml` | SOPS-encrypted: macOS become (sudo) password for `make onprem` |
| `terraform_secrets.yml` | SOPS-encrypted: Njalla API token, DNS secrets |
| `.sops.yaml` | SOPS encryption rules (which files encrypt, which AGE key) |
| `ansible.cfg` | Ansible configuration (inventory, SSH, SOPS binary path) |

**Deployed file locations (on-prem):**

| File | Purpose |
| --- | --- |
| `/opt/homebrew/etc/caddy/Caddyfile.internal` | Deployed internal Caddyfile |
| `/Library/LaunchDaemons/com.wilkesliberty.caddy-internal.plist` | Caddy LaunchDaemon |
| `/opt/homebrew/etc/coredns/Corefile` | Deployed CoreDNS config |
| `/etc/letsencrypt/live/int.wilkesliberty.com/` | Internal wildcard cert (synced from VPS) |
| `/var/log/caddy/internal.log` | Caddy access log |
| `/var/log/caddy/internal-error.log` | Caddy error log |

**Deployed file locations (VPS):**

| File | Purpose |
| --- | --- |
| `/etc/caddy/Caddyfile` | Production Caddyfile |
| `/etc/letsencrypt/live/wilkesliberty.com/` | Public wildcard cert |
| `/etc/letsencrypt/live/int.wilkesliberty.com/` | Internal wildcard cert (source, synced to on-prem) |
| `/etc/letsencrypt/renewal-hooks/deploy/sync-int-cert-to-onprem.sh` | Internal cert sync script |

## CoreDNS Zone Management

The zone file at `coredns/zones/int.wilkesliberty.com.zone` must have its serial incremented in `YYYYMMDDNN` format before each redeployment (e.g., `2026040701` → `2026040702` for a second edit on the same day). After editing, redeploy via `make onprem`.

Test CoreDNS from any Tailscale-connected device:

```bash
dig @<ON_PREM_TAILSCALE_IP> app.int.wilkesliberty.com    # Expect: Tailscale IP (100.x.x.x)
dig @<ON_PREM_TAILSCALE_IP> network.int.wilkesliberty.com  # Expect: CNAME login.tailscale.com.
```

> **Note:** CoreDNS runs as a Homebrew LaunchDaemon on macOS (not in Docker). Test it directly with `dig` against the Tailscale IP.

## Drupal Trusted Host Patterns

Drupal uses an explicit allowlist of trusted hostnames (no wildcards). The following hosts are configured:

- `localhost`, `drupal` (Docker internal)
- `api.wilkesliberty.com` (public)
- `app.int.wilkesliberty.com` (internal Caddy)
- `auth.wilkesliberty.com`, `sso.int.wilkesliberty.com` (Keycloak SSO)

To add a new hostname, edit `docker/drupal/settings.docker.php`.

## Secrets Management Quick Reference

| Action | Command |
| --- | --- |
| Decrypt to stdout | `sops -d <file>` |
| Edit in place | `sops <file>` |
| Generate password | `openssl rand -base64 32` |
| Verify AGE key loaded | `echo $SOPS_AGE_KEY_FILE` |

SOPS secrets are loaded into Ansible plays via `community.sops.load_vars` in each playbook's `pre_tasks` block (not via an automatic vars plugin). If secrets are showing as undefined during a playbook run, verify that `SOPS_AGE_KEY_FILE` is exported in your shell and that manual decryption works with `sops -d`.

`njalla_api_token` has a single canonical home in `terraform_secrets.yml`. It is loaded into `make vps` (for certbot DNS-01) and into Terraform (via `source scripts/load-terraform-secrets.sh`). It is **not** in `sso_secrets.yml`.

## TLS Certificate Renewal

Certificate renewal is fully automatic. The Ansible `letsencrypt` role installs a cron job at 02:30 daily that runs `certbot renew --quiet`. A deploy hook at `/etc/letsencrypt/renewal-hooks/deploy/reload-caddy.sh` reloads Caddy after each successful renewal. Certbot only renews when expiry is within 30 days.

To force an immediate renewal:

```bash
ssh root@<VPS_IP> "certbot renew --force-renewal"
```
