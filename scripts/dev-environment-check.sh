#!/bin/bash
# =============================================================================
# WilkesLiberty Infrastructure — Development Environment Check
# =============================================================================
# Validates that the local operator environment is correctly configured.
# Run from the infra/ repo root.
#
# Usage:
#   ./scripts/dev-environment-check.sh
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

log()  { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}" >&2; ERRORS=$((ERRORS + 1)); }

echo "=== WilkesLiberty Infrastructure — Environment Check ==="
echo ""

# ── Required CLI tools ───────────────────────────────────────────────────────
echo "--- Required tools ---"
# declare -A requires bash 4+; /bin/bash on macOS is 3.2 — use a function instead
check_tool() {
    local name="$1"; shift
    if command -v "$name" &>/dev/null; then
        local version
        version=$("$@" 2>/dev/null | head -1)
        log "$name: $version"
    else
        error "$name is not installed — run: ./scripts/bootstrap.sh"
    fi
}

check_tool ansible   ansible --version
check_tool terraform terraform version
check_tool sops      sops --version
check_tool age       age --version
check_tool python3   python3 --version
check_tool git       git --version
check_tool docker    docker --version
echo ""

# ── Ansible Galaxy collections ───────────────────────────────────────────────
echo "--- Ansible collections ---"
for col in community.sops community.general; do
    if ansible-galaxy collection list 2>/dev/null | grep -q "^${col}[[:space:]]"; then
        log "Collection installed: $col"
    else
        error "Missing collection: $col — run: ansible-galaxy collection install $col"
    fi
done
echo ""

# ── SOPS / AGE configuration ─────────────────────────────────────────────────
echo "--- SOPS / AGE ---"
if [[ -f "$HOME/.config/sops/age/keys.txt" ]]; then
    log "AGE key file found: ~/.config/sops/age/keys.txt"
else
    error "AGE key file missing: ~/.config/sops/age/keys.txt"
fi

if [[ -n "${SOPS_AGE_KEY_FILE:-}" ]]; then
    log "SOPS_AGE_KEY_FILE set: $SOPS_AGE_KEY_FILE"
else
    error "SOPS_AGE_KEY_FILE not set — add to ~/.zshrc: export SOPS_AGE_KEY_FILE=\"\$HOME/.config/sops/age/keys.txt\""
fi

# Test decryption
if sops -d ansible/inventory/group_vars/sso_secrets.yml &>/dev/null; then
    log "SOPS decryption works: sso_secrets.yml"
else
    error "SOPS decryption failed for sso_secrets.yml — check AGE key"
fi
echo ""

# ── Repository structure ──────────────────────────────────────────────────────
echo "--- Required files ---"
required_files=(
    "ansible/inventory/hosts.ini"
    "main.tf"
    "Makefile"
    "CLAUDE.md"
    ".sops.yaml"
    "docker/.env.example"
)
for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        log "Found: $file"
    else
        error "Missing required file: $file"
    fi
done
echo ""

# ── Sibling repos ─────────────────────────────────────────────────────────────
echo "--- Sibling repositories ---"
REPOS_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
for repo in webcms ui; do
    if [[ -d "$REPOS_DIR/$repo" ]]; then
        log "Sibling repo present: $REPOS_DIR/$repo"
    else
        warn "Missing sibling repo: $REPOS_DIR/$repo (required for Docker builds)"
    fi
done
echo ""

# ── Docker .env ───────────────────────────────────────────────────────────────
echo "--- Docker secrets ---"
ENV_FILE="$HOME/nas_docker/.env"
if [[ -f "$ENV_FILE" ]]; then
    perms=$(stat -f "%Mp%Lp" "$ENV_FILE" 2>/dev/null || stat -c "%a" "$ENV_FILE" 2>/dev/null)
    log "Docker .env exists: $ENV_FILE (permissions: $perms)"
    if [[ "$perms" != "600" && "$perms" != "0600" ]]; then
        warn ".env permissions should be 600 — run: chmod 600 $ENV_FILE"
    fi
    for var in REDIS_PASSWORD DRUPAL_DB_PASSWORD KEYCLOAK_ADMIN_PASSWORD GRAFANA_ADMIN_PASSWORD BACKUP_ENCRYPTION_KEY; do
        if grep -q "^${var}=" "$ENV_FILE" && ! grep -q "^${var}=$" "$ENV_FILE"; then
            log "  $var is set"
        else
            error "  $var is missing or empty in $ENV_FILE"
        fi
    done
else
    warn "Docker .env not found at $ENV_FILE — run bootstrap.yml or copy docker/.env.example"
fi
echo ""

# ── Ansible inventory ─────────────────────────────────────────────────────────
echo "--- Ansible ---"
if ansible-inventory -i ansible/inventory/hosts.ini --graph &>/dev/null; then
    log "Ansible inventory valid"
else
    error "Ansible inventory validation failed — check ansible/inventory/hosts.ini"
fi
echo ""

# ── Terraform ────────────────────────────────────────────────────────────────
echo "--- Terraform ---"
if [[ -f ".terraform.lock.hcl" ]]; then
    if terraform validate &>/dev/null; then
        log "Terraform configuration valid"
    else
        error "Terraform validation failed — run: terraform init && terraform validate"
    fi
else
    warn "Terraform not initialised — run: terraform init"
fi
echo ""

# ── Git ───────────────────────────────────────────────────────────────────────
echo "--- Git ---"
if git config --get user.name &>/dev/null && git config --get user.email &>/dev/null; then
    log "Git user: $(git config user.name) <$(git config user.email)>"
else
    error "Git user not configured — run: git config --global user.name/user.email"
fi

if [[ -f "$HOME/.ssh/id_ed25519" || -f "$HOME/.ssh/id_rsa" ]]; then
    log "SSH key found"
else
    warn "No SSH key found — generate with: ssh-keygen -t ed25519 -C 'your_email@example.com'"
fi

if git remote -v 2>/dev/null | grep -q "origin"; then
    log "Git remote 'origin' configured"
else
    error "Git remote 'origin' not configured"
fi
echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
echo "========================================"
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✅ All checks passed — environment is ready.${NC}"
    echo ""
    echo "Next: source scripts/load-terraform-secrets.sh && make deploy"
    exit 0
else
    echo -e "${RED}❌ $ERRORS issue(s) found — resolve before deploying.${NC}"
    echo ""
    echo "To install missing tools: ./scripts/bootstrap.sh"
    exit 1
fi
