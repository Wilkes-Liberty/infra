# AGENTS.md

This file provides context to AI agents (Claude, etc.) when working with code in this repository.

## Project Scope

This repo manages infrastructure for Wilkes Liberty using Docker Compose, Ansible, and Terraform.

**Architecture**:
- **on-prem server** — all Drupal (prod + staging), all monitoring, all backend services
- **Njalla VPS** — production Next.js only; connects to on-prem server via Tailscale mesh
- **Local dev** — DDEV for Drupal, `npm run dev` for Next.js

The on-prem server runs two Docker Compose stacks side by side:
- Production: `~/nas_docker/` (ports 8080/8081/8983/9090/3001…)
- Staging: `~/nas_docker_staging/` (ports 8090/8091/8993/3010…)

## Prerequisites

- **Docker Desktop** installed and running
- **Ansible CLI** + `community.sops` + `community.general`
  ```bash
  ansible-galaxy collection install community.sops community.general
  ```
- **SOPS + AGE** for secrets management
  ```bash
  export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
  ```
- **Terraform CLI** for DNS management (optional initially)

## Core Commands

### Automated Deployment (Recommended)
```bash
# Deploy entire on-prem server stack (prod + staging)
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml
```

### Manual Docker Operations — Production
```bash
# Build/start — must run from the source repo so build context ../.. resolves correctly.
# The compose project name is locked to 'nas_docker' via the name: key in docker-compose.yml.
cd ~/Repositories/infra/docker
docker compose --env-file ~/nas_docker/.env up -d
docker compose --env-file ~/nas_docker/.env pull

# Read-only operations — can run from either directory; ~/nas_docker is convenient.
cd ~/nas_docker
docker compose down
docker compose ps
docker compose logs -f
docker compose logs drupal    # Service-specific logs
docker compose restart prometheus   # e.g. after config change
```

### Manual Docker Operations — Staging
```bash
cd ~/nas_docker_staging
docker compose up -d --build  # Start staging (builds from staging branch)
docker compose down
docker compose ps
```

### Dev Stack (on-prem server, code mounted as volumes)
```bash
cd ~/Repositories/infra/docker
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
# First time only — install dependencies inside containers:
docker compose exec drupal composer install
docker compose exec nextjs npm install
```

### Ansible Operations
```bash
# Validate inventory
ansible-inventory -i ansible/inventory/hosts.ini --graph

# Test connectivity
ansible -i ansible/inventory/hosts.ini all -m ping

# Edit encrypted secrets
sops ansible/inventory/group_vars/sso_secrets.yml
sops ansible/inventory/group_vars/tailscale_secrets.yml
```

### Terraform (DNS)
```bash
terraform plan    # Preview DNS changes
terraform apply   # Apply DNS records
terraform show    # View current state
# Secrets: terraform.tfvars (gitignored); encrypted copy: terraform_secrets.yml (SOPS)
```

### Backup
```bash
~/Scripts/backup-onprem.sh            # Full backup
~/Scripts/backup-onprem.sh --dry-run  # Preview without executing
```

## Architecture Detail

### Production Stack (on-prem server — ~/nas_docker/)

| Service | Container | Port | Purpose |
|---------|-----------|------|---------|
| Drupal 11 | wl_drupal | 8080 | Headless CMS, GraphQL/JSON:API — built from `webcms` repo, public at `api.wilkesliberty.com` |
| PostgreSQL 16 | wl_postgres | internal | Primary database |
| Redis 7 | wl_redis | internal | Object cache (allkeys-lru, password-authenticated via REDIS_PASSWORD) |
| Keycloak 25 | wl_keycloak | 8081/9000 | SSO, OAuth2 |
| Solr 9.6 | wl_solr | 8983 | Full-text search |
| Prometheus | wl_prometheus | 9090 | Metrics collection |
| Grafana | wl_grafana | 3001 | Dashboards |
| Alertmanager | wl_alertmanager | 9093 | Alert routing |
| Node Exporter | wl_node_exporter | 9100 | Host metrics |
| cAdvisor | wl_cadvisor | 8082 | Container metrics |
| Postgres Exporter | wl_postgres_exporter | 9187 | DB metrics |

Next.js production runs on the **Njalla VPS** (not the on-prem server), connecting to Drupal via Tailscale.

### Staging Stack (on-prem server — ~/nas_docker_staging/)

| Service | Container | Port |
|---------|-----------|------|
| Drupal 11 | wl_stg_drupal | 8090 |
| PostgreSQL 16 | wl_stg_postgres | internal |
| Redis 7 | wl_stg_redis | internal |
| Keycloak 25 | wl_stg_keycloak | 8091/9001 |
| Solr 9.6 | wl_stg_solr | 8993 |
| Next.js | wl_stg_nextjs | 3010 |

Staging containers join the shared `wl_monitoring` network — Prometheus auto-discovers them.

### Docker Networks
- `wl_frontend` (172.20.0.0/24) — Drupal, Keycloak, Next.js (prod)
- `wl_backend` (172.21.0.0/24) — PostgreSQL, Redis, Solr
- `wl_monitoring` (172.22.0.0/24) — all monitoring; staging containers join this
- `wl_stg_frontend` / `wl_stg_backend` — staging isolation

### Public URLs (via Njalla VPS)
- `https://www.wilkesliberty.com` — Next.js frontend (served directly on VPS)
- `https://api.wilkesliberty.com` — Drupal CMS / JSON:API (proxied to on-prem via Tailscale)
- `https://auth.wilkesliberty.com` — Keycloak SSO (proxied to on-prem via Tailscale)
- `https://network.wilkesliberty.com` — A record → VPS; Caddy redirects to `login.tailscale.com` (VPN admin)

### Internal URLs (Tailscale required — *.int.wilkesliberty.com)
- `https://api.int.wilkesliberty.com` — Drupal admin (via internal Caddy)
- `https://auth.int.wilkesliberty.com` — Keycloak admin (via internal Caddy)
- `https://monitor.int.wilkesliberty.com` — Grafana dashboards
- `https://metrics.int.wilkesliberty.com` — Prometheus metrics
- `https://alerts.int.wilkesliberty.com` — Alertmanager
- `https://uptime.int.wilkesliberty.com` — Uptime Kuma

### VPN Layers
- **Tailscale** (100.64.0.0/10) — on-prem server ↔ Njalla VPS mesh; Split DNS routes `*.int.wilkesliberty.com` to CoreDNS on on-prem
- **Proton VPN** — outer kill-switch layer on on-prem server

## File Layout

```
infra/
├── docker/
│   ├── docker-compose.yml           # Production stack
│   ├── docker-compose.dev.yml       # Dev overrides (code mounts)
│   ├── docker-compose.staging.yml.j2  # Staging template (Ansible renders it)
│   ├── .env.example                 # Production env template
│   ├── .env.staging.example         # Staging env template
│   ├── drupal/
│   │   ├── Dockerfile.prod          # Multi-stage production build
│   │   ├── Dockerfile.dev           # Dev image (deps installed inside)
│   │   └── settings.docker.php      # Reads all config from env vars
│   ├── nextjs/
│   │   ├── Dockerfile.prod          # Three-stage standalone build
│   │   └── Dockerfile.dev           # Dev image (npm run dev)
│   ├── postgres/init/               # DB init scripts (keycloak DB creation)
│   ├── prometheus/                  # prometheus.yml, alerts.yml
│   └── alertmanager/config.yml.j2  # Ansible Jinja2 template
├── ansible/
│   ├── playbooks/onprem.yml         # Main deployment playbook
│   ├── roles/wl-onprem/             # on-prem server deployment role
│   ├── inventory/
│   │   ├── hosts.ini
│   │   └── group_vars/
│   │       ├── all.yml              # Non-secret variables
│   │       ├── sso_secrets.yml      # SOPS-encrypted secrets
│   │       ├── tailscale_secrets.yml # SOPS-encrypted
│   │       ├── network_secrets.yml  # SOPS-encrypted (IPs, CIDRs)
│   │       └── app_secrets.yml      # SOPS-encrypted (Drupal OAuth2 — empty until post-install)
├── scripts/
│   └── backup-onprem.sh             # Backup with --dry-run support
├── terraform_secrets.yml            # SOPS-encrypted (DO NOT edit directly)
├── .sops.yaml                       # Auto-encryption rules
└── docs/                            # All supplementary documentation (see Documentation Index)
```

## Secrets Management

- All secrets encrypted with **SOPS + AGE** before committing
- Encryption enforced by `.sops.yaml` for `*_secrets.yml` patterns
- **Never** create plaintext temp files with secrets (they will be gitignored but still risky)
- Edit secrets: `sops ansible/inventory/group_vars/sso_secrets.yml`
- Docker env secrets: `~/nas_docker/.env` (never committed; use `.env.example` as template)
- **`chmod 600 ~/nas_docker/.env`** — set immediately after creating
- Key Docker secrets: `DRUPAL_DB_PASSWORD`, `REDIS_PASSWORD`, `KEYCLOAK_ADMIN_PASSWORD`, `GRAFANA_ADMIN_PASSWORD`, `BACKUP_ENCRYPTION_KEY`
- See **docs/SECRETS_MANAGEMENT.md** for full guide

### Bootstrap Ordering for app_secrets.yml

`app_secrets.yml` holds Drupal OAuth2 credentials that only exist after Drupal is fully installed and configured. On a fresh deployment:

1. Encrypt the file with empty values so the playbook can load it:
   ```bash
   sops --encrypt --in-place ansible/inventory/group_vars/app_secrets.yml
   ```
2. Run `make onprem` — the stack comes up, Next.js starts but cannot authenticate to Drupal yet.
3. Install Drupal, then create an OAuth2 consumer at `/admin/config/services/consumer` and configure the Next.js module at `/admin/config/services/next`.
4. Decrypt, fill in the values, and re-encrypt:
   ```bash
   sops ansible/inventory/group_vars/app_secrets.yml
   ```
5. Re-run `make onprem` — Ansible injects the real values and Next.js becomes fully functional.

## Security Notes

- **Redis** requires authentication (`REDIS_PASSWORD`) — unauthenticated connections are rejected
- **Prometheus** does NOT have `--web.enable-lifecycle` enabled (unauthenticated reload removed); use `docker compose restart prometheus` to reload config
- **Drupal trusted_host_patterns** uses an explicit allowlist (not a wildcard) — only `localhost`, `drupal`, `api.wilkesliberty.com`, `api.int.wilkesliberty.com`, `auth.wilkesliberty.com` are accepted
- **Internal services** (`*.int.wilkesliberty.com`) are triple-protected: CoreDNS binds on Tailscale IP only → Tailscale Split DNS → Caddy internal binds on Tailscale IP only
- **TLS**: Caddy (VPS) enforces TLS 1.2+ minimum via global block; security headers (HSTS, CSP, Referrer-Policy, Permissions-Policy) on all public vhosts
- **CAA records**: manually added in Njalla web UI (provider doesn't support CAA via Terraform)

## Build Context Pattern

Dockerfiles in `infra/` reference code from sibling repos using `context: ../..`:
- `../..` from `~/Repositories/infra/docker/` = `~/Repositories/`
- Drupal: `COPY webcms/composer.json ...` → reads from `~/Repositories/webcms/`
- Next.js: `COPY ui/package.json ...` → reads from `~/Repositories/ui/`
- Staging uses absolute paths rendered by Ansible from `docker-compose.staging.yml.j2`

**Important:** `docker compose build`/`pull`/`up` must always be invoked from `~/Repositories/infra/docker/` so the relative build context resolves correctly. The compose file is also copied to `~/nas_docker/` by Ansible for reference and for read-only operations (`ps`, `logs`, `down`). The project name is hardcoded as `name: nas_docker` in `docker-compose.yml` so it is consistent regardless of invocation directory.

## Ansible Role: wl-onprem

Deploys and configures everything on the on-prem server in a single playbook run:

1. Creates directory structure (`~/nas_docker/`, `~/nas_docker_staging/`, etc.)
2. Installs Docker Desktop, Tailscale, Proton VPN via Homebrew
3. Copies production docker-compose.yml and monitoring configs
4. Renders Alertmanager config from Jinja2 template
5. Deploys launchd plist for daily backups (04:00 AM)
6. Clones staging branch repos → `~/Repositories/staging/{webcms,ui}`
7. Renders and starts staging docker-compose
8. Starts production Docker stack

## Documentation Index

- **README.md** — Architecture overview and quick start
- **ansible/README.md** — Variable precedence and configuration structure
- **docs/DEPLOYMENT_CHECKLIST.md** — Step-by-step deployment guide
- **docs/SECRETS_MANAGEMENT.md** — SOPS/AGE encryption guide
- **docs/TAILSCALE_SETUP.md** — Tailscale VPN setup
- **docs/DNS_RECORDS.md** — Public DNS configuration reference
- **docs/LETSENCRYPT_SSL_GUIDE.md** — SSL certificate management (for VPS)
- **docs/GITHUB_ACTIONS_STRATEGY.md** — CI/CD roadmap (future)
- **docs/ENVIRONMENT_OVERVIEW.md** — Environment comparison (prod vs staging vs dev)
- **docs/MULTI_ENVIRONMENT_STRATEGY.md** — Multi-environment design decisions
- **docs/TERRAFORM_ORGANIZATION.md** — Terraform layout and DNS management
- **docs/DNS_AND_SSL_SETUP.md** — DNS + SSL setup walkthrough
- **docs/DNS_MIGRATION_CHECKLIST.md** — Checklist for DNS migrations
- **docs/TERRAFORM_DNS_QUICKSTART.md** — Quick reference for Terraform DNS ops
- **docs/TERRAFORM_SOPS_WORKFLOW.md** — Terraform + SOPS secrets workflow
- **docs/deployment-guide.md** — Detailed deployment guide
- **docs/ADMIN_SETUP.md** — First-run manual setup for all admin UIs (Drupal OAuth consumer, Keycloak SSO, Grafana, Solr, Uptime Kuma)
- **docs/SECURITY_CHECKLIST.md** — Pre-deployment security checklist + ongoing audit with done/partial/not-done status for every item
- **docs/CONFIG_EXPORT.md** — Drupal config export workflow: nightly auto-snapshot, manual export, config_ignore, where files land
- **docs/STAGING_REFRESH.md** — `make refresh-staging`: clone prod DB + files to staging with full sanitization
