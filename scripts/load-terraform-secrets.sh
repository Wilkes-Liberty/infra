#!/bin/bash
# Load Terraform secrets from SOPS-encrypted file into TF_VAR_* env vars.
# Usage: source scripts/load-terraform-secrets.sh
#
# Must be sourced (not executed) — exports only survive in the calling shell.

load_terraform_secrets() {
    # git rev-parse works from any directory inside the repo, in both bash and zsh.
    # The old $(pwd)-based approach broke when not run from the exact repo root.
    local PROJECT_DIR
    PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"
    if [[ -z "$PROJECT_DIR" ]]; then
        echo "❌ Error: could not find repo root — run from inside the infra repo"
        return 1
    fi

    local SECRETS_FILE="$PROJECT_DIR/terraform_secrets.yml"

    if ! command -v sops &>/dev/null; then
        echo "❌ Error: sops not found — run: brew install sops"
        return 1
    fi

    if [[ ! -f "$SECRETS_FILE" ]]; then
        echo "❌ Error: secrets file not found: $SECRETS_FILE"
        return 1
    fi

    if [[ -z "${SOPS_AGE_KEY_FILE:-}" ]]; then
        echo "❌ Error: SOPS_AGE_KEY_FILE not set"
        echo "   Add to ~/.zshrc: export SOPS_AGE_KEY_FILE=\"\$HOME/.config/sops/age/keys.txt\""
        return 1
    fi

    echo "🔒 Loading Terraform secrets from SOPS..."

    local DECRYPTED_CONTENT
    DECRYPTED_CONTENT="$(sops -d "$SECRETS_FILE" 2>/dev/null)"
    if [[ $? -ne 0 || -z "$DECRYPTED_CONTENT" ]]; then
        echo "❌ Error: sops decryption failed — check your age key and SOPS_AGE_KEY_FILE"
        return 1
    fi

    while IFS=': ' read -r key value; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        value="$(echo "$value" | sed "s/^[[:space:]]*[\"']*//;s/[\"']*[[:space:]]*\$//" | tr -d '\n')"
        [[ -z "$value" ]] && continue
        export "TF_VAR_${key}=${value}"
    done <<< "$DECRYPTED_CONTENT"

    if [[ -z "${TF_VAR_njalla_api_token:-}" ]]; then
        echo "❌ Error: decryption succeeded but TF_VAR_njalla_api_token is empty — check terraform_secrets.yml"
        return 1
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
}

load_terraform_secrets
