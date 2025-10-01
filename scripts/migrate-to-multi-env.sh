#!/bin/bash
# Migration script for converting single-environment Terraform to multi-environment structure
# Run this when ready to add development environment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if we're in the right directory
    if [[ ! -f "main.tf" ]]; then
        error "main.tf not found. Please run this script from the infra directory."
        exit 1
    fi
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        error "Terraform not found. Please install Terraform."
        exit 1
    fi
    
    # Check if current Terraform state is clean
    if terraform plan &>/dev/null; then
        log "Terraform state is clean"
    else
        warn "Terraform plan failed. Make sure current infrastructure is in good state."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Backup current state
backup_current_state() {
    log "Creating backup of current state..."
    
    BACKUP_DIR="backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Copy all terraform files
    cp *.tf "$BACKUP_DIR/" 2>/dev/null || true
    cp terraform.tfvars "$BACKUP_DIR/" 2>/dev/null || true
    cp -r .terraform "$BACKUP_DIR/" 2>/dev/null || true
    cp terraform.tfstate* "$BACKUP_DIR/" 2>/dev/null || true
    
    log "Backup created in $BACKUP_DIR"
    echo "$BACKUP_DIR" > .migration-backup-location
}

# Create new directory structure
create_directory_structure() {
    log "Creating multi-environment directory structure..."
    
    mkdir -p environments/prod
    mkdir -p environments/staging
    mkdir -p environments/dev
    mkdir -p modules/dns
    mkdir -p modules/mail
    mkdir -p modules/infrastructure
    mkdir -p shared
    
    info "Created directory structure:"
    tree environments modules shared 2>/dev/null || find environments modules shared -type d
}

# Move production files
move_production_files() {
    log "Moving current files to environments/prod/..."
    
    # Move terraform files
    mv *.tf environments/prod/
    mv terraform.tfvars environments/prod/ 2>/dev/null || true
    mv .terraform environments/prod/ 2>/dev/null || true
    mv terraform.tfstate* environments/prod/ 2>/dev/null || true
    
    log "Production files moved successfully"
}

# Create shared modules
create_shared_modules() {
    log "Creating shared modules..."
    
    # DNS module
    cat > modules/dns/main.tf << 'EOF'
# Shared DNS module for wilkesliberty.com infrastructure

terraform {
  required_providers {
    njalla = {
      source  = "njal-la/njalla"
      version = "~> 1.0"
    }
  }
}

# Infrastructure host A and AAAA records
resource "njalla_record" "host_a" {
  for_each = var.hosts
  
  domain = var.domain
  type   = "A"
  name   = "${each.key}.${var.environment}"
  value  = each.value.ipv4
  ttl    = 3600
}

resource "njalla_record" "host_aaaa" {
  for_each = var.hosts
  
  domain = var.domain
  type   = "AAAA"
  name   = "${each.key}.${var.environment}"
  value  = each.value.ipv6
  ttl    = 3600
}

# Service aliases (CNAME records)
resource "njalla_record" "service_aliases" {
  for_each = var.service_aliases
  
  domain = var.domain
  type   = "CNAME"
  name   = "${each.key}.${var.environment_prefix}"
  value  = "${each.value}.${var.environment}.${var.domain}."
  ttl    = 3600
}
EOF

    cat > modules/dns/variables.tf << 'EOF'
variable "domain" {
  description = "Primary domain name"
  type        = string
}

variable "environment" {
  description = "Environment name (prod, dev)"
  type        = string
}

variable "environment_prefix" {
  description = "Environment prefix for subdomains (empty for prod, 'dev' for dev)"
  type        = string
  default     = ""
}

variable "hosts" {
  description = "Host definitions with IPv4 and IPv6 addresses"
  type = map(object({
    ipv4 = string
    ipv6 = string
  }))
}

variable "service_aliases" {
  description = "Service alias mappings (www -> cache1, api -> cache1, etc)"
  type        = map(string)
  default     = {}
}
EOF

    # Mail module
    cat > modules/mail/main.tf << 'EOF'
# Shared mail configuration module

resource "njalla_record" "dkim1" {
  domain = var.domain
  type   = "TXT"
  name   = "protonmail._domainkey"
  value  = var.proton_dkim1_target
  ttl    = 3600
}

resource "njalla_record" "dkim2" {
  domain = var.domain
  type   = "TXT" 
  name   = "protonmail2._domainkey"
  value  = var.proton_dkim2_target
  ttl    = 3600
}

resource "njalla_record" "dkim3" {
  domain = var.domain
  type   = "TXT"
  name   = "protonmail3._domainkey"
  value  = var.proton_dkim3_target
  ttl    = 3600
}
EOF

    cat > modules/mail/variables.tf << 'EOF'
variable "domain" {
  description = "Primary domain name"
  type        = string
}

variable "proton_dkim1_target" {
  description = "Proton DKIM1 target value"
  type        = string
}

variable "proton_dkim2_target" {
  description = "Proton DKIM2 target value"
  type        = string
}

variable "proton_dkim3_target" {
  description = "Proton DKIM3 target value"
  type        = string
}
EOF

    log "Shared modules created"
}

# Create staging and development environments
create_staging_dev_environments() {
    log "Creating staging and development environments..."
    
    # Create staging environment
    cp environments/prod/*.tf environments/staging/
    cat > environments/staging/terraform.tfvars << 'EOF'
# Staging environment configuration

# Environment settings
environment = "staging"
project_name = "wilkes-liberty-staging"

# Domain configuration
domain_name = "wilkesliberty.com"

# Network configuration (similar to prod)
internal_cidr = "10.10.0.0/24"

# Admin access (same as prod)
admin_allow_cidrs = [
  "203.0.113.0/24",
  "203.0.113.10/32"
]

# Add your Njalla API token
# njalla_api_token = "your_staging_api_token_here"

# Add your Proton DKIM values (same as prod)
# proton_dkim1_target = "your_dkim1_value"
# proton_dkim2_target = "your_dkim2_value"  
# proton_dkim3_target = "your_dkim3_value"
EOF

    # Create development environment
    cp environments/prod/*.tf environments/dev/
    cat > environments/dev/terraform.tfvars << 'EOF'
# Development environment configuration

# Environment settings
environment = "dev"
project_name = "wilkes-liberty-dev"

# Domain configuration
domain_name = "wilkesliberty.com"

# Network configuration (different from prod)
internal_cidr = "10.20.0.0/24"

# Admin access (same as prod for now)
admin_allow_cidrs = [
  "203.0.113.0/24",
  "203.0.113.10/32"
]

# Add your Njalla API token
# njalla_api_token = "your_dev_api_token_here"

# Add your Proton DKIM values (same as prod)
# proton_dkim1_target = "your_dkim1_value"
# proton_dkim2_target = "your_dkim2_value"  
# proton_dkim3_target = "your_dkim3_value"
EOF

    log "Staging and development environments created"
}

# Create environment-specific documentation
create_environment_docs() {
    log "Creating environment-specific documentation..."
    
    cat > environments/README.md << 'EOF'
# Multi-Environment Terraform Structure

## Usage

### Production Environment
```bash
cd environments/prod
terraform init
terraform plan
terraform apply
```

### Staging Environment
```bash
cd environments/staging
terraform init
terraform plan
terraform apply
```

### Development Environment  
```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

## Environment Differences

### Production
- Full infrastructure stack
- Production DNS records (*.wilkesliberty.com)
- High-availability configuration
- Production security settings
- Full monitoring and alerting

### Staging
- Production-like configuration for realistic testing
- Staging DNS subdomain (*.staging.wilkesliberty.com)
- Similar instance sizes to production
- Production security model (isolated)
- Full monitoring for deployment validation

### Development
- Smaller instance sizes for cost optimization
- Development DNS subdomain (*.dev.wilkesliberty.com)
- Relaxed security for testing
- Basic monitoring

## Shared Resources

### DNS Module (`modules/dns/`)
- Handles A/AAAA record creation
- Manages service aliases (CNAME)
- Environment-aware configuration

### Mail Module (`modules/mail/`)
- Proton Mail DKIM configuration
- Shared across environments

## Adding New Environments

1. Create new directory: `environments/[env_name]/`
2. Copy production files as starting point
3. Customize variables for environment requirements
4. Initialize and apply terraform

### Environment Progression
```
Development → Staging → Production
    ↓           ↓         ↓
  Feature    Full Stack  Blue/Green
  Testing    Testing     Deployment
```
EOF

    log "Environment documentation created"
}

# Update root-level documentation
update_root_documentation() {
    log "Updating root-level documentation..."
    
    # Update TERRAFORM_ORGANIZATION.md
    sed -i.bak 's/### Phase 1: Current (Production Only)/### Phase 1: COMPLETED - Multi-Environment Structure/' TERRAFORM_ORGANIZATION.md
    
    info "Documentation updated (backup created as .bak files)"
}

# Final validation
final_validation() {
    log "Running final validation..."
    
    # Test production terraform
    cd environments/prod
    if terraform init && terraform validate; then
        log "Production environment validated successfully"
    else
        error "Production environment validation failed"
        cd ../..
        return 1
    fi
    
    cd ../staging
    if terraform init && terraform validate; then
        log "Staging environment validated successfully"
    else
        error "Staging environment validation failed"
        cd ../..
        return 1
    fi
    
    cd ../dev
    if terraform init && terraform validate; then
        log "Development environment validated successfully"
    else
        error "Development environment validation failed"
        cd ../..
        return 1
    fi
    
    cd ../..
    log "Migration completed successfully!"
}

# Main execution
main() {
    log "=== Terraform Multi-Environment Migration Started ==="
    
    # Parse arguments
    DRY_RUN=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                log "DRY RUN MODE - No actual changes will be made"
                shift
                ;;
            --help|-h)
                cat << EOF
Usage: $0 [options]

Options:
    --dry-run       Show what would be done without making changes
    --help, -h      Show this help message

This script migrates the current single-environment Terraform structure
to a multi-environment structure supporting both production and development.

EOF
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Would perform migration steps:"
        log "1. Check prerequisites"
        log "2. Backup current state"
        log "3. Create directory structure"
        log "4. Move production files"
        log "5. Create shared modules"
        log "6. Create staging and development environments"
        log "7. Update documentation"
        log "8. Validate new structure"
        exit 0
    fi
    
    check_prerequisites
    backup_current_state
    create_directory_structure
    move_production_files
    create_shared_modules
    create_staging_dev_environments
    create_environment_docs
    update_root_documentation
    final_validation
    
    log "=== Migration completed successfully! ==="
    log ""
    log "Next steps:"
    log "1. Review and update environments/staging/terraform.tfvars"
    log "2. Review and update environments/dev/terraform.tfvars"
    log "3. Test staging environment: cd environments/staging && terraform plan"
    log "4. Test development environment: cd environments/dev && terraform plan"
    log "5. Update Ansible inventories for staging and dev environments"
    log "6. Update CI/CD pipelines for multi-environment structure"
}

# Run main function with all arguments
main "$@"