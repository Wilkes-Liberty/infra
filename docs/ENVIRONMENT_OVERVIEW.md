# Environment Overview
## Wilkes Liberty — How Everything Fits Together

**Last Updated**: April 2026

This document is the starting point for anyone working on the Wilkes Liberty stack. It explains how the three repositories relate to each other, how the environments work, and how changes move from local development to production.

---

## The Three Repositories

| Repo | What it is | Who works in it |
|------|-----------|-----------------|
| `infra` | Infrastructure — Docker Compose, Ansible, Terraform, CoreDNS | DevOps / you |
| `webcms` | Drupal 11 headless CMS — content types, GraphQL API, modules | Backend devs |
| `ui` | Next.js 15 frontend — fetches content from Drupal via GraphQL | Frontend devs |

They live as siblings on disk:

```
~/Repositories/
├── infra/       ← infrastructure definitions
├── webcms/      ← Drupal CMS source (build context for Docker)
└── ui/          ← Next.js frontend source (build context for Docker)
```

**Important:** The Docker images for production are built from `webcms` and `ui` source code. The `infra/docker/` Dockerfiles use `../..` as the build context, so all three repos must be siblings on the on-prem server at `~/Repositories/`.

---

## Two-Host Architecture

```
Internet
   │
   ▼
Cloud VPS  ──── Tailscale VPN ────  On-prem server
(Caddy, Next.js)                    (Docker Compose — 11 containers)
   │                                       │
   │  proxy /api/* → Tailscale:8080        ├── Drupal 11 (webcms)
   │  proxy /auth/* → Tailscale:8081       ├── PostgreSQL
   │  serve /* → Next.js (local)           ├── Redis
                                           ├── Keycloak SSO
                                           ├── Solr
                                           └── Prometheus/Grafana/Alertmanager
```

- The **cloud VPS** is the only host with public ports (80, 443). Everything else is private.
- The **on-prem server** runs all backend services and is only reachable over Tailscale.
- Internal admin URLs (`*.int.wilkesliberty.com`) are served by CoreDNS on the on-prem server, reachable only over Tailscale.

---

## The Three Environments

### Local Development

Each repo runs independently on a developer's machine:

| Repo | How to run locally | Local URL |
|------|--------------------|-----------|
| `webcms` | `ddev start` | `https://cms.ddev.site` |
| `ui` | `npm run dev` | `http://localhost:3000` |
| `infra` | Not run locally — used to deploy | n/a |

For local full-stack development, point the `ui` at the local DDEV Drupal instance:
```bash
# ui/.env.local
NEXT_PUBLIC_DRUPAL_BASE_URL=https://cms.ddev.site
NEXT_IMAGE_DOMAIN=cms.ddev.site
```

### Staging

Runs on the on-prem server as a second Docker Compose stack (`~/nas_docker_staging/`), built from the `staging` branch of each repo. Ports are offset from production (8090/8091 for Drupal/Keycloak, 3010 for Next.js). Accessible internally over Tailscale.

### Production

Runs on the on-prem server (`~/nas_docker/`) with the cloud VPS as the public-facing ingress. The cloud VPS proxies API/auth traffic over Tailscale to on-prem and serves Next.js directly.

---

## Branch Strategy

All three repos follow the same branching model:

```
master ─────────────────────────────────────── production
  └── staging ──────────────────────────── staging environment
        └── feature/your-feature ───────── your local work
```

| Branch | Purpose | Who merges |
|--------|---------|------------|
| `feature/*` | Active development | Author (after PR review) |
| `staging` | Integration testing | Team lead, after PR from feature |
| `master` | Production | Team lead, after staging verification |

**Rule:** Never push directly to `master` or `staging`. Always open a PR.

---

## How a Change Reaches Production

### webcms (Drupal)

1. Developer creates `feature/` branch, makes changes (code + config export)
2. PR opened against `staging` — reviewed and merged
3. Staging Docker image rebuilt on on-prem: `cd ~/nas_docker_staging && docker compose up -d --build drupal`
4. QA on `https://stg-api.int.wilkesliberty.com` (Tailscale required)
5. PR opened from `staging` → `master` — reviewed and merged
6. Production image rebuilt: `cd ~/nas_docker && docker compose build --no-cache drupal && docker compose up -d drupal`

### ui (Next.js)

1. Same branch/PR flow as above
2. Staging rebuild: `cd ~/nas_docker_staging && docker compose up -d --build nextjs`
3. QA on `https://stg.int.wilkesliberty.com` (Tailscale required)
4. Production rebuild on the **cloud VPS** (Next.js runs there, not on-prem):
   ```bash
   # SSH to VPS
   ssh root@<vps-ip>
   cd ~/ui && git pull origin master
   npm run build
   pm2 restart nextjs   # or via Caddy/systemd
   ```
   *(Until CI/CD is in place, this is done manually after merging to main.)*

### infra

Infrastructure changes (Docker Compose, Ansible, Terraform) are applied manually:
- Docker/Ansible changes: `ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml`
- DNS changes: `source scripts/load-terraform-secrets.sh && terraform apply`
- VPS config: `ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/vps.yml`

---

## Secrets and Access

| Secret type | Location | How to use |
|------------|----------|------------|
| Docker env vars | `~/nas_docker/.env` (never committed) | Copy from `docker/.env.example`, fill in |
| Ansible secrets | `ansible/inventory/group_vars/*_secrets.yml` (SOPS-encrypted) | `sops <file>` to edit |
| Network IPs | `ansible/inventory/group_vars/network_secrets.yml` (SOPS-encrypted) | `sops <file>` to edit |
| Terraform secrets | `terraform_secrets.yml` (SOPS-encrypted) | `source scripts/load-terraform-secrets.sh` |
| SOPS AGE key | `~/.config/sops/age/keys.txt` (never committed) | Provided by team lead |

Developers working only on `webcms` or `ui` do not need SOPS access. Only those deploying infrastructure do.

---

## Key URLs

### Public (no VPN required)
| URL | Service |
|-----|---------|
| `https://www.wilkesliberty.com` | Next.js frontend |
| `https://api.wilkesliberty.com` | Drupal JSON:API / GraphQL |
| `https://auth.wilkesliberty.com` | Keycloak SSO |

### Internal (Tailscale required)
| URL | Service |
|-----|---------|
| `https://app.int.wilkesliberty.com` | Drupal admin |
| `https://sso.int.wilkesliberty.com` | Keycloak admin |
| `https://monitor.int.wilkesliberty.com` | Grafana dashboards |
| `https://metrics.int.wilkesliberty.com` | Prometheus |
| `https://alerts.int.wilkesliberty.com` | Alertmanager |
| `https://uptime.int.wilkesliberty.com` | Uptime Kuma |

---

## Related Documentation

| Document | Where | Purpose |
|----------|-------|---------|
| `DEPLOYMENT_CHECKLIST.md` | `infra/` | Step-by-step first deployment guide |
| `SECRETS_MANAGEMENT.md` | `infra/` | SOPS + AGE encryption guide |
| `TAILSCALE_SETUP.md` | `infra/` | VPN mesh configuration |
| `DNS_RECORDS.md` | `infra/` | DNS record reference |
| `docs/local-development.md` | `webcms/` | DDEV setup for Drupal |
| `CONTRIBUTING.md` | `webcms/` | Drupal developer workflow |
| `CONTRIBUTING.md` | `ui/` | Next.js developer workflow |
| `CONTRIBUTING.md` | `infra/` | Infrastructure change process |
