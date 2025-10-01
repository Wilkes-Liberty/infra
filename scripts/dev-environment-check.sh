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
if [[ "${VIRTUAL_ENV:-}" ]]; then
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
required_files=("ansible/inventory/hosts.ini" "main.tf" "Makefile" "WARP.md")
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

# Check for common development issues
echo ""
echo "=== Additional Development Environment Checks ==="

# Check for backup script
if [[ -x "scripts/backup-db.sh" ]]; then
    log "Backup script is executable"
    if ./scripts/backup-db.sh --dry-run &>/dev/null; then
        log "Backup script dry-run test passed"
    else
        warn "Backup script dry-run test failed"
    fi
else
    error "Backup script missing or not executable"
fi

# Check Git configuration
if git config --get user.name &>/dev/null && git config --get user.email &>/dev/null; then
    log "Git user configuration found"
else
    error "Git user not configured. Set with: git config --global user.name/user.email"
fi

# Check for SSH key
if [[ -f "$HOME/.ssh/id_rsa" || -f "$HOME/.ssh/id_ed25519" ]]; then
    log "SSH key found"
else
    warn "No SSH key found. Generate with: ssh-keygen -t ed25519 -C 'your_email@example.com'"
fi

# Check repository remotes
if git remote -v | grep -q "origin"; then
    log "Git origin remote configured"
else
    error "Git origin remote not configured"
fi

echo ""
echo "=== Development Environment Check Complete ==="

# Return appropriate exit code
if [[ $(error 2>&1 | wc -l) -gt 0 ]]; then
    echo ""
    warn "Some issues found. Please resolve them before contributing."
    exit 1
else
    echo ""
    log "Development environment is properly configured! 🚀"
    exit 0
fi