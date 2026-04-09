# Multi-Environment Strategy

**Status**: Production and staging environments are operational. This document describes the current architecture and the path forward for CI/CD automation.

## Current Architecture

### Environment Overview

| Environment | Backend (Drupal) | Frontend (Next.js) | Where |
|-------------|-----------------|-------------------|-------|
| **Local dev** | DDEV | `npm run dev` | Developer machine |
| **Staging** | Docker on on-prem server | Docker on on-prem server | `~/nas_docker_staging/` |
| **Production** | Docker on on-prem server | Docker on Njalla VPS | `~/nas_docker/` + VPS |

Developers never need to touch the staging or production Docker stacks directly — they work locally and push to the appropriate branch.

### on-prem server Co-location

Production and staging run side by side on the on-prem server with no resource conflict:

```
on-prem server (24 GB RAM, ~13 CPUs)
├── Production Stack:  ~/nas_docker/          ~8-10 GB RAM allocated
├── Staging Stack:     ~/nas_docker_staging/  ~4-6 GB RAM allocated
├── Monitoring (shared): Prometheus/Grafana   ~2 GB RAM allocated
└── Headroom remaining: ~6-10 GB for OS + overhead
```

### Port Assignments

| Service | Production | Staging |
|---------|-----------|---------|
| Drupal | 8080 | 8090 |
| Keycloak | 8081 / 9000 | 8091 / 9001 |
| Solr | 8983 | 8993 |
| Next.js | — (on VPS) | 3010 |
| Prometheus | 9090 | shared |
| Grafana | 3001 | shared |

### Source Branches

| Environment | webcms branch | ui branch |
|-------------|-------------|---------|
| Staging | `staging` | `staging` |
| Production | `main` | `main` |

Staging repos live at `~/Repositories/staging/{webcms,ui}` (separate clones from production at `~/Repositories/{webcms,ui}`).

### Monitoring Strategy

A single Prometheus/Grafana/Alertmanager stack (production ports) monitors both environments. Staging containers join the shared `wl_monitoring` Docker network and are auto-discovered via container labels.

Staging alerts are labeled with `environment=staging` so they can be filtered or routed differently in Alertmanager if needed.

## Development Workflow

### Branch Strategy

```
feature/* ──→ main ──→ staging branch ──→ (Ansible redeploy)
                │
                └──→ Direct to production (after staging validation)
```

For the current team size, the workflow is:
1. Feature branches → pull request → merge to `main`
2. Periodically sync `staging` branch from `main` and redeploy staging
3. After staging validation, production redeploy via Ansible playbook

No CI/CD automation yet — all deployments are manual Ansible runs. See the roadmap section below.

### Developer Local Setup

**Drupal (webcms)**:
```bash
cd webcms
ddev start
ddev composer install
ddev drush cim -y  # Import config from config/sync/
```

**Next.js (ui)**:
```bash
cd ui
cp .env.example .env.local
# Edit .env.local with local Drupal URL
npm install
npm run dev
```

### Deploying to Staging

```bash
# On on-prem server: update staging repos and rebuild
cd ~/Repositories/staging/webcms && git pull origin staging
cd ~/Repositories/staging/ui && git pull origin staging

cd ~/nas_docker_staging
docker compose up -d --build

# Or via Ansible (re-runs entire role, handles everything)
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml
```

### Deploying to Production

```bash
# Pull latest on on-prem server
cd ~/Repositories/webcms && git pull origin main
cd ~/Repositories/ui && git pull origin main

# Rebuild and restart
cd ~/nas_docker
docker compose up -d --build

# Njalla VPS — Next.js rebuild (if VPS role is ready)
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/vps.yml
```

## DNS Strategy

```
Production:  wilkesliberty.com, www.wilkesliberty.com
Staging:     staging.wilkesliberty.com (when external access is needed)
API (int):   drupal.int.wilkesliberty.com (Tailscale-routed)
```

DNS is managed via Terraform + Njalla API. See `DNS_RECORDS.md` and `docs/TERRAFORM_DNS_QUICKSTART.md`.

## Security Model

**Production**: Full security — Keycloak in `start` mode, Redis with allkeys-lru (no AOF), Drupal with production services YAML (`web/sites/production.services.yml`), Tailscale for VPS→on-prem server.

**Staging**: Production security model — same Keycloak config, same network isolation, reduced resource limits. Staging containers are on isolated `wl_stg_frontend` / `wl_stg_backend` networks, only the monitoring port bridges to production network.

**Local**: DDEV handles everything; Drupal loads `development.services.yml` (Twig debug, relaxed CORS, null cache backends).

## Backup Strategy

| Environment | Automated | Retention | Storage |
|-------------|-----------|---------|---------|
| Production | Daily 04:00 AM (launchd) | 90 days | `~/Backups/wilkesliberty/` |
| Staging | On-demand only | N/A | Not backed up by default |

Backups cover: PostgreSQL databases (prod + staging), Drupal files, configuration.

## CI/CD Roadmap

Automated deployments are not yet configured — all deploys are manual Ansible runs. The target pipeline when ready:

```
Push to staging branch
    → GitHub Actions: build Docker images
    → Pull and rebuild on on-prem server staging stack
    → Run smoke tests
    → Notify team

Push to main branch (after PR review)
    → GitHub Actions: build Docker images
    → Manual approval gate
    → Deploy to production on-prem server + Njalla VPS
```

See **GITHUB_ACTIONS_STRATEGY.md** for the detailed pipeline design.

For now, use the manual commands in the "Deploying to Staging / Production" sections above.

---

**Last Updated**: March 2026
