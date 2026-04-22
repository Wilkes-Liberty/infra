#!/bin/bash
# Load Terraform secrets from SOPS-encrypted file into TF_VAR_* env vars.
# Usage: source scripts/load-terraform-secrets-safe.sh
#
# Uses 'return' so sourcing from bash or zsh doesn't kill the shell on error.
# Must be sourced (not executed) — exports only survive in the calling shell.

# git rev-parse works from any directory inside the repo, in both bash and zsh,
# whether sourced or executed. Avoids ${BASH_SOURCE[0]} which is unset in zsh.
PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$PROJECT_DIR" ]]; then
    echo "❌ Error: could not find repo root — run from inside the infra repo"
    return 1 2>/dev/null || exit 1
fi
SECRETS_FILE="$PROJECT_DIR/terraform_secrets.yml"

if [[ ! -f "$SECRETS_FILE" ]]; then
    echo "❌ Error: secrets file not found: $SECRETS_FILE"
    return 1 2>/dev/null || exit 1
fi

if ! command -v sops &>/dev/null; then
    echo "❌ Error: sops not found — run: brew install sops"
    return 1 2>/dev/null || exit 1
fi

if [[ -z "${SOPS_AGE_KEY_FILE:-}" ]]; then
    echo "❌ Error: SOPS_AGE_KEY_FILE not set"
    echo "   Add to ~/.zshrc: export SOPS_AGE_KEY_FILE=\"\$HOME/.config/sops/age/keys.txt\""
    return 1 2>/dev/null || exit 1
fi

echo "🔒 Loading Terraform secrets from SOPS..."

DECRYPTED_CONTENT="$(sops -d "$SECRETS_FILE" 2>/dev/null)"
if [[ $? -ne 0 || -z "$DECRYPTED_CONTENT" ]]; then
    echo "❌ Error: sops decryption failed — check your age key and SOPS_AGE_KEY_FILE"
    return 1 2>/dev/null || exit 1
fi

while IFS=': ' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    value="$(echo "$value" | sed "s/^[[:space:]]*[\"']*//;s/[\"']*[[:space:]]*\$//" | tr -d '\n')"
    [[ -z "$value" ]] && continue
    export "TF_VAR_${key}=${value}"
done <<< "$DECRYPTED_CONTENT"

# Verify the key variable actually landed
if [[ -z "${TF_VAR_njalla_api_token:-}" ]]; then
    echo "❌ Error: decryption succeeded but TF_VAR_njalla_api_token is empty — check terraform_secrets.yml"
    return 1 2>/dev/null || exit 1
fi

echo "✅ Terraform secrets loaded:"
echo "   TF_VAR_njalla_api_token          (set)"
echo "   TF_VAR_proton_verification_token (set)"
echo "   TF_VAR_proton_dkim1_target       (set)"
echo "   TF_VAR_proton_dkim2_target       (set)"
echo "   TF_VAR_proton_dkim3_target       (set)"
echo ""
echo "   terraform plan"
echo "   terraform apply"
