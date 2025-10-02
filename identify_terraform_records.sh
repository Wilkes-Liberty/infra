#!/bin/bash

# Script to identify which DNS records are managed by Terraform
# This will help you safely delete duplicate records from the Njalla UI

echo "==================================="
echo "🔍 TERRAFORM-MANAGED DNS RECORDS"
echo "==================================="
echo ""
echo "✅ These records are SAFE and managed by Terraform - DO NOT DELETE:"
echo ""

# Get Terraform-managed record IDs
terraform show -json 2>/dev/null | jq -r '.values.root_module.resources[] | select(.type | startswith("njalla_record")) | "Record ID: \(.values.id) - \(.values.name) (\(.type | split("_")[2] | ascii_upcase)) -> \(.values.content // (.values.content + " [Priority: " + (.values.priority | tostring) + "]" // "N/A"))"' | sort -n

echo ""
echo "==================================="
echo "🚨 HOW TO IDENTIFY DUPLICATES:"
echo "==================================="
echo ""
echo "1. Login to your Njalla control panel"
echo "2. Go to your wilkesliberty.com DNS management"
echo "3. Look for records with DIFFERENT IDs than those listed above"
echo "4. Pay special attention to:"
echo "   - Multiple DMARC records at _dmarc"
echo "   - Multiple SPF records at @ (apex)"
echo "   - Duplicate A/AAAA records for same hostnames"
echo "   - Duplicate CNAME records"
echo ""
echo "==================================="
echo "⚠️  CRITICAL SAFETY RULES:"
echo "==================================="
echo ""
echo "✅ SAFE TO DELETE: Any record NOT in the list above"
echo "🚨 NEVER DELETE: Records with IDs matching the list above"
echo "💡 TIP: Sort by Record ID in Njalla UI to easily compare"
echo ""
echo "==================================="
echo "🎯 PRIORITY DUPLICATES TO FIND:"
echo "==================================="
echo ""

# Check for known duplicates
echo "Checking current DNS for duplicates..."
echo ""

dmarc_count=$(dig +short _dmarc.wilkesliberty.com TXT | wc -l | tr -d ' ')
if [ "$dmarc_count" -gt 1 ]; then
    echo "🚨 DMARC: Found $dmarc_count records (should be 1)"
    echo "   Keep only ID: 1755448"
    echo ""
fi

spf_count=$(dig +short wilkesliberty.com TXT | grep "v=spf1" | wc -l | tr -d ' ')
if [ "$spf_count" -gt 1 ]; then
    echo "🚨 SPF: Found $spf_count SPF records (should be 1)"
    echo "   Keep only ID: 1755454"
    echo ""
fi

echo "==================================="
echo "🔧 TERRAFORM RECORD SUMMARY:"
echo "==================================="
terraform show -json 2>/dev/null | jq -r '.values.root_module.resources[] | select(.type | startswith("njalla_record")) | .values.id' | sort -n | wc -l | xargs echo "Total Terraform-managed records:"

echo ""
echo "Run this command after cleanup to verify:"
echo "terraform plan"
echo ""