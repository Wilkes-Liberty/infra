#!/bin/bash
# Safe MX Record Restoration Script
# Checks for drift and restores MX records if they're missing at Njalla

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "🔍 MX Record Restoration Script"
echo "================================"
echo ""

# Load secrets
echo "🔒 Loading Terraform secrets..."
source "$SCRIPT_DIR/load-terraform-secrets-safe.sh"

if [[ -z "${TF_VAR_njalla_api_token:-}" ]]; then
    echo "❌ Error: API token not loaded"
    exit 1
fi

echo ""
echo "📋 Step 1: Checking current DNS state..."
echo "--------------------------------------"

# Check live DNS
MX_RECORDS=$(dig +short MX wilkesliberty.com 2>/dev/null || echo "")

if [[ -n "$MX_RECORDS" ]]; then
    echo "✅ MX records found in live DNS:"
    echo "$MX_RECORDS"
    echo ""
    read -p "❓ MX records already exist. Do you want to continue anyway? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "⏭️  Skipping - MX records already present"
        exit 0
    fi
else
    echo "⚠️  No MX records found in live DNS - they need to be restored!"
fi

echo ""
echo "📋 Step 2: Checking Terraform state..."
echo "--------------------------------------"

# Check if records are in Terraform state
PRIMARY_STATE=$(terraform state show njalla_record_mx.mx_primary 2>/dev/null || echo "missing")
SECONDARY_STATE=$(terraform state show njalla_record_mx.mx_secondary 2>/dev/null || echo "missing")

if [[ "$PRIMARY_STATE" == "missing" ]] || [[ "$SECONDARY_STATE" == "missing" ]]; then
    echo "⚠️  MX records missing from Terraform state!"
    echo "   This means they were never created or were removed."
else
    echo "✅ MX records found in Terraform state"
    echo "   Primary MX: $(echo "$PRIMARY_STATE" | grep 'content' | awk '{print $3}')"
    echo "   Secondary MX: $(echo "$SECONDARY_STATE" | grep 'content' | awk '{print $3}')"
fi

echo ""
echo "📋 Step 3: Planning changes..."
echo "--------------------------------------"

# Run targeted plan
echo "⏳ Running terraform plan (this may take 30-60 seconds)..."
PLAN_OUTPUT=$(timeout 60 terraform plan \
    -target=njalla_record_mx.mx_primary \
    -target=njalla_record_mx.mx_secondary \
    -no-color 2>&1 || echo "TIMEOUT")

if [[ "$PLAN_OUTPUT" == "TIMEOUT" ]]; then
    echo "❌ Error: Terraform plan timed out (Njalla API may be slow)"
    echo ""
    echo "🛠️  Alternative: Manual Fix via Njalla Web UI"
    echo "   1. Go to https://njal.la/"
    echo "   2. Select domain: wilkesliberty.com"
    echo "   3. Add MX records:"
    echo "      - Priority 10: mail.protonmail.ch."
    echo "      - Priority 20: mailsec.protonmail.ch."
    exit 1
fi

# Show plan summary
echo "$PLAN_OUTPUT" | grep -A 20 "Terraform will perform"
echo ""

# Check if plan shows changes
if echo "$PLAN_OUTPUT" | grep -q "No changes"; then
    echo "✅ No changes needed - records are already in sync!"
    exit 0
fi

# Count changes
TO_ADD=$(echo "$PLAN_OUTPUT" | grep -c "will be created" || echo "0")
TO_UPDATE=$(echo "$PLAN_OUTPUT" | grep -c "will be updated" || echo "0")
TO_DESTROY=$(echo "$PLAN_OUTPUT" | grep -c "will be destroyed" || echo "0")

echo "📊 Planned changes:"
echo "   - Records to add: $TO_ADD"
echo "   - Records to update: $TO_UPDATE"
echo "   - Records to destroy: $TO_DESTROY"
echo ""

if [[ "$TO_DESTROY" -gt 0 ]]; then
    echo "⚠️  WARNING: Plan includes record deletions!"
    read -p "❓ Are you sure you want to proceed? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "⏭️  Aborted by user"
        exit 0
    fi
fi

echo "📋 Step 4: Applying changes..."
echo "--------------------------------------"
read -p "🚀 Apply these changes to restore MX records? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "⏭️  Aborted by user"
    exit 0
fi

echo "⏳ Applying Terraform changes..."
terraform apply \
    -target=njalla_record_mx.mx_primary \
    -target=njalla_record_mx.mx_secondary \
    -auto-approve

echo ""
echo "✅ Terraform apply complete!"
echo ""

echo "📋 Step 5: Verifying restoration..."
echo "--------------------------------------"
echo "⏳ Waiting 10 seconds for DNS propagation..."
sleep 10

echo "🔍 Checking live DNS..."
MX_RECORDS_AFTER=$(dig +short MX wilkesliberty.com 2>/dev/null || echo "")

if [[ -n "$MX_RECORDS_AFTER" ]]; then
    echo "✅ SUCCESS! MX records are now live:"
    echo "$MX_RECORDS_AFTER"
    echo ""
    echo "📧 You should now be able to receive emails at 3@wilkesliberty.com"
    echo "   Note: Full DNS propagation may take up to 1 hour"
else
    echo "⚠️  MX records not yet visible in DNS"
    echo "   This is normal - DNS propagation can take 5-60 minutes"
    echo "   Check again with: dig MX wilkesliberty.com +short"
fi

echo ""
echo "🎉 MX record restoration complete!"
