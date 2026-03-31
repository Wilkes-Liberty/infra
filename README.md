# Wilkes Liberty Infrastructure

Infrastructure automation and configuration for the Wilkes Liberty web platform — a multilingual headless Drupal 11 CMS with a Next.js frontend.

## Architecture

**Hardware**: on-prem server (~13 CPUs, 24 GB RAM) + Njalla VPS (single public ingress)

```
                         Internet
                            │
              ┌─────────────────────────────┐
              │          Njalla VPS          │
              │  www.wilkesliberty.com       │  ← Next.js (prod)
              │  api.wilkesliberty.com       │  ← Drupal (proxied via Tailscale)
              │  auth.wilkesliberty.com      │  ← Keycloak (proxied via Tailscale)
              │  search.wilkesliberty.com    │  ← Solr (proxied, CIDR-restricted)
              │  Caddy (TLS 1.2+, sec hdrs) │
              └────────────┬────────────────┘
                           │ Tailscale mesh (100.64.0.0/10)
              ┌────────────▼────────────────────────────────────────┐
              │                   on-prem server                    │
              │                                                      │
              │  Production Stack          Staging Stack             │
              │  ~/nas_docker/             ~/nas_docker_staging/     │
              │  ─────────────             ──────────────────────    │
              │  Drupal :8080 (webcms)     Drupal :8090              │
              │  Keycloak :8081            Keycloak :8091            │
              │  Solr :8983                Solr :8993                │
              │  PostgreSQL (internal)     PostgreSQL (internal)     │
              │  Redis (internal, auth)    Redis (internal, auth)    │
              │  Next.js (dev only)        Next.js :3010             │
              │                                                      │
              │  Monitoring (Tailscale-only, *.int.wilkesliberty.com)│
              │  Grafana  Prometheus  Alertmanager  Uptime Kuma      │
              │                                                      │
              │  CoreDNS — serves int.wilkesliberty.com (Tailscale) │
              └──────────────────────────────────────────────────────┘
```

**DNS overview**:
- `www`, `api`, `auth`, `search` — all A/AAAA records → VPS IP (Terraform-managed, Njalla)
- `network.wilkesliberty.com` — CNAME to `login.tailscale.com` (VPN admin console)
- `*.int.wilkesliberty.com` — CoreDNS on on-prem, accessible only over Tailscale (Split DNS)

**Local development**: Developers use DDEV for Drupal and `npm run dev` for Next.js — neither environment is in this repo.

## Services

### Production Stack (`~/nas_docker/`)

| Service | Container | Port | Notes |
|---------|-----------|------|-------|
| Drupal 11 | wl_drupal | 8080 | Headless CMS, GraphQL/JSON:API — built from `webcms` repo, public at `api.wilkesliberty.com` |
| PostgreSQL 16 | wl_postgres | internal | Primary database |
| Redis 7 | wl_redis | internal | Object cache (allkeys-lru, password-authenticated) |
| Keycloak 25 | wl_keycloak | 8081, 9000 | SSO, OAuth2 |
| Solr 9.6 | wl_solr | 8983 | Full-text search |
| Prometheus | wl_prometheus | 9090 | Metrics collection |
| Grafana | wl_grafana | 3001 | Dashboards |
| Alertmanager | wl_alertmanager | 9093 | Alert routing (email + Slack) |
| Node Exporter | wl_node_exporter | 9100 | Host metrics |
| cAdvisor | wl_cadvisor | 8082 | Container metrics |
| Postgres Exporter | wl_postgres_exporter | 9187 | DB metrics |

Next.js production runs on the Njalla VPS, connecting to Drupal over Tailscale.

### Staging Stack (`~/nas_docker_staging/`)

Same services on different ports: Drupal `8090`, Keycloak `8091`, Solr `8993`, Next.js `3010`. Staging containers join the shared `wl_monitoring` network and are auto-discovered by Prometheus.

## Repository Layout

```
infra/
├── docker/
│   ├── docker-compose.yml              # Production stack
│   ├── docker-compose.dev.yml          # Dev overrides (volume mounts, no build)
│   ├── docker-compose.staging.yml.j2   # Staging (Ansible template)
│   ├── .env.example                    # Production secrets template
│   ├── .env.staging.example            # Staging secrets template
│   ├── drupal/
│   │   ├── Dockerfile.prod             # Multi-stage production build
│   │   ├── Dockerfile.dev              # Dev image
│   │   └── settings.docker.php         # Reads config from env vars
│   ├── nextjs/
│   │   ├── Dockerfile.prod             # Three-stage standalone build
│   │   └── Dockerfile.dev
│   ├── postgres/init/                  # DB init scripts
│   ├── prometheus/                     # prometheus.yml, alerts.yml
│   └── alertmanager/config.yml.j2      # Jinja2 template (Ansible renders)
├── ansible/
│   ├── playbooks/onprem.yml            # Main deployment playbook
│   ├── roles/wl-onprem/               # on-prem server deployment role
│   └── inventory/
│       ├── hosts.ini
│       └── group_vars/
│           ├── all.yml                 # Non-secret variables + repo URLs
│           ├── sso_secrets.yml         # SOPS-encrypted secrets
│           └── tailscale_secrets.yml   # SOPS-encrypted
├── scripts/
│   └── backup-onprem.sh               # Supports --dry-run
├── terraform_secrets.yml              # SOPS-encrypted DNS secrets
├── .sops.yaml                         # Auto-encryption rules
└── docs/                              # DNS, Terraform, and workflow references
```

## Quick Start

### Prerequisites

```bash
# Ansible + collections
pip install ansible --break-system-packages
ansible-galaxy collection install community.sops community.general

# SOPS + AGE for secrets
brew install sops age
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt

# Terraform (for DNS management)
brew install terraform
```

Sibling repositories must be present before building Docker images:
- `~/Repositories/webcms` — Drupal CMS source (Docker build context for Drupal image)
- `~/Repositories/ui` — Next.js source (Docker build context for Next.js image)

### Deploy to on-prem server

```bash
# 1. Configure production Docker secrets
cp docker/.env.example ~/nas_docker/.env
chmod 600 ~/nas_docker/.env
# Edit with production values — set REDIS_PASSWORD, DRUPAL_DB_PASSWORD, etc.

# 2. Configure staging secrets
cp docker/.env.staging.example ~/nas_docker_staging/.env
chmod 600 ~/nas_docker_staging/.env

# 3. Run playbook (deploys Docker stack, CoreDNS, internal Caddy, backups)
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml
```

See **DEPLOYMENT_CHECKLIST.md** for the full guide including Tailscale mesh setup, Terraform DNS, VPS deployment, and Let's Encrypt.

### Manual Docker Operations

```bash
# Production
cd ~/nas_docker
docker compose up -d          # Start
docker compose ps             # Status
docker compose logs -f        # Logs
docker compose down           # Stop

# Staging
cd ~/nas_docker_staging
docker compose up -d --build  # Start (builds from staging branch)
docker compose ps
docker compose down
```

### Dev Stack (on on-prem server, code mounted live)

```bash
cd ~/Repositories/infra/docker
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# First time: install dependencies inside containers
docker compose exec drupal composer install
docker compose exec nextjs npm install
```

## Secrets Management

All secrets use **SOPS + AGE** encryption. The `.sops.yaml` file enforces encryption for any `*_secrets.yml` file committed to `ansible/inventory/group_vars/`.

```bash
# Edit encrypted secrets safely
sops ansible/inventory/group_vars/sso_secrets.yml
sops ansible/inventory/group_vars/tailscale_secrets.yml

# Docker secrets (never committed)
# Production: ~/nas_docker/.env
# Staging:    ~/nas_docker_staging/.env
```

⚠️ **Never create plaintext staging files for secrets.** If you need to work with values before encrypting, do it in memory or use `sops` directly.

See **SECRETS_MANAGEMENT.md** for full setup and rotation instructions.

## Backup

Automated daily backups run at 04:00 AM via launchd (deployed by the Ansible role).

```bash
# Manual backup
~/Scripts/backup-onprem.sh

# Dry run (preview without executing)
~/Scripts/backup-onprem.sh --dry-run

# View logs
tail -f ~/Backups/wilkesliberty/logs/backup.log
```

Backed up: PostgreSQL databases (prod + staging), Drupal files, configuration.

## Monitoring

Access on the on-prem server:
- **Grafana**: http://localhost:3001 — dashboards for all services
- **Prometheus**: http://localhost:9090 — metrics and alert rules (16 rules configured)
- **Alertmanager**: http://localhost:9093 — email + Slack routing

Staging containers are automatically discovered via Docker labels on the shared `wl_monitoring` network.

## Ansible Role: wl-onprem

The `wl-onprem` role fully automates on-prem server setup in a single playbook run:

1. Creates all directory structures (`~/nas_docker/`, `~/nas_docker_staging/`, `~/Scripts/`, etc.)
2. Installs Docker Desktop, Tailscale, Proton VPN via Homebrew
3. Copies production docker-compose.yml and monitoring configuration
4. Renders Alertmanager config from Jinja2 template (Ansible vars → config.yml)
5. Deploys internal Caddy (`Caddyfile.internal.j2`) — binds on Tailscale IP only; serves `*.int.wilkesliberty.com` with TLS
6. Deploys CoreDNS with zone file for `int.wilkesliberty.com` — binds on Tailscale IP only
7. Deploys launchd backup plist (daily 04:00 AM)
8. Clones `staging` branch of webcms and ui repos into `~/Repositories/staging/`
9. Renders and starts staging docker-compose
10. Builds and starts production Docker stack (Drupal from `webcms`, Next.js from `ui`)

## Troubleshooting

**Ansible SOPS decryption fails**
```bash
# Verify key file is present
ls $SOPS_AGE_KEY_FILE
# Test decryption manually
sops -d ansible/inventory/group_vars/sso_secrets.yml
```

**Docker service unhealthy**
```bash
docker compose logs <service>     # Check logs
docker compose ps                 # See health status
docker inspect wl_<service>       # Detailed container info
```

**Drupal not starting**
```bash
docker compose logs drupal        # Check for DB connection errors
# Ensure DRUPAL_DB_PASSWORD in .env matches POSTGRES_PASSWORD
# Ensure REDIS_PASSWORD is set (required — Redis rejects unauthenticated connections)
```

**Alertmanager not receiving alerts**
```bash
# Check the rendered config (Ansible must have run first)
cat ~/nas_docker/alertmanager/config.yml
# Re-render by running the Ansible role
```

## Documentation

- **CLAUDE.md** — AI assistant context and command reference
- **DEPLOYMENT_CHECKLIST.md** — Step-by-step deployment guide
- **SECRETS_MANAGEMENT.md** — SOPS/AGE encryption setup and rotation
- **TAILSCALE_SETUP.md** — Tailscale mesh VPN configuration
- **DNS_RECORDS.md** — Public DNS configuration reference
- **LETSENCRYPT_SSL_GUIDE.md** — SSL certificates for the Njalla VPS
- **GITHUB_ACTIONS_STRATEGY.md** — CI/CD pipeline roadmap (future)
- **ansible/README.md** — Variable precedence and configuration structure
- **docs/** — DNS, Terraform, and SOPS workflow quick references

---

**Last Updated**: March 2026
