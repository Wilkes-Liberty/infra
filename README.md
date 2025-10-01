# Wilkes Liberty Infrastructure

This repository contains the infrastructure automation and configuration for the Wilkes Liberty web platform, a multilingual Drupal 11 site with headless capabilities.

## Architecture Overview

The infrastructure consists of multiple servers managed through Ansible automation:

- **App Server** (`app`) - Drupal 11 application with PHP 8.3
- **Database Server** (`db`) - MySQL/MariaDB database
- **Search Server** (`solr`) - Apache Solr 9.6.1 for full-text search
- **Analytics Server** (`analytics`) - Observability and monitoring
- **DNS Server** (`coredns`) - Custom DNS configuration

### Network Configuration

- **Primary Domain**: `wilkesliberty.com`
- **Internal Domain**: `int.wilkesliberty.com`
- **VPN**: Proton VPN Business for secure access
- **Internal IPs**:
  - App: `10.10.0.2`
  - Database: `10.10.0.3` 
  - Solr: `10.10.0.4`
  - Analytics: `10.10.0.7`

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

### Core Roles

- **`common`** - Base system configuration, security, users
- **`app`** - PHP 8.3, Nginx, Drupal application setup
- **`db`** - Database server configuration
- **`solr`** - Apache Solr search engine setup
- **`analytics_obs`** - Monitoring and observability tools

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

### Bootstrap New Environment
```bash
make bootstrap
```
Runs initial server setup, security hardening, and user configuration.

### Deploy Full Site
```bash
make site
```
Configures all services according to their roles.

### Application Deployment
```bash
make deploy
```
Deploys application updates to app servers only.

### Database Backup
```bash
make backup-db
```
Creates database backup using the provided script.

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

## Infrastructure Status (October 2025)

### ✅ Production Ready
This infrastructure repository has been fully audited and all critical issues have been resolved:

- **Inventory**: Clean, standardized FQDN format without duplications
- **Variables**: Consolidated definitions, no conflicts or duplications
- **Automation**: Functional deployment and backup scripts
- **Documentation**: Comprehensive guides for variable precedence and structure
- **Security**: SOPS/age encryption properly configured

### Recent Improvements
- Fixed all inventory duplications and hostname inconsistencies
- Consolidated variable definitions in group_vars/all.yml
- Created missing deployment and backup automation
- Enhanced .gitignore to prevent artifact commits
- Added comprehensive documentation (see ansible/README.md)

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
make --dry-run bootstrap
./scripts/backup-db.sh --dry-run
```

### Deployment Commands  
```bash
# Deploy infrastructure
make bootstrap    # Initial setup
make site        # Full deployment
make deploy      # Application only
make backup-db   # Database backup
```

### Terraform DNS Management
```bash
# Terraform files are in project root (single environment pattern)
terraform plan       # Plan DNS changes
terraform apply      # Apply DNS records
terraform show       # View current state
```

### Documentation
- **WARP.md**: Complete infrastructure guide and architecture
- **ansible/README.md**: Variable precedence and configuration structure  
- **DNS_RECORDS.md**: Public DNS configuration reference
- **MULTI_ENVIRONMENT_STRATEGY.md**: Three-environment expansion plan (dev → staging → prod)
- **GITHUB_ACTIONS_STRATEGY.md**: CI/CD pipeline with branch-based deployment triggers
