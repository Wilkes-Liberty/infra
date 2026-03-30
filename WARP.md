# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Scope
- This repo manages infrastructure for Wilkes Liberty using Docker Compose, Ansible, and Terraform
- **Current Architecture**: On-premises Mac Mini M4 Pro running Docker Compose stack (11 containers)
- **Future Architecture**: Njalla VPS for Next.js frontend, connected via Tailscale mesh to Mac Mini backend
- Includes Docker orchestration, infrastructure automation (Ansible), DNS management (Terraform), and monitoring (Prometheus/Grafana)

## Prerequisites
- **Docker Desktop** installed and running (required)
- **Ansible CLI** installed (for automated deployment)
- **community.sops** Ansible vars plugin and the sops/age tooling
  - Install the collection: `ansible-galaxy collection install community.sops`
  - Install community.general: `ansible-galaxy collection install community.general`
  - Have sops and age installed and your AGE private key available locally (e.g., `export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt`)
- **Terraform CLI** installed (for DNS management - optional initially)
- **Njalla API token** (for DNS record management - optional initially)

## Core Commands (run from repo root)

### Automated Deployment (Recommended)
- **Deploy complete on-prem stack** (one command - creates directories, configs, starts Docker):
  ```bash
  ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml
  ```

### Manual Docker Operations
- Start all services:
  ```bash
  cd ~/nas_docker && docker compose up -d
  ```
- Stop all services:
  ```bash
  cd ~/nas_docker && docker compose down
  ```
- View logs:
  ```bash
  cd ~/nas_docker && docker compose logs -f
  ```
- Check service status:
  ```bash
  cd ~/nas_docker && docker compose ps
  ```

### Ansible Operations
- Validate inventory:
  ```bash
  ansible-inventory -i ansible/inventory/hosts.ini --graph
  ```
- Test connectivity:
  ```bash
  ansible -i ansible/inventory/hosts.ini all -m ping
  ```
- Edit encrypted secrets (SOPS/age):
  ```bash
  sops ansible/inventory/group_vars/tailscale_secrets.yml
  sops ansible/inventory/group_vars/sso_secrets.yml
  ```

### Terraform Operations (DNS Management)
- Plan DNS changes
  - terraform plan
- Apply DNS changes
  - terraform apply
- View current DNS state
  - terraform show

## High-level Architecture and Orchestration

### Current Infrastructure (Phase 1 - On-Premises)
**Mac Mini M4 Pro** running **Docker Compose** with 11 containers:

**Application Services:**
- **Drupal 11** (port 8080): Headless CMS with GraphQL API
- **PostgreSQL 16** (internal): Primary database
- **Redis 7** (internal): Object caching
- **Keycloak** (port 8081): SSO and authentication
- **Apache Solr 9.6** (port 8983): Search engine

**Monitoring Stack:**
- **Prometheus** (port 9090): Metrics collection and alerting
- **Grafana** (port 3001): Dashboards and visualization
- **Alertmanager** (port 9093): Alert routing and notifications
- **Node Exporter** (port 9100): Host system metrics
- **cAdvisor** (port 8082): Container resource metrics
- **Postgres Exporter** (port 9187): Database performance metrics

**Resources:** ~13 CPUs, ~25GB RAM (well within M4 Pro capacity)

### Future Infrastructure (Phase 2 - Distributed)
- **Njalla VPS**: Next.js frontend, Caddy reverse proxy
- **Tailscale Mesh**: Secure tunnel between VPS and Mac Mini
- **Public DNS**: Managed via Terraform/Njalla

### Inventory Structure
**ansible/inventory/hosts.ini** contains:
- **wl-onprem**: Mac Mini M4 Pro (localhost) - primary backend server
- **njalla-vps**: Future frontend server (not yet provisioned)

All services run as Docker containers on wl-onprem, managed via docker-compose.yml

### Play Orchestration (ansible/playbooks)
- **onprem.yml**: Deploys complete Mac Mini stack (wl-onprem role)
  - Creates all required directories
  - Installs Docker Desktop, Tailscale, Proton VPN
  - Deploys docker-compose.yml and monitoring configs
  - Sets up automated backups via launchd
  - Starts Docker Compose stack
- **vps.yml**: Future Njalla VPS deployment (Next.js + Caddy)
- **letsencrypt.yml**: SSL certificate automation
- **monitoring.yml**: Monitoring stack configuration

### Ansible Roles (ansible/roles)

#### Active Roles
- **wl-onprem**: Mac Mini deployment orchestration
  - Installs Docker Desktop, Tailscale, Proton VPN
  - Creates all required directory structures
  - Deploys docker-compose.yml and monitoring configs
  - Sets up automated backups via launchd
  - Starts Docker Compose stack with 11 containers
- **common**: Base system configuration (for future VPS use)
  - System hardening and security
  - User management
  - Base package installation
- **tailscale**: Mesh VPN configuration (for future VPS→Mac Mini connectivity)
  - Automatic installation on hosts
  - Configurable auth keys, routes, hostnames
  - Supports subnet routing and exit nodes
  - See TAILSCALE_SETUP.md for setup
- **vps-proxy**: Njalla VPS reverse proxy (future)
  - Caddy configuration for Next.js + backend proxying
  - Let's Encrypt SSL automation
- **letsencrypt**: SSL certificate management (future)
- **monitoring**: Monitoring orchestration (currently integrated in Docker Compose)

#### Removed Roles (Phase 1 Cleanup)
The following roles were removed as their functionality is now provided by Docker Compose:
- ~~app~~ (Drupal now in Docker)
- ~~db~~ (PostgreSQL now in Docker)
- ~~solr~~ (Solr now in Docker)
- ~~authentik~~ (using Keycloak in Docker instead)
- ~~analytics_obs~~ (monitoring now in Docker)
- ~~cache~~ (edge caching deferred to Phase 2)
- ~~coredns~~ (using external DNS)
- ~~resolved~~ (not needed)
- ~~wireguard~~ (using Tailscale)

### Networking and DNS Architecture
- **Docker Networks** (internal):
  - `wl_frontend` (172.20.0.0/24): Public-facing services (Drupal, Keycloak)
  - `wl_backend` (172.21.0.0/24): Internal services (PostgreSQL, Redis, Solr)
  - `wl_monitoring` (172.22.0.0/24): Monitoring stack isolation
- **Public DNS**: Managed via Terraform/Njalla (future)
  - Domain: wilkesliberty.com
  - A/AAAA records for services
  - CNAME records for aliases
- **VPN Layers**:
  - **Outer**: Proton VPN (kill-switch, always-on)
  - **Inner**: Tailscale mesh (100.64.0.0/10) for future VPS↔Mac Mini connectivity
  - Automatic peer discovery and NAT traversal

## Configuration Management

### Variable Structure
- **Primary group_vars**: ansible/inventory/group_vars/all.yml
- **Host-specific**: ansible/inventory/host_vars/wl-onprem.yml (if needed)
- **Docker environment**: docker/.env (passwords, SMTP, backup settings)

### Secrets Management (SOPS/age)
- Ansible configured to load SOPS-encrypted vars (ansible/ansible.cfg: vars_plugins_enabled includes community.sops)
- .sops.yaml encrypts any ansible/inventory/group_vars/*_secrets.yml file for specific age recipient
- Current encrypted files: sso_secrets.yml, tailscale_secrets.yml
- Use sops to edit; decryption requires your local AGE key
- Never commit plaintext secrets to repository
- **See SECRETS_MANAGEMENT.md for complete guide**

### Terraform State and Secrets
- DNS management via Njalla API
- API tokens stored in terraform.tfvars (not committed)
- Proton Mail DKIM configuration variables

## Infrastructure Status (Updated March 2026)

### ✅ COMPLETED (Production Ready)

#### Phase 1-2: Infrastructure Modernization
- ✅ **Simplified inventory** - Reduced from 9 hosts to 2 (wl-onprem + njalla-vps)
- ✅ **Removed conflicting roles** - Eliminated 9 roles now handled by Docker Compose
- ✅ **Docker Compose stack** - 11 containers with health checks and monitoring
- ✅ **Enterprise monitoring** - Prometheus, Grafana, Alertmanager with 16 alert rules
- ✅ **Automated backups** - Daily backups with 90-day retention via launchd
- ✅ **Network segmentation** - Three Docker networks for security isolation
- ✅ **Comprehensive documentation** - 677-line deployment checklist

#### Phase 3-4: Operational Readiness
- ✅ **Backup automation** - backup-onprem.sh with encryption and retention
- ✅ **Alert configuration** - 16 rules (5 critical, 7 warning, 4 info)
- ✅ **Grafana integration** - Prometheus datasource and dashboard provisioning
- ✅ **Environment templating** - .env.example with secure defaults

### Current Infrastructure Health: ✅ READY TO DEPLOY

## Current Operational Status

### ✅ Production-Ready Components
- **Docker Compose Stack**: 11 containers (Drupal, PostgreSQL, Redis, Keycloak, Solr, monitoring)
- **Enterprise Monitoring**: Prometheus/Grafana/Alertmanager with 16 alert rules
- **Automated Backups**: Daily backups with 90-day retention via launchd
- **Automated Deployment**: Single playbook deploys entire stack
- **Network Security**: Three-tier Docker network isolation
- **Secrets Management**: SOPS/AGE encryption for sensitive variables

### ⚠️ Functional Notes
- **Application separation**: Drupal application is not in this repo; local dev uses ddev in separate app codebase
- **Tailscale Setup**: Generate auth key at https://login.tailscale.com/admin/settings/keys and store in SOPS-encrypted tailscale_secrets.yml
- **VPS Deployment**: Njalla VPS (Next.js frontend) is future Phase 2 work
- **DNS Management**: External DNS via Terraform/Njalla (optional for initial deployment)

## Development Roadmap

### Phase 1: On-Premises Production (COMPLETE ✅)
1. ✅ **Docker Compose stack** - 11 containers deployed
2. ✅ **Monitoring** - Prometheus, Grafana, Alertmanager configured
3. ✅ **Backups** - Automated with retention management
4. ✅ **Deployment automation** - Single command deployment
5. ✅ **Documentation** - Comprehensive guides created

### Phase 1.5: Final Pre-Production Tasks (NEXT)
1. **Grafana Dashboards** - Import community dashboards for infrastructure/application monitoring
2. **Test Restore** - Create test-restore.sh script for disaster recovery validation
3. **Performance Baseline** - Run for 7 days and document normal operating metrics
4. **Operational Runbooks** - Service restart, troubleshooting, security incident procedures
5. **Terraform DNS** - Simplify for single-environment pattern (optional)

### Phase 2: Multi-Environment Infrastructure (Future)
Once production is stable, expand to staging and development environments:

#### Phase 2a: Staging Environment
1. **Production-like testing environment**
   - Full stack deployment validation
   - Blue/green deployment testing
   - Performance and load testing
   - Security scanning in prod-like environment

2. **Staging-specific configuration**
   - Staging DNS subdomain (staging.wilkesliberty.com)
   - Production-scale instance sizes
   - Production security model (isolated network)
   - Full monitoring and alerting
   - Automated deployment from main branch

#### Phase 2b: Development Environment
1. **Rapid development and feature testing**
   - Individual developer environments
   - Feature branch deployments
   - Integration testing
   - Database migration testing

2. **Development-specific configuration**
   - Development DNS subdomain (dev.wilkesliberty.com)
   - Smaller instance sizes for cost optimization
   - Relaxed security settings for debugging
   - Shared services where appropriate
   - Basic monitoring

#### Phase 2c: Multi-Environment Structure
1. **Infrastructure organization**
   - Migrate Terraform to `environments/prod/`, `environments/staging/`, `environments/dev/`
   - Create shared Terraform modules for common patterns
   - Separate Ansible inventories for each environment

2. **GitHub Actions CI/CD pipeline** (Currently disabled while building infrastructure)
   - **Development**: ~~Auto-deploy~~ Manual deploy only (workflow_dispatch)
   - **Staging**: ~~Auto-deploy~~ Manual deploy only (workflow_dispatch)  
   - **Production**: Manual deploy only with confirmation (workflow_dispatch)
   - Infrastructure validation and compliance checks
   - Rollback capabilities at each stage
   - **Note**: Auto-deployment triggers are commented out until infrastructure is complete

### Migration to Multi-Environment
When ready to add staging and development environments:
```bash
# Preview migration changes
./scripts/migrate-to-multi-env.sh --dry-run

# Execute migration (when staging/dev servers are ready)
./scripts/migrate-to-multi-env.sh
```

The migration script will:
- ✅ Backup current production setup
- ✅ Create `environments/prod/`, `environments/staging/`, and `environments/dev/` structure
- ✅ Generate shared Terraform modules for DNS, mail, and infrastructure
- ✅ Set up environment-specific configuration
- ✅ Update documentation and validate new structure

### GitHub Actions Deployment Flow (Manual Only - Building Phase)
```
Feature Branch → development → staging → master
     ↓              ↓           ↓        ↓
   Pull Request    Manual Only  Manual Only Manual Only
   Unit Tests     workflow_    workflow_   workflow_
   Code Review    dispatch     dispatch    dispatch
```

**Current Triggers** (Auto-deployment disabled):
- ~~Push to `development`~~ → Manual trigger only (workflow_dispatch)
- ~~Merge `dev` → `staging`~~ → Manual trigger only (workflow_dispatch)  
- ~~Merge `staging` → `master`~~ → Manual trigger with confirmation required

**Future Triggers** (When infrastructure is complete):
- Push to `development` → Deploy to dev environment
- Merge `dev` → `staging` → Deploy to staging environment  
- Merge `staging` → `master` → Manual approval + production deployment

## Manual Deployment (Current Phase)

While auto-deployments are disabled, use GitHub's Actions tab to manually trigger deployments:

### Manual Deployment via GitHub UI
1. Go to **Actions** tab in GitHub repository
2. Select the desired workflow:
   - "Deploy to Development"
   - "Deploy to Staging" 
   - "Deploy to Production"
3. Click **"Run workflow"**
4. **Important**: Type `deploy` in the confirmation field
5. For production: Optionally check "emergency deployment" to skip pre-checks
6. Click **"Run workflow"** to start

### Manual Deployment via CLI
```bash
# Trigger development deployment
gh workflow run "Deploy to Development" --field confirm_deployment=deploy

# Trigger staging deployment  
gh workflow run "Deploy to Staging" --field confirm_deployment=deploy

# Trigger production deployment
gh workflow run "Deploy to Production" --field confirm_deployment=deploy

# Emergency production deployment (skips pre-checks)
gh workflow run "Deploy to Production" --field confirm_deployment=deploy --field emergency_deployment=true
```

**Note**: All deployments require explicit confirmation to prevent accidental deployments.

## Infrastructure Management Commands

### Validation and Testing
```bash
# Verify inventory structure
ansible-inventory -i ansible/inventory/hosts.ini --graph

# Test variable resolution for specific host
ansible-inventory -i ansible/inventory/hosts.ini --host wl-onprem

# Test connectivity
ansible -i ansible/inventory/hosts.ini all -m ping

# Test backup script
./scripts/backup-onprem.sh --dry-run
```

### Infrastructure Deployment
```bash
# Deploy complete on-prem stack (automated)
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml

# Manual Docker operations
cd ~/nas_docker
docker compose up -d        # Start all services
docker compose ps           # Check status
docker compose logs -f      # View logs
docker compose down         # Stop all services
```

### Terraform DNS Management (Optional)
```bash
# Plan DNS changes
terraform plan

# Apply DNS records
terraform apply

# View current state
terraform show
```

## Recent Improvements (March 2026)

### Infrastructure Fixes Completed
- ✅ Simplified inventory from 9 hosts to 2 (wl-onprem + njalla-vps)
- ✅ Removed 9 conflicting Ansible roles (now handled by Docker Compose)
- ✅ Created comprehensive Docker Compose stack with 11 containers
- ✅ Implemented enterprise monitoring (Prometheus/Grafana/Alertmanager)
- ✅ Automated backup system with 90-day retention
- ✅ Enhanced wl-onprem role for fully automated deployment
- ✅ Updated all documentation to reflect Docker-first architecture

### Repository Health
- **Technical Debt**: Eliminated
- **Documentation**: Comprehensive and current
- **Infrastructure**: Production-ready foundation
- **Automation**: Single-command deployment
- **Security**: SOPS encryption properly configured
