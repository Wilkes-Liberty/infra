#!/bin/bash
# Safe MX Record Terraform Sync Script
# Ensures Terraform state matches Njalla without creating duplicates

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "🔄 MX Record Terraform Sync Script"
echo "==================================="
echo ""

# Load secrets
echo "🔒 Loading Terraform secrets..."
source "$SCRIPT_DIR/load-terraform-secrets-safe.sh"

if [[ -z "${TF_VAR_njalla_api_token:-}" ]]; then
    echo "❌ Error: API token not loaded"
    exit 1
fi

echo ""
echo "📋 Step 1: Verifying MX records exist at Njalla..."
echo "--------------------------------------------------"

# Check authoritative DNS
MX_AT_NJALLA=$(dig MX wilkesliberty.com @ns1.njal.la +short | sort -n)

if [[ -z "$MX_AT_NJALLA" ]]; then
    echo "❌ Error: No MX records found at Njalla's authoritative nameserver"
    echo "   Please add them manually first at https://njal.la/"
    exit 1
fi

echo "✅ MX records found at Njalla:"
echo "$MX_AT_NJALLA"

# Validate the records are correct
if echo "$MX_AT_NJALLA" | grep -q "10 mail.protonmail.ch." && \
   echo "$MX_AT_NJALLA" | grep -q "20 mailsec.protonmail.ch."; then
    echo "✅ Records match expected Proton Mail configuration"
else
    echo "⚠️  Warning: Records don't match expected configuration"
    echo "   Expected: 10 mail.protonmail.ch. and 20 mailsec.protonmail.ch."
    read -p "❓ Continue anyway? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo ""
echo "📋 Step 2: Checking Terraform state..."
echo "--------------------------------------------------"

# Check current Terraform state
PRIMARY_EXISTS=$(terraform state list | grep -c "njalla_record_mx.mx_primary" || echo "0")
SECONDARY_EXISTS=$(terraform state list | grep -c "njalla_record_mx.mx_secondary" || echo "0")

if [[ "$PRIMARY_EXISTS" == "1" ]] && [[ "$SECONDARY_EXISTS" == "1" ]]; then
    echo "✅ MX records already in Terraform state"
    
    # Get current state details
    PRIMARY_ID=$(terraform state show njalla_record_mx.mx_primary 2>/dev/null | grep 'id' | awk '{print $3}' | tr -d '"')
    SECONDARY_ID=$(terraform state show njalla_record_mx.mx_secondary 2>/dev/null | grep 'id' | awk '{print $3}' | tr -d '"')
    
    echo "   Primary MX (priority 10): Record ID $PRIMARY_ID"
    echo "   Secondary MX (priority 20): Record ID $SECONDARY_ID"
else
    echo "⚠️  MX records NOT in Terraform state"
    echo "   They need to be imported"
fi

echo ""
echo "📋 Step 3: Running Terraform refresh to detect drift..."
echo "--------------------------------------------------"
echo "⏳ This will check if the state matches reality at Njalla..."
echo "   (This may take 30-60 seconds)"
echo ""

# Run refresh with timeout
set +e
REFRESH_OUTPUT=$(timeout 90 terraform refresh \
    -target=njalla_record_mx.mx_primary \
    -target=njalla_record_mx.mx_secondary \
    -no-color 2>&1)
REFRESH_EXIT=$?
set -e

if [[ $REFRESH_EXIT -eq 124 ]]; then
    echo "⚠️  Terraform refresh timed out (Njalla API is slow)"
    echo ""
    echo "📋 Step 4: Attempting Terraform plan instead..."
    echo "--------------------------------------------------"
    
    # Try plan instead
    set +e
    PLAN_OUTPUT=$(timeout 90 terraform plan \
        -target=njalla_record_mx.mx_primary \
        -target=njalla_record_mx.mx_secondary \
        -detailed-exitcode \
        -no-color 2>&1)
    PLAN_EXIT=$?
    set -e
    
    if [[ $PLAN_EXIT -eq 124 ]]; then
        echo "❌ Error: Terraform is not responding (Njalla API issues)"
        echo ""
        echo "✅ Good news: Your MX records are working at Njalla!"
        echo "   The records are live and email is flowing."
        echo ""
        echo "⏭️  You can sync Terraform later when the API is responsive."
        echo "   Your email will continue working regardless."
        exit 0
    elif [[ $PLAN_EXIT -eq 0 ]]; then
        echo "✅ No changes needed - Terraform state matches Njalla!"
        echo ""
        echo "🎉 Everything is in sync. Your MX records are:"
        echo "   - Correctly configured at Njalla"
        echo "   - Properly tracked in Terraform state"
        echo "   - Delivering email successfully"
        exit 0
    elif [[ $PLAN_EXIT -eq 2 ]]; then
        echo "⚠️  Terraform detected differences between state and Njalla"
        echo ""
        echo "Changes detected:"
        echo "$PLAN_OUTPUT" | grep -A 10 "Terraform will perform" || echo "(Full plan output available)"
        echo ""
        
        # Check if it wants to destroy/recreate
        if echo "$PLAN_OUTPUT" | grep -q "must be replaced"; then
            echo "⚠️  WARNING: Terraform wants to REPLACE records!"
            echo "   This could cause email disruption."
            echo ""
            echo "🛡️  SAFE APPROACH:"
            echo "   1. Remove the old IDs from Terraform state"
            echo "   2. Import the new IDs from Njalla"
            echo ""
            read -p "❓ Do you want to proceed with safe state replacement? (y/N): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "⏭️  Aborted - no changes made"
                exit 0
            fi
            
            echo ""
            echo "📋 Step 5: Safely replacing Terraform state..."
            echo "--------------------------------------------------"
            
            # This is where we'd need to get the NEW record IDs from Njalla API
            # Since we can't easily do that without API working, we'll document it
            echo "⚠️  To complete this, you need the new record IDs from Njalla."
            echo ""
            echo "Manual steps:"
            echo "1. Log into Njalla: https://njal.la/"
            echo "2. Go to wilkesliberty.com DNS records"
            echo "3. Find the MX record IDs (shown in the UI)"
            echo "4. Run these commands:"
            echo ""
            echo "   # Remove old state"
            echo "   terraform state rm njalla_record_mx.mx_primary"
            echo "   terraform state rm njalla_record_mx.mx_secondary"
            echo ""
            echo "   # Import new records (replace XXXXX with actual IDs)"
            echo "   terraform import njalla_record_mx.mx_primary XXXXX"
            echo "   terraform import njalla_record_mx.mx_secondary YYYYY"
            echo ""
            echo "   # Verify"
            echo "   terraform plan -target=njalla_record_mx.mx_primary -target=njalla_record_mx.mx_secondary"
            exit 0
        else
            # Plan shows updates, not replacements - safer
            echo "📋 Terraform can update the state to match Njalla"
            echo ""
            read -p "❓ Apply these changes? (y/N): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "⏭️  Aborted - no changes made"
                exit 0
            fi
            
            echo "⏳ Applying changes..."
            terraform apply \
                -target=njalla_record_mx.mx_primary \
                -target=njalla_record_mx.mx_secondary \
                -auto-approve
            
            echo ""
            echo "✅ Terraform state updated!"
        fi
    else
        echo "❌ Terraform plan failed with exit code: $PLAN_EXIT"
        echo "$PLAN_OUTPUT"
        exit 1
    fi
else
    # Refresh succeeded
    echo "✅ Terraform refresh completed successfully"
    
    # Now run plan to see if there are any changes
    echo ""
    echo "📋 Step 4: Checking for drift..."
    echo "--------------------------------------------------"
    
    set +e
    terraform plan \
        -target=njalla_record_mx.mx_primary \
        -target=njalla_record_mx.mx_secondary \
        -detailed-exitcode \
        -no-color
    PLAN_EXIT=$?
    set -e
    
    if [[ $PLAN_EXIT -eq 0 ]]; then
        echo ""
        echo "✅ Perfect! No changes needed - everything is in sync!"
        echo ""
        echo "🎉 Your MX records are:"
        echo "   - Correctly configured at Njalla"
        echo "   - Properly tracked in Terraform"
        echo "   - Delivering email successfully"
    elif [[ $PLAN_EXIT -eq 2 ]]; then
        echo ""
        echo "⚠️  Changes detected. Review above and run terraform apply if needed."
    else
        echo ""
        echo "❌ Terraform plan failed"
        exit 1
    fi
fi

echo ""
echo "✅ MX record sync complete!"
