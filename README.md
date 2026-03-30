# Wilkes Liberty Infrastructure

This repository contains the infrastructure automation and configuration for the Wilkes Liberty web platform, a multilingual Drupal 11 site with headless capabilities.

## Architecture Overview

**Current Infrastructure**: On-premises Mac Mini M4 Pro running Docker Compose with 11 containers.

### Application Services:
- **Drupal 11** (port 8080) - Headless CMS with GraphQL API
- **PostgreSQL 16** - Primary database
- **Redis 7** - Object caching
- **Keycloak** (port 8081) - SSO and authentication
- **Apache Solr 9.6** (port 8983) - Full-text search

### Monitoring Stack:
- **Prometheus** (port 9090) - Metrics collection and alerting
- **Grafana** (port 3001) - Dashboards and visualization
- **Alertmanager** (port 9093) - Alert routing and notifications
- **Node Exporter** (port 9100) - Host system metrics
- **cAdvisor** (port 8082) - Container resource metrics
- **Postgres Exporter** (port 9187) - Database performance metrics

### Network Configuration

- **Primary Domain**: `wilkesliberty.com`
- **Docker Networks**:
  - `wl_frontend` (172.20.0.0/24) - Public-facing services
  - `wl_backend` (172.21.0.0/24) - Internal services
  - `wl_monitoring` (172.22.0.0/24) - Monitoring isolation
- **VPN Layers**:
  - Proton VPN (outer kill-switch layer)
  - Tailscale mesh (100.64.0.0/10) for future VPS connectivity

**Resources**: ~13 CPUs, ~25GB RAM (well within Mac Mini M4 Pro capacity)

## Directory Structure

```
infra/
├── ansible/           # Ansible automation
│   ├── files/         # Static files for deployment
│   ├── inventory/     # Server inventory and variables
│   ├── playbooks/     # Ansible playbooks
│   ├── roles/         # Ansible roles for each service
│   └── templates/     # Configuration templates
├── coredns/          # CoreDNS configuration (static files)
├── scripts/          # Utility scripts (backup-db.sh)
├── *.tf              # Terraform configuration files (DNS management)
├── terraform.tfvars  # Terraform variables (not committed)
├── .terraform/       # Terraform working directory (gitignored)
└── Makefile          # Common tasks automation
```

## Ansible Roles

### Active Roles

- **`wl-onprem`** - Mac Mini deployment (creates dirs, deploys Docker stack, configures backups)
- **`common`** - Base system configuration (for future VPS use)
- **`tailscale`** - VPN mesh configuration (for future VPS↔Mac Mini)
- **`vps-proxy`** - Njalla VPS reverse proxy (future)
- **`letsencrypt`** - SSL certificate management (future)
- **`monitoring`** - Monitoring orchestration (currently in Docker Compose)

## Quick Start

### Prerequisites

- Ansible installed locally
- SSH access to target servers
- Proton VPN or equivalent for secure access
- sops and age installed; export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
- Ansible collection community.sops installed (ansible-galaxy collection install community.sops)

### Setup

1. **Configure Inventory**
   ```bash
   # Edit server IPs and hostnames
   vi ansible/inventory/hosts.ini
   ```

2. **Configure SOPS/age**
   ```bash
   # Ensure SOPS and age are installed, and point to your private key
   export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt

   # Install the Ansible vars plugin used by this repo
   ansible-galaxy collection install community.sops
   ```

3. **Update Variables**
   ```bash
   # Edit global variables
   vi ansible/inventory/group_vars/all.yml
   
   # Create or edit encrypted secrets with SOPS (auto-encrypted via .sops.yaml)
   sops ansible/inventory/group_vars/sso_secrets.yml
   ```

## Secrets (SOPS/age)

- Encrypted variables live under ansible/inventory/group_vars/*_secrets.yml (example: sso_secrets.yml).
- Encryption is enforced by .sops.yaml: any file matching that pattern is automatically encrypted for the repository’s age recipient.
- Ansible is configured to load SOPS-encrypted vars via community.sops (see ansible/ansible.cfg). If your AGE private key is available (export SOPS_AGE_KEY_FILE), Ansible will decrypt at runtime.
- Edit secrets safely with SOPS (do not paste secrets into plaintext files):
  - sops ansible/inventory/group_vars/sso_secrets.yml

## Common Tasks

### Deploy Complete On-Prem Stack (Recommended)
```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml
```
Automatically creates directories, installs dependencies, deploys Docker Compose, and starts all services.

### Manual Docker Operations
```bash
# Start all services
cd ~/nas_docker && docker compose up -d

# Stop all services
docker compose down

# View logs
docker compose logs -f

# Check service status
docker compose ps
```

### Backup Operations
```bash
# Manual backup
~/Scripts/backup-onprem.sh

# View backup logs
tail -f ~/Backups/wilkesliberty/logs/backup.log
```

## Security Configuration

### Access Control
- Admin access restricted to specified CIDR ranges
- VPN required for internal network access
- SSH key-based authentication only
- Fail2ban for intrusion prevention

### Network Security
- Internal services communicate via private network
- External access only through reverse proxy
- SSL/TLS encryption for all public endpoints
- Firewall rules limiting service exposure

## Drupal-Specific Configuration

### Features Supported
- **Multilingual**: English, Spanish, Russian
- **Headless API**: GraphQL and JSON:API endpoints
- **Content Types**: Article, Basic Page, Career, Case Study, Event, Landing Page, Person, Resource, Service
- **Media Management**: Audio, Document, Image, Video, SVG support
- **SEO Optimization**: Metatags, XML sitemaps, structured data
- **Translation Management**: TMGMT integration

### Performance Features
- **Caching**: Redis/Memcached for object caching
- **CDN Integration**: Asset optimization and delivery
- **Search**: Apache Solr with multilingual support
- **Image Processing**: Automated optimization and responsive images

## Monitoring & Maintenance

### Observability
- Application performance monitoring
- Server health monitoring  
- Database performance metrics
- Search index health
- Uptime monitoring

### Backup Strategy
- Automated daily database backups
- File system snapshots
- Configuration backup to git
- Offsite backup storage

## Development Workflow

### Local Development
This infrastructure supports local development using ddev:
```bash
# In the Drupal application directory
ddev start
ddev drush cr
```

### Staging Deployment
1. Test changes locally with ddev
2. Commit configuration changes
3. Deploy to staging environment
4. Run automated tests
5. Deploy to production

## Infrastructure Status (March 2026)

### ✅ Production Ready
This infrastructure is production-ready with enterprise-grade capabilities:

- **Docker Compose Stack**: 11 containers with health checks
- **Enterprise Monitoring**: Prometheus/Grafana/Alertmanager with 16 alert rules
- **Automated Backups**: Daily backups with 90-day retention
- **Single-Command Deployment**: Fully automated via Ansible
- **Network Segmentation**: Three-tier Docker network isolation
- **Secrets Management**: SOPS/AGE encryption
- **Documentation**: Comprehensive 677-line deployment checklist

### Recent Improvements
- Simplified inventory from 9 hosts to 2
- Removed 9 conflicting Ansible roles
- Created comprehensive Docker Compose stack
- Implemented enterprise monitoring
- Automated backup system with retention management
- Enhanced wl-onprem role for fully automated deployment
- Updated documentation to reflect Docker-first architecture

## Troubleshooting

### Common Issues

**SSH Access Issues**
- Verify VPN connection
- Check SSH key permissions  
- Confirm server IP addresses

**Ansible Failures**
- Ensure SOPS_AGE_KEY_FILE points to your AGE key file and your key is available
- Confirm community.sops is installed (ansible-galaxy collection install community.sops)
- Verify inventory configuration
- Ensure target servers are accessible

**Variable Resolution Issues** 
- Check ansible/README.md for variable precedence documentation
- Use `ansible-inventory --host [hostname]` to debug variable conflicts
- Verify SOPS decryption is working for encrypted files

**Application Issues**
- Check logs: `tail -f /var/log/nginx/error.log`
- Drupal logs: `ddev drush watchdog:show` 
- Clear caches: `ddev drush cr`

### Support Contacts
- Infrastructure: [Your team contact]
- Application: [Drupal team contact]
- Security: [Security team contact]

## Contributing

1. Fork this repository
2. Create feature branch: `git checkout -b feature/new-role`
3. Test changes in staging environment
4. Submit pull request with detailed description
5. Ensure all checks pass before merge

## License

Private repository for Wilkes Liberty infrastructure. Unauthorized access prohibited.

---

**Last Updated**: October 2025  
**Version**: 2.0 (Infrastructure Audit Complete)  
**Maintainer**: Wilkes Liberty Infrastructure Team

## Quick Reference

### Validation Commands
```bash
# Verify infrastructure health
ansible-inventory -i ansible/inventory/hosts.ini --graph
ansible -i ansible/inventory/hosts.ini all -m ping
./scripts/backup-onprem.sh --dry-run
```

### Deployment Commands  
```bash
# Deploy complete stack (automated)
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml

# Manual Docker operations
cd ~/nas_docker
docker compose up -d        # Start services
docker compose ps           # Check status
docker compose logs -f      # View logs
docker compose down         # Stop services
```

### Terraform DNS Management
```bash
# Terraform files are in project root (single environment pattern)
terraform plan       # Plan DNS changes
terraform apply      # Apply DNS records
terraform show       # View current state
```

### Documentation
- **DEPLOYMENT_CHECKLIST.md**: Step-by-step deployment guide (677 lines)
- **WARP.md**: Complete infrastructure guide and architecture
- **IMPLEMENTATION_STATUS.md**: Current implementation progress
- **SECRETS_MANAGEMENT.md**: SOPS/AGE encryption setup and usage guide
- **TAILSCALE_SETUP.md**: Tailscale mesh VPN deployment guide
- **ansible/README.md**: Variable precedence and configuration structure  
- **DNS_RECORDS.md**: Public DNS configuration reference
