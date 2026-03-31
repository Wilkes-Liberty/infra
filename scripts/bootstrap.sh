#!/bin/bash
# =============================================================================
# WilkesLiberty Infrastructure — Local Bootstrap Script
# =============================================================================
# Installs all required tools on the OPERATOR'S LOCAL MACHINE (macOS).
# Run this once before using Ansible, Terraform, or SOPS.
#
# Usage:
#   chmod +x scripts/bootstrap.sh
#   ./scripts/bootstrap.sh
#
# What this installs:
#   - Homebrew (if missing)
#   - sops, age, terraform, ansible, ansible-galaxy collections
#
# What this does NOT install (handled by Ansible on the remote host):
#   - Docker Desktop, Tailscale — installed on on-prem via wl-onprem role
#
# Idempotent: safe to re-run; already-installed tools are skipped.
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}" >&2; exit 1; }

echo ""
echo "============================================================"
echo "  WilkesLiberty Infrastructure Bootstrap"
echo "============================================================"
echo ""

# ── Homebrew ────────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for this session (Apple Silicon default path)
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
    log "Homebrew installed"
else
    log "Homebrew already installed: $(brew --version | head -1)"
fi

# ── Brew packages ────────────────────────────────────────────────────────────
BREW_PACKAGES=(sops age terraform)

for pkg in "${BREW_PACKAGES[@]}"; do
    if brew list "$pkg" &>/dev/null; then
        log "$pkg already installed: $(brew info --json=v2 "$pkg" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['formulae'][0]['installed'][0]['version'])" 2>/dev/null || echo 'version unknown')"
    else
        info "Installing $pkg..."
        brew install "$pkg"
        log "$pkg installed"
    fi
done

# ── Ansible ──────────────────────────────────────────────────────────────────
# Ansible is installed via pip (not brew) to allow pip-managed collections/plugins.
if command -v ansible &>/dev/null; then
    log "Ansible already installed: $(ansible --version | head -1)"
else
    info "Installing Ansible via pip..."
    pip3 install ansible --break-system-packages
    log "Ansible installed"
fi

# ── Ansible Galaxy collections ───────────────────────────────────────────────
COLLECTIONS=(community.sops community.general)

for col in "${COLLECTIONS[@]}"; do
    if ansible-galaxy collection list 2>/dev/null | grep -q "${col//.//}"; then
        log "Ansible collection $col already installed"
    else
        info "Installing Ansible collection $col..."
        ansible-galaxy collection install "$col"
        log "Ansible collection $col installed"
    fi
done

# ── SOPS / AGE key setup ─────────────────────────────────────────────────────
AGE_KEY_DIR="$HOME/.config/sops/age"
AGE_KEY_FILE="$AGE_KEY_DIR/keys.txt"

if [[ -f "$AGE_KEY_FILE" ]]; then
    log "AGE key already exists at $AGE_KEY_FILE"
else
    warn "No AGE key found at $AGE_KEY_FILE"
    echo ""
    echo "  You need an AGE private key to decrypt SOPS secrets."
    echo "  Options:"
    echo "    a) Copy your existing key:  cp /path/to/keys.txt $AGE_KEY_FILE"
    echo "    b) Generate a new key (then add the public key to .sops.yaml):"
    echo "       mkdir -p $AGE_KEY_DIR && age-keygen -o $AGE_KEY_FILE"
    echo ""
fi

# ── Shell environment setup ───────────────────────────────────────────────────
SHELL_RC="$HOME/.zshrc"
[[ -n "${BASH_VERSION:-}" ]] && SHELL_RC="$HOME/.bash_profile"

SOPS_EXPORT='export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"'
if grep -q "SOPS_AGE_KEY_FILE" "$SHELL_RC" 2>/dev/null; then
    log "SOPS_AGE_KEY_FILE already set in $SHELL_RC"
else
    echo "" >> "$SHELL_RC"
    echo "# SOPS/AGE — WilkesLiberty infra" >> "$SHELL_RC"
    echo "$SOPS_EXPORT" >> "$SHELL_RC"
    log "Added SOPS_AGE_KEY_FILE to $SHELL_RC"
    warn "Restart your shell or run: export SOPS_AGE_KEY_FILE=\"\$HOME/.config/sops/age/keys.txt\""
fi

# ── Repository structure check ────────────────────────────────────────────────
echo ""
info "Checking sibling repository structure..."

REPOS_DIR="$(cd "$(dirname "$0")/../.." && pwd)"  # ~/Repositories/

for repo in webcms ui; do
    if [[ -d "$REPOS_DIR/$repo" ]]; then
        log "Sibling repo found: $REPOS_DIR/$repo"
    else
        warn "Missing sibling repo: $REPOS_DIR/$repo"
        echo "    Clone with:"
        if [[ "$repo" == "webcms" ]]; then
            echo "      git clone git@github.com:wilkesliberty/webcms.git $REPOS_DIR/webcms"
        else
            echo "      git clone git@github.com:wilkesliberty/ui.git $REPOS_DIR/ui"
        fi
    fi
done

# ── Final summary ─────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  Bootstrap complete"
echo "============================================================"
echo ""
echo "Next steps:"
echo "  1. Ensure your AGE key is at: $AGE_KEY_FILE"
echo "  2. Verify decryption works:   sops -d ansible/inventory/group_vars/sso_secrets.yml"
echo "  3. Load Terraform secrets:    source scripts/load-terraform-secrets.sh"
echo "  4. Check full environment:    ./scripts/dev-environment-check.sh"
echo "  5. Deploy:                    cd ansible && make deploy"
echo ""
