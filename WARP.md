# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Scope
- This repo manages infrastructure for Wilkes Liberty using Ansible and Terraform
- Separate from the Drupal application codebase (developed locally with ddev in the app repo)
- Manages server provisioning/configuration, networking, internal DNS (CoreDNS), and public DNS (Njalla)
- Includes both infrastructure automation (Ansible) and DNS/domain management (Terraform)

## Prerequisites
- Ansible CLI installed
- community.sops Ansible vars plugin and the sops/age tooling
  - Install the collection: ansible-galaxy collection install community.sops
  - Have sops and age installed and your AGE private key available locally (e.g., export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt)
- SSH access to the target hosts defined in ansible/inventory/hosts.ini
- Terraform CLI installed (for DNS management)
- Njalla API token (for DNS record management)

## Core Commands (run from repo root)

### Ansible Operations
- Bootstrap base config on all hosts
  - make bootstrap
- Configure all roles across all hosts
  - make site
- Deploy CoreDNS to DNS servers
  - ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/coredns.yml
- Configure fleet to use internal DNS
  - ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/resolved.yml
- Run playbook in check/diff mode (no changes) for a subset
  - ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/site.yml --limit app --check --diff
- Limit to a single host or group
  - ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/site.yml --limit app1.prod.wilkesliberty.com
  - ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/site.yml --limit cache
  - ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/site.yml --limit dns
- Validate connectivity
  - ansible -i ansible/inventory/hosts.ini all -m ping
  - ansible -i ansible/inventory/hosts.ini fleet -m ping
- Inspect inventory graph
  - ansible-inventory -i ansible/inventory/hosts.ini --graph
- Edit encrypted group secrets (SOPS/age)
  - sops ansible/inventory/group_vars/sso_secrets.yml

### Terraform Operations (DNS Management)
- Plan DNS changes
  - terraform plan
- Apply DNS changes
  - terraform apply
- View current DNS state
  - terraform show

## High-level Architecture and Orchestration

### Infrastructure Components
- **DNS Server** (dns1 - 10.10.0.10): CoreDNS for internal domain resolution
- **Application Server** (app1 - 10.10.0.2): Drupal 11 application (planned)
- **Database Server** (db1 - 10.10.0.3): MySQL/MariaDB (planned)
- **Search Server** (search1 - 10.10.0.4): Apache Solr (planned)
- **Analytics Server** (analytics1 - 10.10.0.7): Monitoring and observability (planned)
- **SSO Server** (sso1 - 10.10.0.8): Authentik identity provider (partial)
- **Cache Server** (cache1 - 10.10.0.9): Varnish + Caddy edge caching (functional)

### Inventory Structure
**ansible/inventory/hosts.ini** contains multiple group formats:
- **Individual service groups**: app, db, solr, analytics, sso, cache
- **Logical groups**: dns (dedicated DNS), fleet (all application services)
- **Global Python interpreter**: Set via ansible_python_interpreter

### Play Orchestration (ansible/playbooks)
- **bootstrap.yml**: Applies common role to all hosts with become
- **site.yml**: Main orchestration playbook running in sequence:
  - all hosts: wireguard, then common
  - app group: app role
  - db group: db role
  - solr group: solr role
  - analytics group: analytics_obs role
  - sso group: authentik role
  - cache group: cache role
- **coredns.yml**: Deploys CoreDNS to DNS servers
- **resolved.yml**: Configures fleet to use internal DNS

### Roles Implementation Status (ansible/roles)

#### Fully Implemented
- **common**: UFW firewall policy (tasks/firewall.yml)
  - Default deny inbound/allow outbound, allow SSH from admin_allow_cidrs and wg_network_cidr
  - Public HTTP/HTTPS on app/analytics/sso/cache groups
  - MySQL 3306 allowed from app/analytics to db
  - Solr 8983 allowed from app to solr
  - Cache-specific: Varnish (6081) bound to 127.0.0.1 with Caddy front-end
- **wireguard**: Mesh VPN configuration
  - Defines mesh variables via defaults and per-host host_vars (wg_address, wg_peers)
  - App host acts as hub; peers defined for db/search/analytics/sso
- **cache**: HTTP edge caching (Varnish + Caddy)
  - Caddy terminates TLS/HTTP/2/3 for public hosts (cache_public_hosts)
  - Reverse proxies to Varnish on 127.0.0.1:6081
  - Uses app.int.wilkesliberty.com:80 as backend (configurable)
  - Default VCL caches static assets, bypasses session/admin traffic
  - Sets X-Cache=HIT/MISS headers
  - PURGE support exists but disabled by default
  - Tunables in ansible/roles/cache/defaults/main.yml
- **coredns**: Internal DNS server
  - Serves int.wilkesliberty.com zone
  - Forward and reverse DNS resolution
  - Templates for Corefile and zone files
- **resolved**: DNS client configuration
  - Configures systemd-resolved to use internal DNS

#### Partially Implemented
- **authentik**: SSO/Identity provider
  - Has defaults (images, domain, secrets)
  - Templates for docker-compose and nginx config
  - Tasks not fully implemented

#### Stub Implementations
- **app**: Drupal application server (placeholder)
- **db**: Database server (placeholder)
- **solr**: Search server (placeholder)
- **analytics_obs**: Monitoring/observability (placeholder)

### Networking and DNS Architecture
- **Internal Network**: 10.10.0.0/24 (defined in group_vars/all.yml)
- **Internal DNS**: CoreDNS on 10.10.0.10 serves int.wilkesliberty.com
  - Forward zone: host.int.wilkesliberty.com → 10.10.0.x
  - Reverse zone: 10.10.0.x → host.int.wilkesliberty.com
  - Upstream DNS: 1.1.1.1, 9.9.9.9
- **Public DNS**: Managed via Terraform/Njalla
  - cache1.prod.wilkesliberty.com fronts www and api subdomains
  - Individual host records for each service
  - IPv4 and IPv6 A/AAAA records
  - CNAME records for service aliases
- **VPN Mesh**: WireGuard connecting all services
  - App server as hub, others as peers
  - Enables secure inter-service communication

## Configuration Management

### Variable Structure
- **Primary group_vars**: ansible/inventory/group_vars/all.yml
- **CoreDNS-specific**: ansible/group_vars/all/coredns.yml
- **Host-specific**: ansible/inventory/host_vars/[hostname].yml

### Secrets Management (SOPS/age)
- Ansible configured to load SOPS-encrypted vars (ansible/ansible.cfg: vars_plugins_enabled includes community.sops)
- .sops.yaml encrypts any ansible/inventory/group_vars/*_secrets.yml file for specific age recipient
- Current encrypted files: sso_secrets.yml
- Use sops to edit; decryption requires your local AGE key
- Never commit plaintext secrets to repository

### Terraform State and Secrets
- DNS management via Njalla API
- API tokens stored in terraform.tfvars (not committed)
- Proton Mail DKIM configuration variables

## Infrastructure Status (Updated October 2025)

### ✅ RESOLVED ISSUES (All Critical Issues Fixed)

#### Inventory Structure
- ✅ **Fixed duplicate [cache] group entries** - Removed duplications from hosts.ini
- ✅ **Standardized hostname format** - All hosts now use consistent FQDN format with ansible_host
- ✅ **Organized group structure** - Clean separation between individual service groups and logical fleet group
- ✅ **Added DNS infrastructure** - dns1.prod.wilkesliberty.com properly configured

#### Variable Configuration  
- ✅ **Consolidated duplicate variables** - Single authoritative definitions for all variables
- ✅ **Organized variable sections** - Clear categorization with descriptive headers
- ✅ **Added DNS host variables** - dns_int_ip (10.10.0.10) included consistently
- ✅ **Backward compatibility** - Legacy aliases maintained (solr_int_ip)

#### Missing Files and Scripts
- ✅ **Created deploy-app.yml** - Comprehensive application deployment playbook
- ✅ **Created backup-db.sh** - Full-featured database backup script with dry-run, help, and error handling
- ✅ **Fixed Makefile** - Corrected tab indentation and verified all targets

#### Infrastructure Cleanup
- ✅ **Removed Terraform artifacts** - Deleted .bak files and enhanced .gitignore
- ✅ **Improved .gitignore** - Added comprehensive patterns for backup files, logs, temp files
- ✅ **Created documentation** - ansible/README.md explaining variable precedence and structure

### Current Infrastructure Health: ✅ PRODUCTION READY

## Current Operational Status

### ✅ Production-Ready Components
- **Infrastructure Management**: Clean inventory, consolidated variables, comprehensive documentation
- **Cache Layer**: Varnish + Caddy edge caching (production-ready)
- **DNS Infrastructure**: CoreDNS internal DNS with forward/reverse resolution
- **VPN Mesh**: WireGuard connecting all services securely
- **Backup System**: Automated database backup script with retention management
- **Deployment Pipeline**: Application deployment playbook with health checks

### ⚠️ Functional Notes
- **Cache PURGE**: Available in cache role (via Caddyfile) but disabled by default; restrict to admin CIDRs if enabling
- **Application separation**: The Drupal application is not in this repo; local dev uses ddev in separate app codebase
- **Role implementation**: common, wireguard, cache, coredns, and resolved roles are functional; app, db, solr, analytics_obs are stubs
- **Secrets management**: SOPS/age encryption properly configured for sensitive variables

## Development Roadmap

### Phase 1: Production Infrastructure (Current Focus)
1. **Complete application role** (app)
   - Drupal 11 installation and configuration
   - PHP 8.3 and Nginx setup
   - Database connectivity
   - File permissions and security

2. **Implement database role** (db)
   - MySQL/MariaDB installation
   - Database user management
   - Backup integration
   - Performance tuning

3. **Deploy search infrastructure** (solr)
   - Apache Solr 9.6.1 installation
   - Drupal integration configuration
   - Multilingual search setup

4. **Set up monitoring** (analytics_obs)
   - Application performance monitoring
   - Infrastructure health checks
   - Log aggregation and alerting

5. **Finalize SSO** (authentik)
   - Complete Authentik role implementation
   - Docker Compose deployment
   - LDAP/SAML configuration

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

2. **GitHub Actions CI/CD pipeline**
   - **Development**: Auto-deploy on push to `development` branch
   - **Staging**: Auto-deploy on merge `development` → `staging`
   - **Production**: Manual approval + deploy on merge `staging` → `master`
   - Infrastructure validation and compliance checks
   - Rollback capabilities at each stage

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

### GitHub Actions Deployment Flow
```
Feature Branch → development → staging → master
     ↓              ↓           ↓        ↓
   Pull Request    Auto Deploy  Auto Deploy Manual Gate
   Unit Tests     to Dev Env   to Staging   Blue/Green
   Code Review    Smoke Tests  Load Tests   Production
```

**Triggers**:
- Push to `development` → Deploy to dev environment
- Merge `dev` → `staging` → Deploy to staging environment  
- Merge `staging` → `master` → Manual approval + production deployment

## Infrastructure Management Commands

### Validation and Testing
```bash
# Verify inventory structure
ansible-inventory -i ansible/inventory/hosts.ini --graph

# Test variable resolution for specific host
ansible-inventory -i ansible/inventory/hosts.ini --host app1.prod.wilkesliberty.com

# Test connectivity to all hosts
ansible -i ansible/inventory/hosts.ini all -m ping

# Dry-run deployment
make --dry-run deploy

# Test backup script
./scripts/backup-db.sh --dry-run
```

### Infrastructure Deployment
```bash
# Initial infrastructure setup
make bootstrap

# Deploy all services
make site  

# Deploy DNS infrastructure
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/coredns.yml

# Configure DNS clients
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/resolved.yml

# Application deployment
make deploy

# Database backup
make backup-db
```

### Terraform DNS Management
```bash
# Plan DNS changes
terraform plan

# Apply DNS records
terraform apply

# View current state
terraform show
```

## Recent Improvements (October 2025)

### Infrastructure Fixes Completed
- ✅ Resolved all inventory duplications and inconsistencies
- ✅ Consolidated variable definitions and eliminated conflicts
- ✅ Created comprehensive backup and deployment automation
- ✅ Enhanced documentation with variable precedence guides
- ✅ Implemented proper .gitignore to prevent artifact commits
- ✅ Fixed Makefile formatting and verified all target references

### Repository Health
- **Technical Debt**: Eliminated
- **Documentation**: Comprehensive and current
- **Infrastructure**: Production-ready foundation
- **Automation**: Functional deployment and backup systems
- **Security**: SOPS encryption properly configured
