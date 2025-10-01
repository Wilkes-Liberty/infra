# Contributing to Wilkes Liberty Infrastructure

This guide covers everything you need to know to contribute to the Wilkes Liberty infrastructure project, from setting up your local development environment to following our GitHub flow process.

## Table of Contents

- [Getting Started](#getting-started)
- [Local Development Environment](#local-development-environment)
- [GitHub Flow Process](#github-flow-process)
- [Code Standards](#code-standards)
- [Testing Requirements](#testing-requirements)
- [Infrastructure Changes](#infrastructure-changes)
- [Security Guidelines](#security-guidelines)
- [Documentation Requirements](#documentation-requirements)
- [Review Process](#review-process)

## Getting Started

### Prerequisites

Before contributing, ensure you have the required tools and access:

#### Required Software
- **Git**: Version control system
- **Ansible**: `>= 2.14` for infrastructure automation
- **Terraform**: `>= 1.5` for infrastructure as code
- **Python**: `>= 3.9` for Ansible and tooling
- **Node.js**: `>= 20` for JavaScript tooling
- **PHP**: `>= 8.3` for Drupal development (if working on app components)
- **SOPS**: For encrypted secrets management
- **Age**: For SOPS encryption keys

#### Required Access
- **GitHub repository**: Read/write access to submit pull requests
- **SSH keys**: Access to development servers (provided by team lead)
- **SOPS key**: AGE private key for decrypting secrets (provided by team lead)
- **Slack**: Access to `#infrastructure` and `#deployments` channels

### Repository Access

1. **Fork the repository** (external contributors) or **clone directly** (team members):
   ```bash
   # Team members
   git clone git@github.com:wilkesliberty/infra.git
   cd infra
   
   # External contributors
   git clone git@github.com:yourusername/infra.git
   cd infra
   git remote add upstream git@github.com:wilkesliberty/infra.git
   ```

2. **Verify repository structure**:
   ```bash
   ls -la
   # Should show: ansible/, scripts/, .github/, *.tf files, documentation
   ```

## Local Development Environment

### 1. System Setup (macOS)

#### Install Homebrew (if not already installed)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### Install Required Tools
```bash
# Core tools
brew install git ansible terraform python@3.11 node@20

# Security and secrets management
brew install sops age

# Optional but recommended
brew install jq yq tree curl wget
```

#### Verify Installations
```bash
# Check versions
ansible --version     # Should be >= 2.14
terraform --version   # Should be >= 1.5
python3 --version     # Should be >= 3.9
node --version        # Should be >= 20
sops --version        # Should be latest
age --version         # Should be latest
```

### 2. Python Environment Setup

#### Create Virtual Environment
```bash
# Create virtual environment for the project
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install Python dependencies
pip install --upgrade pip
pip install ansible
```

#### Install Ansible Collections
```bash
# Install required Ansible collections
ansible-galaxy collection install community.sops
ansible-galaxy collection install ansible.posix
ansible-galaxy collection install community.general
```

### 3. SOPS/Age Configuration

#### Set Up Age Key (Provided by Team Lead)
```bash
# Create SOPS configuration directory
mkdir -p ~/.config/sops/age

# Add your AGE private key (provided by team lead)
echo "YOUR_AGE_PRIVATE_KEY_HERE" > ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# Export environment variable
echo 'export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt' >> ~/.zshrc
source ~/.zshrc
```

#### Test SOPS Configuration
```bash
# Test decrypting existing secrets
cd infra
sops ansible/inventory/group_vars/sso_secrets.yml
# Should show decrypted content
```

### 4. SSH Configuration

#### Set Up SSH for Development Servers
```bash
# Add SSH configuration (provided by team lead)
cat >> ~/.ssh/config << 'EOF'
# Wilkes Liberty Development Infrastructure
Host *.dev.wilkesliberty.com
  User ubuntu
  IdentityFile ~/.ssh/wilkes_liberty_dev
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

# Staging Infrastructure  
Host *.staging.wilkesliberty.com
  User ubuntu
  IdentityFile ~/.ssh/wilkes_liberty_staging
  StrictHostKeyChecking accept-new
EOF
```

### 5. Development Environment Validation

#### Run Infrastructure Validation
```bash
cd infra

# Validate Ansible configuration
ansible-inventory -i ansible/inventory/hosts.ini --graph

# Test variable resolution
ansible-inventory -i ansible/inventory/hosts.ini --host app1.prod.wilkesliberty.com

# Validate Terraform configuration  
terraform init
terraform validate
terraform plan -out=tfplan

# Test backup script
./scripts/backup-db.sh --dry-run
```

#### Development Environment Health Check
```bash
# Run complete validation script
./scripts/dev-environment-check.sh
```

Let me create this validation script:

```bash
# Create development environment validation script
cat > scripts/dev-environment-check.sh << 'EOF'
#!/bin/bash
# Development environment validation script

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}" >&2; }

echo "=== Wilkes Liberty Infrastructure Development Environment Check ==="

# Check required tools
tools=("ansible" "terraform" "python3" "node" "sops" "age")
for tool in "${tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        version=$(eval "$tool --version 2>/dev/null | head -1")
        log "$tool is installed: $version"
    else
        error "$tool is not installed"
    fi
done

# Check Python virtual environment
if [[ "$VIRTUAL_ENV" ]]; then
    log "Python virtual environment active: $VIRTUAL_ENV"
else
    warn "Python virtual environment not active. Run: source venv/bin/activate"
fi

# Check Ansible collections
if ansible-galaxy collection list | grep -q community.sops; then
    log "Ansible community.sops collection installed"
else
    error "Missing community.sops collection. Run: ansible-galaxy collection install community.sops"
fi

# Check SOPS configuration
if [[ -f "$HOME/.config/sops/age/keys.txt" && -n "${SOPS_AGE_KEY_FILE:-}" ]]; then
    log "SOPS/AGE configuration found"
else
    error "SOPS/AGE not configured. Check ~/.config/sops/age/keys.txt and SOPS_AGE_KEY_FILE"
fi

# Check repository structure
required_files=("ansible/inventory/hosts.ini" "terraform.tf" "Makefile" "WARP.md")
for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        log "Required file exists: $file"
    else
        error "Missing required file: $file"
    fi
done

# Validate Ansible inventory
if ansible-inventory -i ansible/inventory/hosts.ini --graph &>/dev/null; then
    log "Ansible inventory validation passed"
else
    error "Ansible inventory validation failed"
fi

# Validate Terraform
if terraform validate &>/dev/null; then
    log "Terraform validation passed"
else
    error "Terraform validation failed"
fi

echo ""
echo "=== Development Environment Check Complete ==="
EOF

chmod +x scripts/dev-environment-check.sh
```

## GitHub Flow Process

We follow a **strict GitHub Flow** process to ensure code quality and deployment safety.

### Branch Strategy

```
main/master (production)
    ↑
staging (staging environment)  
    ↑
development (development environment)
    ↑
feature/fix branches (pull requests)
```

### 1. Creating Feature Branches

#### Branch Naming Convention
- **Features**: `feature/description-of-feature`
- **Bug fixes**: `fix/description-of-bug`  
- **Infrastructure**: `infra/description-of-change`
- **Documentation**: `docs/description-of-update`

#### Examples
```bash
# Good branch names
feature/add-solr-role
fix/inventory-duplicate-cache-groups
infra/migrate-to-multi-environment
docs/update-contributing-guide

# Bad branch names
fix-stuff
new-feature
update
temp-branch
```

#### Creating Branches
```bash
# Always start from development branch
git checkout development
git pull origin development

# Create and checkout new feature branch
git checkout -b feature/your-feature-name

# Push branch to origin
git push -u origin feature/your-feature-name
```

### 2. Making Changes

#### Commit Standards
Follow **Conventional Commits** specification:

```bash
# Format: type(scope): description
# 
# Types: feat, fix, docs, style, refactor, test, chore, infra
# Scope: component being changed (optional)
# Description: concise description of change

# Examples
git commit -m "feat(ansible): add Solr search role implementation"
git commit -m "fix(inventory): remove duplicate cache group entries"
git commit -m "docs(contributing): add local development setup guide"
git commit -m "infra(terraform): migrate to multi-environment structure"
```

#### Commit Best Practices
- **Atomic commits**: One logical change per commit
- **Clear messages**: Describe what and why, not how
- **Test before committing**: Ensure all tests pass
- **Sign commits**: Use GPG signing for security (recommended)

### 3. Pull Request Process

#### Pre-Pull Request Checklist
- [ ] All tests pass locally
- [ ] Code follows style guidelines
- [ ] Documentation updated if needed
- [ ] Secrets properly encrypted with SOPS
- [ ] No sensitive data in commits
- [ ] Branch is up to date with development

#### Creating Pull Requests

1. **Push your changes**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create pull request** via GitHub UI with template:

   ```markdown
   ## Description
   Brief description of changes and motivation.

   ## Type of Change
   - [ ] Bug fix (non-breaking change that fixes an issue)
   - [ ] New feature (non-breaking change that adds functionality)  
   - [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
   - [ ] Documentation update
   - [ ] Infrastructure change

   ## Testing
   - [ ] Unit tests pass locally
   - [ ] Integration tests pass locally
   - [ ] Ansible playbooks validated
   - [ ] Terraform configuration validated
   - [ ] Manual testing completed

   ## Security
   - [ ] No sensitive data exposed
   - [ ] Secrets properly encrypted with SOPS
   - [ ] Security best practices followed

   ## Documentation
   - [ ] Code is self-documenting
   - [ ] README updated (if applicable)
   - [ ] WARP.md updated (if applicable)
   - [ ] Inline comments added for complex logic

   ## Deployment
   - [ ] Changes tested in development environment
   - [ ] Database migrations included (if applicable)
   - [ ] Rollback plan documented (if applicable)
   ```

3. **Request reviews** from:
   - **Required**: At least one infrastructure team member
   - **Optional**: Domain expert for specific changes

#### Pull Request Requirements

**Automated Checks** (must pass):
- [ ] All GitHub Actions workflows pass
- [ ] No merge conflicts with target branch
- [ ] Branch is up to date with development
- [ ] Conventional commit format followed

**Manual Review Requirements** (before approval):
- [ ] Code review by at least one team member
- [ ] Security review for infrastructure changes
- [ ] Documentation review for public-facing changes
- [ ] Architecture review for significant changes

## Code Standards

### Ansible Standards

#### Directory Structure
```
ansible/
├── inventory/
│   ├── group_vars/
│   │   ├── all.yml           # Main variables
│   │   └── *_secrets.yml     # Encrypted secrets
│   ├── host_vars/
│   │   └── *.yml             # Host-specific variables
│   └── hosts.ini             # Inventory file
├── playbooks/
│   ├── site.yml              # Main orchestration
│   ├── bootstrap.yml         # Initial setup
│   └── deploy-app.yml        # Application deployment
└── roles/
    ├── common/               # Base configuration
    ├── app/                  # Application server
    └── [service]/            # Service-specific roles
```

#### YAML Style Guide
```yaml
---
# Use --- to start YAML documents
# Use consistent 2-space indentation
# Use descriptive variable names
# Group related variables

# Good examples
- name: Install packages
  package:
    name:
      - nginx
      - php8.3-fpm
    state: present
    
# Variables
app_packages:
  - nginx
  - php8.3-fpm
  - php8.3-mysql

# Bad examples (avoid)
- package: name=nginx state=present  # Use YAML format
- name: install stuff                # Be descriptive
```

#### Role Standards
- **Idempotent**: Roles must be safe to run multiple times
- **Variables**: Use role-specific prefixes (`role_name_variable`)
- **Handlers**: Use descriptive handler names
- **Documentation**: Include README.md for complex roles
- **Testing**: Include molecule tests for complex roles

### Terraform Standards

#### File Organization
```
# Single environment (current)
main.tf              # Core configuration
provider.tf          # Provider configuration  
variables.tf         # Variable definitions
outputs.tf           # Output definitions
records.tf          # DNS record definitions
mail_proton.tf      # Mail configuration

# Multi-environment (future)
environments/
├── prod/           # Production environment
├── staging/        # Staging environment
└── dev/            # Development environment
modules/
├── dns/           # Shared DNS module
└── mail/          # Shared mail module
```

#### Code Style
```hcl
# Use consistent formatting
# terraform fmt will handle most formatting

# Resource naming: [resource_type]_[descriptive_name]
resource "njalla_record" "www_cname" {
  domain = var.domain_name
  type   = "CNAME" 
  name   = "www"
  value  = "cache1.prod.${var.domain_name}."
  ttl    = 3600
}

# Variable definitions with descriptions
variable "domain_name" {
  description = "Primary domain name for the infrastructure"
  type        = string
  default     = "wilkesliberty.com"
}

# Use locals for computed values
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

### Documentation Standards

#### Inline Comments
```yaml
# Ansible example
- name: Configure firewall rules
  ufw:
    rule: "{{ item.rule }}"
    port: "{{ item.port }}"
    proto: "{{ item.proto }}"
    src: "{{ item.src | default(omit) }}"
  loop: "{{ firewall_rules }}"
  # Loop through firewall rules defined in group_vars
  # Uses omit filter to skip undefined src addresses
```

```hcl
# Terraform example
resource "njalla_record" "apex_a" {
  domain = var.domain_name
  type   = "A"
  name   = "@"                    # @ represents the apex domain
  value  = var.cache_server_ipv4  # Points to cache server for CDN
  ttl    = 3600                   # 1 hour TTL for production stability
}
```

#### README Files
Every major component should have a README:
- **Purpose**: What the component does
- **Usage**: How to use it
- **Variables**: Required and optional variables
- **Examples**: Common usage examples
- **Dependencies**: What it depends on

## Testing Requirements

### Pre-Commit Testing
Run these tests before every commit:

```bash
# Ansible validation
ansible-playbook --syntax-check ansible/playbooks/site.yml
ansible-inventory -i ansible/inventory/hosts.ini --graph

# Terraform validation
terraform init
terraform validate
terraform fmt -check

# YAML linting
yamllint ansible/

# Security checks
# Check for secrets in commits
git secrets --scan

# Check for large files
git ls-files | xargs wc -l | sort -rn | head -10
```

### Integration Testing
For significant changes, test in development environment:

```bash
# Deploy to development
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy-app.yml --limit dev

# Verify deployment
curl -f https://dev.wilkesliberty.com/health

# Run smoke tests
./scripts/smoke-tests.sh dev
```

### Creating Test Scripts

#### Example Smoke Test Script
```bash
cat > scripts/smoke-tests.sh << 'EOF'
#!/bin/bash
# Smoke tests for infrastructure deployment

set -euo pipefail

ENVIRONMENT=${1:-dev}
BASE_URL="https://${ENVIRONMENT}.wilkesliberty.com"

echo "Running smoke tests for $ENVIRONMENT environment..."

# Health check endpoint
if curl -f "$BASE_URL/health"; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed"
    exit 1
fi

# Database connectivity
# Add your specific tests here

echo "✅ All smoke tests passed for $ENVIRONMENT"
EOF

chmod +x scripts/smoke-tests.sh
```

## Infrastructure Changes

### Types of Changes

#### Low-Risk Changes
- Documentation updates
- Variable modifications
- Non-breaking role additions
- DNS record updates

**Process**: Standard pull request → development → staging → production

#### Medium-Risk Changes  
- New service roles
- Firewall rule changes
- Backup procedure modifications
- Monitoring configuration changes

**Process**: Pull request + development testing → staging validation → production (with approval)

#### High-Risk Changes
- Database schema changes
- Breaking configuration changes
- Security policy modifications
- Multi-environment migrations

**Process**: Design document → team review → development testing → staging validation → production planning meeting → production deployment

### Change Documentation

For infrastructure changes, document:

1. **Motivation**: Why is this change needed?
2. **Impact**: What systems/services are affected?
3. **Risk Assessment**: What could go wrong?
4. **Rollback Plan**: How to undo if needed?
5. **Testing Plan**: How will you verify success?
6. **Monitoring**: What metrics to watch post-deployment?

### Database Migrations

For changes affecting databases:

```bash
# 1. Create migration backup
./scripts/backup-db.sh --backup-dir /opt/backups/pre-migration-$(date +%Y%m%d)

# 2. Test migration in development
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/migrate-db.yml --limit dev

# 3. Validate in staging
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/migrate-db.yml --limit staging

# 4. Production migration (with approval)
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/migrate-db.yml --limit prod
```

## Security Guidelines

### Secrets Management

#### SOPS Encryption
All secrets must be encrypted with SOPS:

```bash
# Create new secrets file
sops ansible/inventory/group_vars/new_secrets.yml

# Edit existing secrets
sops ansible/inventory/group_vars/sso_secrets.yml

# Verify encryption
file ansible/inventory/group_vars/sso_secrets.yml
# Should show: ASCII text (encrypted)
```

#### Secret Types and Storage
- **API tokens**: Environment-specific secrets files
- **SSH keys**: Stored in secure key management, not in repository
- **Database credentials**: SOPS-encrypted in group_vars
- **SSL certificates**: Automated via Let's Encrypt or stored securely

#### Security Checklist
- [ ] No plaintext secrets in any files
- [ ] All .yml files with secrets encrypted with SOPS
- [ ] SSH keys not committed to repository
- [ ] API tokens stored in environment-specific secrets
- [ ] Database credentials properly encrypted
- [ ] SSL/TLS certificates automatically managed

### Access Control

#### Repository Access
- **Read access**: All team members
- **Write access**: Core infrastructure team
- **Admin access**: Infrastructure team leads only

#### Server Access
- **Development**: All developers (via SSH keys)
- **Staging**: Infrastructure team only
- **Production**: Infrastructure team leads only (with approval)

#### Secrets Access
- **Development secrets**: All developers
- **Staging secrets**: Infrastructure team only  
- **Production secrets**: Infrastructure team leads only

### Security Reviews

Required for:
- New security configurations
- Firewall rule changes
- Access control modifications
- Encryption/certificate changes
- External service integrations

## Documentation Requirements

### Types of Documentation

#### Code Documentation
- **Inline comments**: For complex logic
- **Variable descriptions**: Purpose and format
- **Role documentation**: README for each role
- **Playbook headers**: Purpose and usage

#### Architecture Documentation  
- **WARP.md**: Primary infrastructure guide
- **README.md**: Project overview and quick start
- **Component diagrams**: For complex systems
- **Network diagrams**: Infrastructure layout

#### Operational Documentation
- **Runbooks**: Step-by-step operational procedures
- **Troubleshooting**: Common issues and solutions  
- **Disaster recovery**: Backup and recovery procedures
- **Monitoring**: Alerts and response procedures

### Documentation Standards

#### Format
- **Markdown**: Primary documentation format
- **Diagrams**: Mermaid or ASCII art for simple diagrams
- **Code examples**: Always include working examples
- **Links**: Use relative links within repository

#### Content Requirements
- **Purpose**: What does this solve?
- **Usage**: How to use it?
- **Examples**: Working examples
- **Prerequisites**: What's needed first?
- **Troubleshooting**: Common issues

#### Documentation Review Process
1. **Technical accuracy**: Does it match implementation?
2. **Clarity**: Can newcomers understand it?
3. **Completeness**: Are all aspects covered?
4. **Examples**: Are examples current and working?
5. **Links**: Do all links work?

## Review Process

### Review Assignments

#### Automatic Reviews (GitHub)
- **Infrastructure team**: Required for all infrastructure changes
- **Security team**: Required for security-related changes
- **Documentation team**: Required for major documentation updates

#### Review Types
- **Code review**: Logic, style, and best practices
- **Security review**: Secrets, access control, and vulnerabilities  
- **Architecture review**: Design decisions and system impact
- **Documentation review**: Accuracy, clarity, and completeness

### Review Criteria

#### Code Quality
- [ ] Follows established coding standards
- [ ] Is properly documented
- [ ] Includes appropriate tests
- [ ] Handles errors gracefully
- [ ] Uses consistent naming conventions

#### Security
- [ ] No secrets exposed
- [ ] Follows security best practices  
- [ ] Includes appropriate access controls
- [ ] Uses encrypted communication
- [ ] Validates inputs appropriately

#### Architecture
- [ ] Aligns with system architecture
- [ ] Considers scalability
- [ ] Maintains backward compatibility
- [ ] Includes monitoring and observability
- [ ] Has rollback capabilities

### Approval Requirements

#### Development Environment
- **1 approval** from any team member
- **Automated tests** must pass
- **No security review** required

#### Staging Environment  
- **1 approval** from infrastructure team member
- **All tests** must pass including integration tests
- **Security review** for security-related changes

#### Production Environment
- **2 approvals** from infrastructure team leads
- **All tests** pass including staging validation
- **Security review** completed
- **Change documentation** provided
- **Rollback plan** documented

### Post-Merge Process

#### Immediate Actions
1. **Monitor deployment** in target environment
2. **Verify health checks** pass
3. **Update team** via Slack
4. **Close related issues** in GitHub

#### Follow-up Actions
1. **Monitor metrics** for 24-48 hours
2. **Document lessons learned** if needed
3. **Update documentation** if gaps found
4. **Plan next iteration** if applicable

## Emergency Procedures

### Hot Fixes

For critical production issues:

1. **Create hotfix branch** from master:
   ```bash
   git checkout master
   git pull origin master
   git checkout -b hotfix/critical-issue-fix
   ```

2. **Make minimal fix** and test locally

3. **Create emergency PR** with:
   - Clear description of issue
   - Minimal fix approach
   - Testing performed
   - Risk assessment

4. **Fast-track review** with infrastructure team lead

5. **Deploy immediately** after approval

6. **Follow up** with:
   - Post-mortem if needed
   - Documentation updates
   - Process improvements

### Rollback Procedures

If deployment fails:

```bash
# Infrastructure rollback
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/rollback.yml

# Database rollback (if needed)
./scripts/restore-db.sh /opt/backups/pre-deployment-YYYYMMDD_HHMMSS

# Terraform rollback
terraform plan -destroy -target=resource.that.failed
terraform apply

# DNS rollback (if needed)
# Revert DNS changes via Terraform or manual Njalla updates
```

### Communication

During emergencies:
- **Slack**: `#alerts` channel for immediate notifications
- **GitHub**: Create incident issue with `emergency` label
- **Team**: Notify infrastructure team leads immediately
- **Stakeholders**: Update stakeholders on resolution timeline

## Getting Help

### Resources
- **WARP.md**: Primary infrastructure documentation
- **GitHub Issues**: Ask questions or report problems
- **Slack Channels**:
  - `#infrastructure`: General infrastructure discussion
  - `#deployments`: Deployment notifications and discussion
  - `#alerts`: Critical alerts and emergency response

### Team Contacts
- **Infrastructure Team Lead**: @infrastructure-lead
- **DevOps Engineer**: @devops-engineer  
- **Security Lead**: @security-lead

### Common Issues
- **SOPS decryption fails**: Check AGE key configuration
- **Ansible connection issues**: Verify SSH keys and network access
- **Terraform state conflicts**: Coordinate with team before running terraform
- **GitHub Actions failures**: Check secrets configuration and workflow logs

---

**Welcome to the Wilkes Liberty Infrastructure team! 🚀**

This guide is living documentation. If you find gaps or have improvements, please contribute via pull request.