#!/bin/bash
# Securely copy SOPS/AGE keys to on-prem server
# This allows Terraform and Ansible to decrypt secrets on the on-prem server

set -euo pipefail

echo "🔐 SOPS/AGE Key Copy to On-Prem Server"
echo "========================================"
echo ""

# Verify source AGE key exists
AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

if [[ ! -f "$AGE_KEY_FILE" ]]; then
    echo "❌ Error: AGE key file not found at: $AGE_KEY_FILE"
    echo ""
    echo "Expected location: ~/.config/sops/age/keys.txt"
    echo "Set SOPS_AGE_KEY_FILE if it's in a different location"
    exit 1
fi

echo "✅ Found AGE key file: $AGE_KEY_FILE"
echo ""

# Show key info (public key only)
PUBLIC_KEY=$(grep "public key:" "$AGE_KEY_FILE" | awk '{print $4}')
echo "📋 Public key: $PUBLIC_KEY"
echo ""

# Prompt for on-prem server connection info
read -p "On-prem server hostname or IP (e.g., onprem.local or 192.168.1.100): " ONPREM_HOST
read -p "On-prem server username (default: jcerda): " ONPREM_USER
ONPREM_USER=${ONPREM_USER:-jcerda}

echo ""
echo "📋 Connection details:"
echo "   Host: $ONPREM_HOST"
echo "   User: $ONPREM_USER"
echo ""

# Test SSH connectivity
echo "🔍 Testing SSH connectivity..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "${ONPREM_USER}@${ONPREM_HOST}" "echo '✅ SSH connection successful'" 2>/dev/null; then
    echo "⚠️  SSH key authentication failed or not configured"
    echo ""
    echo "You'll be prompted for password during copy."
    echo "To avoid this in the future, set up SSH key authentication:"
    echo "  ssh-copy-id ${ONPREM_USER}@${ONPREM_HOST}"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo ""
echo "🔄 Step 1: Creating SOPS directory on on-prem server..."
ssh "${ONPREM_USER}@${ONPREM_HOST}" "mkdir -p ~/.config/sops/age && chmod 700 ~/.config/sops ~/.config/sops/age"

echo "✅ Directory created"
echo ""

echo "🔄 Step 2: Copying AGE private key..."
scp "$AGE_KEY_FILE" "${ONPREM_USER}@${ONPREM_HOST}:~/.config/sops/age/keys.txt"

echo "✅ Key copied"
echo ""

echo "🔄 Step 3: Setting correct permissions on on-prem server..."
ssh "${ONPREM_USER}@${ONPREM_HOST}" "chmod 600 ~/.config/sops/age/keys.txt"

echo "✅ Permissions set"
echo ""

echo "🔄 Step 4: Verifying key on on-prem server..."
REMOTE_PUBLIC_KEY=$(ssh "${ONPREM_USER}@${ONPREM_HOST}" "grep 'public key:' ~/.config/sops/age/keys.txt | awk '{print \$4}'")

if [[ "$PUBLIC_KEY" == "$REMOTE_PUBLIC_KEY" ]]; then
    echo "✅ Key verification successful!"
    echo "   Public key matches: $PUBLIC_KEY"
else
    echo "❌ Error: Key mismatch!"
    echo "   Local:  $PUBLIC_KEY"
    echo "   Remote: $REMOTE_PUBLIC_KEY"
    exit 1
fi

echo ""
echo "🔄 Step 5: Setting SOPS_AGE_KEY_FILE environment variable on on-prem server..."

# Add to .zshrc if not already there
ssh "${ONPREM_USER}@${ONPREM_HOST}" << 'ENDSSH'
if ! grep -q "SOPS_AGE_KEY_FILE" ~/.zshrc 2>/dev/null; then
    echo "" >> ~/.zshrc
    echo "# SOPS/AGE encryption" >> ~/.zshrc
    echo "export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt" >> ~/.zshrc
    echo "✅ Added SOPS_AGE_KEY_FILE to ~/.zshrc"
else
    echo "ℹ️  SOPS_AGE_KEY_FILE already in ~/.zshrc"
fi
ENDSSH

echo ""
echo "🔄 Step 6: Testing SOPS decryption on on-prem server..."

# Copy a test encrypted file to verify
if [[ -f "terraform_secrets.yml" ]]; then
    echo "   Copying terraform_secrets.yml for testing..."
    scp terraform_secrets.yml "${ONPREM_USER}@${ONPREM_HOST}:~/terraform_secrets_test.yml"

    ssh "${ONPREM_USER}@${ONPREM_HOST}" << 'ENDSSH'
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
if sops -d ~/terraform_secrets_test.yml > /dev/null 2>&1; then
    echo "✅ SOPS decryption test successful!"
    rm ~/terraform_secrets_test.yml
else
    echo "❌ SOPS decryption test FAILED"
    exit 1
fi
ENDSSH

    if [[ $? -eq 0 ]]; then
        echo "✅ Decryption verified on on-prem server"
    else
        echo "❌ Decryption test failed"
        exit 1
    fi
fi

echo ""
echo "✅ SOPS/AGE setup complete on on-prem server!"
echo ""

echo "📋 Next steps on on-prem server:"
echo ""
echo "1. SSH to on-prem server:"
echo "   ssh ${ONPREM_USER}@${ONPREM_HOST}"
echo ""
echo "2. Clone the infra repo (if not already there):"
echo "   git clone <repo-url> ~/Repositories/infra"
echo ""
echo "3. Install required tools:"
echo "   brew install sops age terraform ansible"
echo "   ansible-galaxy collection install community.sops"
echo "   ansible-galaxy collection install community.general"
echo ""
echo "4. Test SOPS decryption:"
echo "   cd ~/Repositories/infra"
echo "   sops -d terraform_secrets.yml"
echo ""
echo "5. Load secrets and run Terraform:"
echo "   source scripts/load-terraform-secrets-safe.sh"
echo "   terraform plan"
echo ""
echo "🎉 You can now manage infrastructure from the on-prem server!"
