# WilkesLiberty Infrastructure — Deployment Guide

**Version 2.0 · March 2026**

> ⚠ This guide covers the full deployment of the WilkesLiberty two-host infrastructure: on-prem server (Docker Compose backend) + Njalla VPS (public ingress). Read the entire guide before starting.

# Pre-Deployment Checklist

Complete every item below in order before running make deploy. Tick each checkbox as you go. A machine-executable check for phases 1–3 is available via make check.

|                                          |           |                                     |                                                                                                                                                    |
| ---------------------------------------- | --------- | ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| **✓**                                    | **Phase** | **Task**                            | **Command / Detail**                                                                                                                               |
| **PHASE 1 — Local Machine Setup**        |           |                                     |                                                                                                                                                    |
| ☐                                        |           | Install required tools              | ./scripts/bootstrap.sh                                                                                                                             |
| ☐                                        |           | Validate environment                | make check                                                                                                                                         |
| ☐                                        |           | Place AGE private key               | \~/.config/sops/age/keys.txt                                                                                                                       |
| ☐                                        |           | Set SOPS env var                    | export SOPS\_AGE\_KEY\_FILE=\~/.config/sops/age/keys.txt                                                                                           |
| ☐                                        |           | Verify SOPS decryption              | sops -d ansible/inventory/group\_vars/sso\_secrets.yml                                                                                             |
| ☐                                        |           | Clone webcms repo                   | git clone git@github.com:wilkesliberty/webcms.git \~/Repositories/webcms                                                                           |
| ☐                                        |           | Clone ui repo                       | git clone git@github.com:wilkesliberty/ui.git \~/Repositories/ui                                                                                   |
| ☐                                        |           | Create Docker .env                  | cp docker/.env.example \~/nas\_docker/.env && chmod 600 \~/nas\_docker/.env                                                                        |
| ☐                                        |           | Set all .env secrets                | Edit \~/nas\_docker/.env — set REDIS\_PASSWORD, DRUPAL\_DB\_PASSWORD, KEYCLOAK\_ADMIN\_PASSWORD, GRAFANA\_ADMIN\_PASSWORD, BACKUP\_ENCRYPTION\_KEY |
| **PHASE 2 — DNS (Terraform)**            |           |                                     |                                                                                                                                                    |
| ☐                                        |           | Initialize Terraform                | terraform init                                                                                                                                     |
| ☐                                        |           | Load Terraform secrets              | source scripts/load-terraform-secrets.sh                                                                                                           |
| ☐                                        |           | Review DNS plan                     | terraform plan                                                                                                                                     |
| ☐                                        |           | Apply DNS records                   | terraform apply                                                                                                                                    |
| ☐                                        |           | Add CAA records manually            | Njalla web UI → wilkesliberty.com → Add 3 CAA records (letsencrypt.org)                                                                            |
| ☐                                        |           | Verify CAA records                  | dig CAA wilkesliberty.com (expect 3 records)                                                                                                       |
| **PHASE 3 — Tailscale VPN Mesh**         |           |                                     |                                                                                                                                                    |
| ☐                                        |           | Install Tailscale on-prem           | brew install tailscale                                                                                                                             |
| ☐                                        |           | Connect on-prem to tailnet          | sudo tailscale up --advertise-routes=10.10.0.0/24 --hostname=wilkesliberty-onprem                                                                  |
| ☐                                        |           | Note on-prem Tailscale IP           | tailscale ip -4 (record this — needed for Caddyfile)                                                                                               |
| ☐                                        |           | Install Tailscale on VPS            | curl -fsSL https://tailscale.com/install.sh | sh                                                                                                   |
| ☐                                        |           | Connect VPS to tailnet              | sudo tailscale up --hostname=wilkesliberty-vps                                                                                                     |
| ☐                                        |           | Approve subnet route                | Tailscale admin → wilkesliberty-onprem → Subnet routes → approve 10.10.0.0/24                                                                      |
| ☐                                        |           | Configure Split DNS                 | Tailscale admin → DNS → Custom Nameservers → int.wilkesliberty.com → on-prem Tailscale IP                                                          |
| ☐                                        |           | Verify mesh connectivity            | ping -c 3 \<ON\_PREM\_TAILSCALE\_IP\> (from VPS)                                                                                                   |
| **PHASE 4 — On-prem Server (Ansible)**   |           |                                     |                                                                                                                                                    |
| ☐                                        |           | Bootstrap on-prem server            | make bootstrap (installs Docker Desktop, Tailscale, creates dirs)                                                                                  |
| ☐                                        |           | Deploy on-prem stack                | make onprem (Docker Compose, CoreDNS, internal Caddy, backups)                                                                                     |
| ☐                                        |           | Verify all containers running       | docker compose -f \~/nas\_docker/docker-compose.yml ps (all healthy)                                                                               |
| ☐                                        |           | Verify Redis auth                   | docker exec wl\_redis redis-cli -a "$REDIS\_PASSWORD" ping (expect PONG)                                                                           |
| ☐                                        |           | Create Solr core                    | docker exec -it wl\_solr bash -c "solr create -c drupal"                                                                                           |
| ☐                                        |           | Verify internal DNS                 | dig @\<ON\_PREM\_TAILSCALE\_IP\> app.int.wilkesliberty.com (expect 10.10.0.2)                                                                      |
| **PHASE 5 — VPS Deployment (Ansible)**   |           |                                     |                                                                                                                                                    |
| ☐                                        |           | Deploy VPS                          | make vps (certbot wildcard cert via Njalla DNS plugin + Caddy)                                                                                     |
| ☐                                        |           | Verify TLS certificate              | openssl x509 -in /etc/letsencrypt/live/wilkesliberty.com/fullchain.pem -noout -dates                                                               |
| ☐                                        |           | Verify Caddy serving                | curl -I https://www.wilkesliberty.com (expect 200)                                                                                                 |
| **PHASE 6 — Keycloak SSO**               |           |                                     |                                                                                                                                                    |
| ☐                                        |           | Access Keycloak admin               | https://sso.int.wilkesliberty.com (Tailscale required)                                                                                             |
| ☐                                        |           | Create wilkesliberty realm          | Keycloak admin → Add realm → Name: wilkesliberty                                                                                                   |
| ☐                                        |           | (Optional) Configure Grafana OAuth2 | Create grafana client → copy secret → uncomment GF\_AUTH\_\* in .env                                                                               |
| **PHASE 7 — Post-Deployment Validation** |           |                                     |                                                                                                                                                    |
| ☐                                        |           | Public endpoints respond            | https://www.wilkesliberty.com, api, auth, search (all 200 OK)                                                                                      |
| ☐                                        |           | Internal endpoints respond          | https://monitor.int / alerts.int / uptime.int (Tailscale required)                                                                                 |
| ☐                                        |           | TLS 1.1 rejected                    | openssl s\_client -connect www.wilkesliberty.com:443 -tls1\_1 → handshake failure                                                                  |
| ☐                                        |           | Security headers present            | curl -I https://www.wilkesliberty.com | grep -i strict-transport                                                                                   |
| ☐                                        |           | Internal DNS isolated               | dig monitor.int.wilkesliberty.com (from non-Tailscale device) → NXDOMAIN                                                                           |
| ☐                                        |           | Backup job scheduled                | launchctl list | grep wilkesliberty (expect entry)                                                                                                 |
| ☐                                        |           | No critical alerts firing           | https://alerts.int.wilkesliberty.com (check Alertmanager)                                                                                          |

# Commands & Scripts Reference

Every command, script, and Makefile target used in this infrastructure. Run all local commands from the infra/ repo root unless otherwise noted. Secrets must be loaded first via source scripts/load-terraform-secrets.sh before any Terraform commands.

|                                  |                                                                                      |                          |                                                                                                                             |
| -------------------------------- | ------------------------------------------------------------------------------------ | ------------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| **Category**                     | **Command / Script**                                                                 | **Run On**               | **What It Does**                                                                                                            |
| **Setup & Bootstrapping**        |                                                                                      |                          |                                                                                                                             |
| **Bootstrap**                    | ./scripts/bootstrap.sh                                                               | Local                    | Installs sops, age, terraform, ansible, ansible-galaxy collections via Homebrew/pip. Idempotent.                            |
| **Bootstrap**                    | make bootstrap                                                                       | Local                    | Alias for ./scripts/bootstrap.sh                                                                                            |
| **Env check**                    | make check                                                                           | Local                    | Runs dev-environment-check.sh — validates all tools, SOPS config, .env secrets, sibling repos, Ansible inventory, Terraform |
| **Env check**                    | ./scripts/dev-environment-check.sh                                                   | Local                    | Full pre-flight check with exit code 1 on any failure                                                                       |
| **Secrets Management (SOPS)**    |                                                                                      |                          |                                                                                                                             |
| **Decrypt**                      | sops -d \<file\>                                                                     | Local                    | Decrypt any SOPS-encrypted file to stdout. Requires SOPS\_AGE\_KEY\_FILE set.                                               |
| **Edit secrets**                 | sops ansible/inventory/group\_vars/sso\_secrets.yml                                  | Local                    | Open encrypted sso\_secrets.yml in editor — saves re-encrypted on exit                                                      |
| **Edit secrets**                 | sops ansible/inventory/group\_vars/tailscale\_secrets.yml                            | Local                    | Open encrypted Tailscale secrets file                                                                                       |
| **Edit secrets**                 | sops terraform\_secrets.yml                                                          | Local                    | Open encrypted Terraform secrets (Njalla token, Proton DKIM, verification)                                                  |
| **Load TF secrets**              | source scripts/load-terraform-secrets.sh                                             | Local                    | Decrypts terraform\_secrets.yml and exports all keys as TF\_VAR\_\* env vars for Terraform                                  |
| **Terraform (DNS)**              |                                                                                      |                          |                                                                                                                             |
| **Init**                         | terraform init                                                                       | Local                    | Download Njalla provider (sighery/njalla v0.10.0), initialise lock file                                                     |
| **Plan**                         | terraform plan                                                                       | Local                    | Preview DNS changes without applying. Always run before apply.                                                              |
| **Apply**                        | terraform apply                                                                      | Local                    | Apply DNS record changes to Njalla. Requires TF\_VAR\_\* secrets loaded.                                                    |
| **Import**                       | terraform import \<resource\> \<domain:id\>                                          | Local                    | Import a manually-created DNS record into Terraform state                                                                   |
| **Identify**                     | ./identify\_terraform\_records.sh                                                    | Local                    | Lists current Njalla DNS record IDs to help with terraform import                                                           |
| **Import helper**                | ./import\_existing\_records.sh                                                       | Local                    | Generates terraform import commands for all existing Njalla records                                                         |
| **Ansible Deployment**           |                                                                                      |                          |                                                                                                                             |
| **Full deploy**                  | make deploy                                                                          | Local                    | Runs onprem + monitoring + vps playbooks in sequence                                                                        |
| **On-prem**                      | make onprem                                                                          | Local                    | Deploys Docker stack, CoreDNS, internal Caddy, backups to on-prem server                                                    |
| **VPS**                          | make vps                                                                             | Local                    | Deploys Let’s Encrypt wildcard cert (auto DNS-01 via Njalla) + public Caddy to VPS                                          |
| **Monitoring**                   | make monitoring                                                                      | Local                    | Deploys Prometheus, Grafana, Alertmanager stack                                                                             |
| **Bootstrap remote**             | make bootstrap                                                                       | Local                    | Runs bootstrap.yml — preps on-prem server (Docker, dirs, .env)                                                              |
| **Validate inventory**           | ansible-inventory -i ansible/inventory/hosts.ini --graph                             | Local                    | Verifies Ansible inventory parses correctly                                                                                 |
| **Ping hosts**                   | ansible -i ansible/inventory/hosts.ini all -m ping                                   | Local                    | Confirms SSH + Ansible connectivity to all hosts                                                                            |
| **Docker Stack (On-prem)**       |                                                                                      |                          |                                                                                                                             |
| **Start stack**                  | docker compose up -d                                                                 | On-prem (\~/nas\_docker) | Start all 11 production containers in background                                                                            |
| **Stop stack**                   | docker compose down                                                                  | On-prem (\~/nas\_docker) | Stop and remove containers (data volumes preserved)                                                                         |
| **Health check**                 | docker compose ps                                                                    | On-prem                  | Show status and health of all containers                                                                                    |
| **Logs**                         | docker compose logs -f \<service\>                                                   | On-prem                  | Stream logs for a container (e.g. drupal, postgres, redis)                                                                  |
| **Restart service**              | docker compose restart \<service\>                                                   | On-prem                  | Restart a single container without affecting others                                                                         |
| **Rebuild image**                | docker compose build --no-cache \<service\>                                          | On-prem                  | Force-rebuild Docker image (e.g. after webcms/ui repo changes)                                                              |
| **Solr core**                    | docker exec -it wl\_solr bash -c "solr create -c drupal"                             | On-prem                  | Create Drupal Solr core on first deploy (required once)                                                                     |
| **Redis auth test**              | docker exec wl\_redis redis-cli -a "$REDIS\_PASSWORD" ping                           | On-prem                  | Verify Redis authentication — expect PONG                                                                                   |
| **Drupal shell**                 | docker exec -it wl\_drupal bash                                                      | On-prem                  | Open bash shell inside Drupal container                                                                                     |
| **Drush**                        | docker exec -it wl\_drupal bash -c 'drush \<cmd\>'                                   | On-prem                  | Run Drush commands (cr, updb, cim, etc.) inside Drupal container                                                            |
| **Backup & Restore**             |                                                                                      |                          |                                                                                                                             |
| **Manual backup**                | \~/Scripts/backup-onprem.sh                                                          | On-prem                  | Run full on-prem backup immediately (normally runs at 04:00 AM via launchd)                                                 |
| **DB backup**                    | scripts/backup-db.sh                                                                 | On-prem                  | Backup PostgreSQL databases to encrypted archive                                                                            |
| **Check backup job**             | launchctl list | grep wilkesliberty                                                  | On-prem                  | Confirm the daily backup launchd plist is loaded and active                                                                 |
| **Caddy**                        |                                                                                      |                          |                                                                                                                             |
| **Reload config**                | systemctl reload caddy                                                               | VPS                      | Reload Caddy config without dropping connections (also triggered by cert renewal hook)                                      |
| **Validate config**              | caddy validate --config /etc/caddy/Caddyfile                                         | VPS                      | Check Caddyfile syntax before reloading                                                                                     |
| **Check status**                 | systemctl status caddy                                                               | VPS                      | Show Caddy service status, last log lines                                                                                   |
| **TLS / Let’s Encrypt**          |                                                                                      |                          |                                                                                                                             |
| **Check cert dates**             | openssl x509 -in /etc/letsencrypt/live/wilkesliberty.com/fullchain.pem -noout -dates | VPS                      | Verify certificate expiry dates                                                                                             |
| **Force renew**                  | certbot renew --force-renewal                                                        | VPS                      | Force certificate renewal regardless of expiry (use sparingly)                                                              |
| **Check cron**                   | crontab -l -u root | grep certbot                                                    | VPS                      | Verify the daily auto-renewal cron job is installed                                                                         |
| **Monitor issuance**             | https://crt.sh/?q=wilkesliberty.com                                                  | Browser                  | Check Certificate Transparency logs for unauthorized cert issuance                                                          |
| **CoreDNS**                      |                                                                                      |                          |                                                                                                                             |
| **Test resolution**              | dig @\<TS\_IP\> app.int.wilkesliberty.com                                            | Any TS device            | Query CoreDNS directly by Tailscale IP — expect 10.10.0.2                                                                   |
| **Internal test**                | docker exec wl\_coredns dig @127.0.0.1 app.int.wilkesliberty.com                     | On-prem                  | Test CoreDNS from inside the container                                                                                      |
| **Isolation test**               | dig monitor.int.wilkesliberty.com                                                    | Non-TS device            | Confirm internal DNS returns NXDOMAIN outside Tailscale                                                                     |
| **Post-Deployment Verification** |                                                                                      |                          |                                                                                                                             |
| **TLS check**                    | openssl s\_client -connect www.wilkesliberty.com:443 -tls1\_1                        | Local                    | TLS 1.1 must fail with handshake failure                                                                                    |
| **Headers check**                | curl -I https://www.wilkesliberty.com                                                | Local                    | Verify HSTS, X-Frame-Options, Permissions-Policy headers present                                                            |
| **CAA check**                    | dig CAA wilkesliberty.com                                                            | Local                    | Expect 3 CAA records (letsencrypt.org x2, iodef)                                                                            |
| **Connectivity**                 | ping -c 3 \<ON\_PREM\_TAILSCALE\_IP\>                                                | VPS                      | Verify Tailscale mesh connectivity from VPS to on-prem                                                                      |

# 1\. Architecture Overview

WilkesLiberty uses a two-host architecture. The on-prem server runs all backend services (Drupal, Keycloak, PostgreSQL, Redis, Solr, monitoring). The Njalla VPS is the sole public ingress point — it serves Next.js directly and reverse-proxies all other services to the on-prem server over a Tailscale mesh VPN.

## 1.1 Traffic Flow

| **Service**      | **Public URL**                    | **Served By**         | **Backend**            |
| ---------------- | --------------------------------- | --------------------- | ---------------------- |
| Next.js frontend | https://www.wilkesliberty.com     | VPS (directly)        | ui repo                |
| Drupal CMS / API | https://api.wilkesliberty.com     | VPS Caddy → Tailscale | webcms repo, port 8080 |
| Keycloak SSO     | https://auth.wilkesliberty.com    | VPS Caddy → Tailscale | on-prem, port 8081     |
| Solr search      | https://search.wilkesliberty.com  | VPS Caddy → Tailscale | on-prem, port 8983     |
| VPN admin        | https://network.wilkesliberty.com | CNAME → Tailscale     | login.tailscale.com    |

## 1.2 Internal Services (Tailscale Only)

Internal services are accessible only over the Tailscale network via \*.int.wilkesliberty.com. Three independent layers enforce Tailscale-only access:

  - Tailscale Split DNS — \*.int.wilkesliberty.com only resolves on Tailscale (NXDOMAIN otherwise)

  - CoreDNS — binds on Tailscale IP only, not reachable from the public internet

  - Internal Caddy — binds on Tailscale IP only, not reachable from the public internet

| **Internal URL**                         | **Service**        | **Port** |
| ---------------------------------------- | ------------------ | -------- |
| https://app.int.wilkesliberty.com        | Drupal admin       | 8080     |
| https://sso.int.wilkesliberty.com        | Keycloak admin     | 8081     |
| https://monitor.int.wilkesliberty.com    | Grafana dashboards | 3001     |
| https://metrics.int.wilkesliberty.com | Prometheus metrics | 9090     |
| https://alerts.int.wilkesliberty.com     | Alertmanager       | 9093     |
| https://uptime.int.wilkesliberty.com     | Uptime Kuma        | —        |
| https://network.int.wilkesliberty.com    | VPN admin console  | CNAME    |

## 1.3 Docker Compose Services (On-prem)

| **Container**          | **Port**    | **Purpose**                     | **Source**  |
| ---------------------- | ----------- | ------------------------------- | ----------- |
| wl\_drupal             | 8080        | Headless CMS, JSON:API, GraphQL | webcms repo |
| wl\_postgres           | internal    | PostgreSQL 16 database          | —           |
| wl\_redis              | internal    | Object cache (auth required)    | —           |
| wl\_keycloak           | 8081 / 9000 | SSO, OAuth2 / Metrics           | —           |
| wl\_solr               | 8983        | Full-text search                | —           |
| wl\_prometheus         | 9090        | Metrics collection              | —           |
| wl\_grafana            | 3001        | Dashboards                      | —           |
| wl\_alertmanager       | 9093        | Alert routing                   | —           |
| wl\_node\_exporter     | 9100        | Host metrics                    | —           |
| wl\_cadvisor           | 8082        | Container metrics               | —           |
| wl\_postgres\_exporter | 9187        | DB metrics                      | —           |

# 2\. Prerequisites & Placeholders

## 2.1 Required Software

Run ./scripts/bootstrap.sh from the infra/ repo root to install all required tools automatically. The script is idempotent — safe to re-run on an already-configured machine. It installs sops, age, terraform, ansible, and ansible-galaxy collections; checks for sibling repos (webcms, ui); and configures SOPS\_AGE\_KEY\_FILE in your shell profile. After running, use make check to confirm all prerequisites are met before deploying.

| **Software**               | **Install Command**                                                | **Purpose**                 |
| -------------------------- | ------------------------------------------------------------------ | --------------------------- |
| Docker Desktop             | brew install --cask docker                                         | Runs all backend containers |
| Tailscale                  | brew install tailscale                                             | VPN mesh                    |
| SOPS                       | brew install sops                                                  | Secrets encryption          |
| AGE                        | brew install age                                                   | Encryption key backend      |
| Ansible                    | pip install ansible --break-system-packages                        | Deployment automation       |
| Terraform                  | brew install terraform                                             | DNS management              |
| ansible-galaxy collections | ansible-galaxy collection install community.sops community.general | Ansible plugins             |

## 2.2 Required Repositories

Docker images are built using a context of \~/Repositories/ (two levels above infra/docker/). The following sibling repositories must be cloned before building:

  - **webcms:** \~/Repositories/webcms — Drupal CMS source (Drupal Docker image copies from webcms/)

  - **ui:** \~/Repositories/ui — Next.js frontend source (Next.js Docker image copies from ui/)

## 2.3 Fill-in Placeholders

Replace these values throughout configuration files before deploying:

| **Placeholder**             | **Description**                         | **Where Used**              |
| --------------------------- | --------------------------------------- | --------------------------- |
| \<VPS\_IPV4\>               | Njalla VPS IPv4 address                 | terraform.tfvars, Caddyfile |
| \<VPS\_IPV6\>               | Njalla VPS IPv6 (optional)              | terraform.tfvars            |
| \<ON\_PREM\_TAILSCALE\_IP\> | On-prem server Tailscale IP (100.x.x.x) | Caddyfile.production.j2     |
| \<NJALLA\_API\_TOKEN\>      | Njalla DNS API token                    | terraform.tfvars            |
| DRUPAL\_DB\_PASSWORD        | Strong random password                  | docker/.env                 |
| REDIS\_PASSWORD             | Strong random password                  | docker/.env (required)      |
| KEYCLOAK\_ADMIN\_PASSWORD   | Strong random password                  | docker/.env                 |
| GRAFANA\_ADMIN\_PASSWORD    | Strong random password                  | docker/.env                 |
| BACKUP\_ENCRYPTION\_KEY     | Strong random key                       | docker/.env (required)      |

> Generate strong passwords: openssl rand -base64 32

# 3\. Secrets Management (SOPS + AGE)

All secrets in this repository are encrypted with SOPS + AGE. The AGE private key must be present at \~/.config/sops/age/keys.txt and SOPS\_AGE\_KEY\_FILE must be set in your shell environment.

## 3.1 Setup AGE Key

```bash
export SOPS\_AGE\_KEY\_FILE=\~/.config/sops/age/keys.txt
```

Add this to \~/.zshrc or \~/.bash\_profile so it persists across sessions.

## 3.2 Verify Decryption

```bash
sops -d ansible/inventory/group\_vars/sso\_secrets.yml

sops -d ansible/inventory/group\_vars/tailscale\_secrets.yml

sops -d terraform\_secrets.yml
```

All three must decrypt without errors before proceeding.

## 3.3 Docker Environment File

Docker secrets are in \~/nas\_docker/.env (never committed to git). Create it from the template and restrict permissions immediately:

> cp docker/.env.example \~/nas\_docker/.env
>
> chmod 600 \~/nas\_docker/.env
>
> nano \~/nas\_docker/.env
>
> REDIS\_PASSWORD is required — Redis rejects unauthenticated connections. BACKUP\_ENCRYPTION\_KEY is required — backups are encrypted at rest. Both must be set before starting the Docker stack.

# 4\. Terraform DNS Records

All public DNS records for wilkesliberty.com are managed via Terraform with the Njalla provider (sighery/njalla v0.10.0). The source of truth is records.tf.

## 4.1 Configure Variables

```bash
\# Create terraform.tfvars (gitignored)

njalla\_api\_token = "\<NJALLA\_API\_TOKEN\>"

vps\_ipv4 = "\<VPS\_IPV4\>"

vps\_ipv6 = "" \# Set to IPv6 or leave empty

chmod 600 terraform.tfvars
```

## 4.2 Apply DNS Records

```bash
terraform init

terraform plan \# Review all changes

terraform apply \# Apply when satisfied
```

## 4.3 DNS Records Created by Terraform

| **Subdomain**     | **Type** | **Value**            | **Purpose**                   |
| ----------------- | -------- | -------------------- | ----------------------------- |
| wilkesliberty.com | A / AAAA | VPS IP               | Apex                          |
| www               | A / AAAA | VPS IP               | Next.js frontend              |
| api               | A / AAAA | VPS IP               | Drupal CMS (webcms repo)      |
| auth              | A / AAAA | VPS IP               | Keycloak SSO                  |
| search            | A / AAAA | VPS IP               | Solr search (CIDR-restricted) |
| network           | CNAME    | login.tailscale.com. | VPN admin console             |

## 4.4 CAA Records (Manual — Njalla Web UI)

> The Njalla Terraform provider does not support CAA records. Add these manually in the Njalla web interface for wilkesliberty.com:

| **Tag**   | **Value**                        |
| --------- | -------------------------------- |
| issue     | "letsencrypt.org"                |
| issuewild | "letsencrypt.org"                |
| iodef     | "mailto:admin@wilkesliberty.com" |

```bash
dig CAA wilkesliberty.com \# Verify after adding
```

Monitor for unauthorized certificate issuance: https://crt.sh/?q=wilkesliberty.com

# 5\. Tailscale VPN Mesh

Tailscale must be running on both hosts before deploying the application stack. VPS Caddy's reverse\_proxy directives reference the on-prem Tailscale IP.

## 5.1 On-prem Server

```bash
brew install tailscale

sudo tailscaled &

sudo tailscale up --advertise-routes=10.10.0.0/24 --hostname=wilkesliberty-onprem

tailscale ip -4 \# Note this — needed for VPS Caddyfile
```

## 5.2 Njalla VPS

```bash
curl -fsSL https://tailscale.com/install.sh | sh

sudo tailscale up --hostname=wilkesliberty-vps

tailscale ip -4
```

## 5.3 Approve Subnet Route

In the Tailscale admin console (https://login.tailscale.com or network.wilkesliberty.com once DNS is live):

  - Find the wilkesliberty-onprem machine

  - Under Subnet routes, approve 10.10.0.0/24

This allows the VPS to reach all on-prem Docker services over Tailscale.

## 5.4 Configure Split DNS

In Tailscale admin → DNS tab → Custom Nameservers, add:

| **Domain**            | **Nameserver**              |
| --------------------- | --------------------------- |
| int.wilkesliberty.com | \<ON\_PREM\_TAILSCALE\_IP\> |

This routes all \*.int.wilkesliberty.com queries to CoreDNS on the on-prem server, only for Tailscale-connected devices.

## 5.5 Verify Connectivity

```bash
\# From VPS — should reach on-prem

ping -c 3 \<ON\_PREM\_TAILSCALE\_IP\>

\# From Tailscale device — should resolve to 10.10.0.7

dig monitor.int.wilkesliberty.com
```

# 6\. Let's Encrypt Wildcard Certificate

Certificate issuance and renewal are fully automated by the letsencrypt Ansible role, which runs as part of make vps. No manual certbot commands or TXT record pasting required. The role installs certbot, the custom Njalla DNS plugin (which calls the Njalla API to place and clean up the \_acme-challenge record automatically), obtains the wildcard certificate non-interactively, and configures a cron job for automatic renewal with a Caddy reload hook. Caddy is configured with auto\_https off and reads the certbot-managed wildcard certificate directly.

## 6.1 Automated Certificate Issuance (via Ansible)

```bash
make vps
```

This runs ansible/playbooks/vps.yml, which applies the letsencrypt role before deploying Caddy. The role: (1) installs certbot and the custom Njalla DNS plugin; (2) creates an encrypted credentials file from njalla\_api\_token (from sso\_secrets.yml); (3) calls certbot certonly --authenticator dns-njalla --non-interactive to obtain the wildcard certificate (Njalla API handles the DNS challenge automatically); (4) sets up a daily cron job with a Caddy reload deploy hook; (5) skips issuance if a valid cert already exists.

## 6.2 Verify Certificate

```bash
ls /etc/letsencrypt/live/wilkesliberty.com/

openssl x509 -in /etc/letsencrypt/live/wilkesliberty.com/fullchain.pem -noout -dates
```

## 6.3 Renewal (Automatic)

Renewal is fully automatic. The Ansible role installs a cron job at 02:30 daily that runs certbot renew --quiet with a deploy hook at /etc/letsencrypt/renewal-hooks/deploy/reload-caddy.sh that reloads Caddy automatically after each successful renewal. Certbot only renews when expiry is within 30 days. No manual intervention required. See LETSENCRYPT\_SSL\_GUIDE.md for monitoring guidance.

# 7\. Ansible Deployment

Ansible automates the full deployment of both hosts. Encrypted secrets are automatically decrypted by the community.sops plugin during playbook runs.

## 7.1 Validate Inventory

```bash
ansible-inventory -i ansible/inventory/hosts.ini --graph

ansible -i ansible/inventory/hosts.ini all -m ping
```

## 7.2 Deploy On-prem Server

```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml
```

This playbook:

  - Creates \~/nas\_docker/, \~/nas\_docker\_staging/, \~/Scripts/ directory structure

  - Installs Docker Desktop, Tailscale, Proton VPN via Homebrew

  - Copies docker-compose.yml and monitoring configurations

  - Deploys internal Caddy (Caddyfile.internal.j2, binds on Tailscale IP only)

  - Deploys CoreDNS with zone file for int.wilkesliberty.com (binds on Tailscale IP only)

  - Deploys launchd plist for daily encrypted backups (04:00 AM)

  - Clones staging branches; renders and starts staging docker-compose

  - Builds and starts production Docker stack (Drupal from webcms, Next.js from ui)

## 7.3 Deploy Njalla VPS

```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/vps.yml
```

This playbook:

  - Installs Docker, Caddy, certbot on VPS

  - Deploys Caddyfile.production.j2 (public vhosts with TLS 1.2+, security headers)

  - Deploys Next.js built from ui repo

  - Starts Caddy and Next.js

> Before running vps.yml: ensure the wildcard Let's Encrypt certificate is in place (Section 6) and Tailscale is connected on the VPS (Section 5.2).

# 8\. Docker Stack Verification

## 8.1 Check Container Health

```bash
cd \~/nas\_docker

docker compose ps
```

All services should show healthy or running. Wait 2–3 minutes after start for health checks.

## 8.2 Verify Redis Authentication

> \# Without password — must fail
>
> docker exec wl\_redis redis-cli ping
>
> \# Expected: NOAUTH Authentication required.
>
> \# With password — must succeed
>
> docker exec wl\_redis redis-cli -a "$REDIS\_PASSWORD" ping
>
> \# Expected: PONG
>
> Redis is configured with --requirepass. If REDIS\_PASSWORD is missing from .env, the Drupal container will fail to start (it's required via :? syntax in docker-compose.yml).

## 8.3 Create Solr Core

```bash
docker exec -it wl\_solr bash -c "solr create -c drupal"

curl http://localhost:8983/solr/admin/cores?action=STATUS
```

## 8.4 Drupal Trusted Host Patterns

Drupal is configured with an explicit allowlist of trusted hostnames (not a wildcard). Only these hosts are accepted:

  - localhost, drupal (Docker internal names)

  - api.wilkesliberty.com (public)

  - app.int.wilkesliberty.com (internal Caddy)

  - auth.wilkesliberty.com, sso.int.wilkesliberty.com (Keycloak SSO)

If you add a new hostname that Drupal needs to respond to, add it to docker/drupal/settings.docker.php.

# 9\. CoreDNS Internal DNS

CoreDNS is deployed by the wl-onprem Ansible role. It serves the int.wilkesliberty.com zone and binds only on the Tailscale IP.

## 9.1 Zone File Location

```bash
coredns/zones/int.wilkesliberty.com.zone
```

## 9.2 Key Records

| **Name**   | **Type** | **Value**            | **Service**                                  |
| ---------- | -------- | -------------------- | -------------------------------------------- |
| ns         | A        | 10.10.0.10           | CoreDNS itself                               |
| app        | A        | 10.10.0.2            | Drupal (webcms) — also api.wilkesliberty.com |
| sso        | A        | 10.10.0.8            | Keycloak — also auth.wilkesliberty.com       |
| db         | A        | 10.10.0.3            | PostgreSQL                                   |
| search     | A        | 10.10.0.4            | Solr                                         |
| cache      | A        | 10.10.0.9            | Redis                                        |
| monitor    | A        | 10.10.0.7            | Grafana                                      |
| metrics    | A        | 10.10.0.7            | Prometheus                                   |
| alerts     | A        | 10.10.0.7            | Alertmanager                                 |
| uptime     | A        | 10.10.0.7            | Uptime Kuma                                  |
| network    | CNAME    | login.tailscale.com. | VPN admin                                    |

## 9.3 Update Zone Serial When Editing

The zone file serial must be incremented in YYYYMMDDNN format before each redeployment (e.g., 2026033001 → 2026033002 for the second edit on 2026-03-30). Then redeploy via Ansible.

## 9.4 Verify CoreDNS (from Tailscale device)

```bash
dig @\<ON\_PREM\_TAILSCALE\_IP\> app.int.wilkesliberty.com

\# Expected: 10.10.0.2

dig @\<ON\_PREM\_TAILSCALE\_IP\> network.int.wilkesliberty.com

\# Expected: CNAME login.tailscale.com.
```

# 10\. Caddy Configuration

## 10.1 VPS Caddy (Public)

File: ansible/roles/vps-proxy/templates/Caddyfile.production.j2

Key features:

  - auto\_https off — uses certbot-managed wildcard cert directly

  - TLS 1.2+ minimum enforced in global block: tls { protocols tls1.2 tls1.3 }

  - Security headers on all vhosts via reusable snippets (public\_headers\_html, public\_headers\_api)

  - search.wilkesliberty.com restricted to admin\_allow\_cidrs (IP allowlist)

  - Server and X-Powered-By headers removed on all vhosts

## 10.2 Security Headers (public\_headers\_html)

| **Header**                | **Value**                                                    |
| ------------------------- | ------------------------------------------------------------ |
| Strict-Transport-Security | max-age=63072000; includeSubDomains; preload                 |
| X-Frame-Options           | SAMEORIGIN                                                   |
| X-Content-Type-Options    | nosniff                                                      |
| X-XSS-Protection          | 1; mode=block                                                |
| Referrer-Policy           | strict-origin-when-cross-origin                              |
| Permissions-Policy        | geolocation=(), microphone=(), camera=(), payment=(), usb=() |
| Content-Security-Policy   | default-src 'self'; script-src 'self' 'unsafe-inline'...     |
| Server                    | (removed)                                                    |
| X-Powered-By              | (removed)                                                    |

## 10.3 Internal Caddy (Tailscale-only)

File: ansible/roles/wl-onprem/templates/Caddyfile.internal.j2

Binds on the on-prem Tailscale IP only. Serves all \*.int.wilkesliberty.com vhosts using the Let's Encrypt wildcard cert. Uses internal\_headers snippet with HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy.

## 10.4 Prometheus Note

> Prometheus does NOT have --web.enable-lifecycle enabled. This flag enables an unauthenticated POST /-/reload endpoint and was intentionally removed. To reload Prometheus configuration: docker compose restart prometheus

# 11\. Keycloak SSO Setup

## 11.1 Access Admin Console

From a Tailscale-connected device:

```bash
https://sso.int.wilkesliberty.com
```

Or via public DNS: https://auth.wilkesliberty.com

Login: admin / KEYCLOAK\_ADMIN\_PASSWORD from .env

## 11.2 Create Realm

  - Click Add realm

  - Name: wilkesliberty

  - Click Create

## 11.3 Grafana OAuth2 (Optional)

To enable Grafana SSO via Keycloak, create a client in the wilkesliberty realm:

  - Client ID: grafana

  - Valid Redirect URI: https://monitor.int.wilkesliberty.com/login/generic\_oauth

  - Copy the client secret

Then uncomment the GF\_AUTH\_GENERIC\_OAUTH\_\* variables in \~/nas\_docker/.env and fill in the client secret. Restart Grafana.

# 12\. Post-Deployment Validation

## 12.1 Public URLs (No Tailscale Required)

| **URL**                        | **Expected Response**             |
| ------------------------------ | --------------------------------- |
| https://www.wilkesliberty.com  | Next.js homepage (200 OK)         |
| https://api.wilkesliberty.com  | Drupal JSON:API response (200 OK) |
| https://auth.wilkesliberty.com | Keycloak login page (200 OK)      |

## 12.2 Internal URLs (Tailscale Required)

| **URL**                                  | **Expected Response**   |
| ---------------------------------------- | ----------------------- |
| https://app.int.wilkesliberty.com        | Drupal admin (200 OK)   |
| https://sso.int.wilkesliberty.com        | Keycloak admin (200 OK) |
| https://monitor.int.wilkesliberty.com    | Grafana login (200 OK)  |
| https://metrics.int.wilkesliberty.com | Prometheus UI (200 OK)  |
| https://alerts.int.wilkesliberty.com     | Alertmanager (200 OK)   |

## 12.3 Security Checks

```bash
\# TLS 1.1 must be rejected

openssl s\_client -connect www.wilkesliberty.com:443 -tls1\_1 2\>&1 | grep alert

\# Expected: handshake failure

\# Security headers must be present

curl -I https://www.wilkesliberty.com | grep -i "strict-transport\\|x-frame\\|permissions"

\# CAA records must show 3 entries

dig CAA wilkesliberty.com

\# Internal DNS must NOT resolve outside Tailscale (test from non-TS device)

dig monitor.int.wilkesliberty.com \# Expected: NXDOMAIN
```

## 12.4 Full Success Criteria Checklist

  - [ ] All 11 Docker containers running and healthy on on-prem

  - [ ] https://www.wilkesliberty.com loads Next.js frontend

  - [ ] https://api.wilkesliberty.com returns Drupal JSON:API response

  - [ ] https://auth.wilkesliberty.com shows Keycloak login

  - [ ] https://monitor.int.wilkesliberty.com shows Grafana (Tailscale required)

  - [ ] https://metrics.int.wilkesliberty.com — all targets UP

  - [ ] Redis authentication working (redis-cli -a $REDIS\_PASSWORD ping → PONG)

  - [ ] TLS 1.1 rejected; TLS 1.2 accepted on public endpoints

  - [ ] Security headers (HSTS, CSP, X-Frame-Options) on all public vhosts

  - [ ] CAA records in Njalla (dig CAA wilkesliberty.com → 3 records)

  - [ ] \*.int.wilkesliberty.com NOT resolvable from non-Tailscale devices

  - [ ] Automated backups running daily at 04:00 AM (launchctl list | grep wilkesliberty)

  - [ ] No critical alerts firing in Alertmanager

# 13\. Quick Reference

## 13.1 Common Commands

| **Task**               | **Command**                                                                                   |
| ---------------------- | --------------------------------------------------------------------------------------------- |
| Start production stack | cd \~/nas\_docker && docker compose up -d                                                     |
| Check service health   | docker compose ps                                                                             |
| Stream logs            | docker compose logs -f                                                                        |
| Restart a service      | docker compose restart drupal                                                                 |
| Rebuild Drupal image   | docker compose build --no-cache drupal                                                        |
| Edit SOPS secrets      | sops ansible/inventory/group\_vars/sso\_secrets.yml                                           |
| Preview DNS changes    | terraform plan                                                                                |
| Apply DNS changes      | terraform apply                                                                               |
| Run Ansible deployment | ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml                  |
| Manual backup          | \~/Scripts/backup-onprem.sh                                                                   |
| Test Redis auth        | docker exec wl\_redis redis-cli -a "$REDIS\_PASSWORD" ping                                    |
| Reload Prometheus      | docker compose restart prometheus                                                             |
| Update Drupal modules  | docker exec -it wl\_drupal bash -c 'composer update drupal/core && drush updb -y && drush cr' |

## 13.2 Key File Locations

| **File**                                                  | **Purpose**                                           |
| --------------------------------------------------------- | ----------------------------------------------------- |
| docker/docker-compose.yml                                 | Production stack definition                           |
| docker/.env.example                                       | Docker secrets template (copy to \~/nas\_docker/.env) |
| docker/drupal/settings.docker.php                         | Drupal runtime config (trusted hosts, Redis)          |
| ansible/playbooks/onprem.yml                              | Main on-prem deployment playbook                      |
| ansible/roles/vps-proxy/templates/Caddyfile.production.j2 | Public Caddy config                                   |
| ansible/roles/wl-onprem/templates/Caddyfile.internal.j2   | Internal Caddy config                                 |
| coredns/zones/int.wilkesliberty.com.zone                  | Internal DNS zone file                                |
| records.tf                                                | Public DNS records (Terraform)                        |
| ansible/inventory/group\_vars/all.yml                     | Non-secret Ansible variables + repo URLs              |
| .sops.yaml                                                | Encryption rules for SOPS                             |

## 13.3 Related Documentation

| **Document**               | **Contents**                               |
| -------------------------- | ------------------------------------------ |
| README.md                  | Architecture overview and quick start      |
| DEPLOYMENT\_CHECKLIST.md   | Step-by-step deployment guide              |
| SECRETS\_MANAGEMENT.md     | SOPS + AGE encryption guide                |
| TAILSCALE\_SETUP.md        | Tailscale mesh VPN and Split DNS           |
| DNS\_RECORDS.md            | Public and internal DNS record reference   |
| LETSENCRYPT\_SSL\_GUIDE.md | Wildcard certificate management            |
| CLAUDE.md                  | AI assistant context and command reference |
| ansible/README.md          | Ansible variable precedence                |
