#!/bin/bash
# Load Terraform secrets from SOPS-encrypted file
# Usage: source scripts/load-terraform-secrets.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_FILE="$PROJECT_DIR/terraform_secrets.yml"

# Check if SOPS is available
if ! command -v sops &> /dev/null; then
    echo "❌ Error: sops command not found. Please install sops first."
    echo "   brew install sops"
    exit 1
fi

# Check if secrets file exists
if [[ ! -f "$SECRETS_FILE" ]]; then
    echo "❌ Error: Secrets file not found: $SECRETS_FILE"
    exit 1
fi

# Check if AGE key is configured
if [[ -z "${SOPS_AGE_KEY_FILE:-}" ]]; then
    echo "❌ Error: SOPS_AGE_KEY_FILE environment variable not set."
    echo "   export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt"
    exit 1
fi

if [[ ! -f "$SOPS_AGE_KEY_FILE" ]]; then
    echo "❌ Error: AGE key file not found: $SOPS_AGE_KEY_FILE"
    exit 1
fi

echo "🔒 Loading Terraform secrets from SOPS..."

# Decrypt secrets file
DECRYPTED_CONTENT=$(sops -d "$SECRETS_FILE")

# Parse YAML and export as Terraform variables
while IFS=': ' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    
    # Remove quotes and whitespace from value
    value=$(echo "$value" | sed 's/^[[:space:]]*["'\'']*//;s/["'\'']*[[:space:]]*$//' | tr -d '\n')
    
    # Skip empty values
    [[ -z "$value" ]] && continue
    
    # Export as TF_VAR_
    export "TF_VAR_${key}=${value}"
done <<< "$DECRYPTED_CONTENT"

echo "✅ Terraform secrets loaded successfully!"
echo "   Available variables:"
echo "   - TF_VAR_njalla_api_token"
echo "   - TF_VAR_proton_dkim1_target"
echo "   - TF_VAR_proton_dkim2_target" 
echo "   - TF_VAR_proton_dkim3_target"
echo ""
echo "💡 You can now run terraform commands normally:"
echo "   terraform plan"
echo "   terraform apply"