#!/bin/bash

# import_existing_records.sh
# Generates Terraform import commands for all njalla_record_* resources in records.tf and mail_proton.tf
#
# To get record IDs from Njalla:
# 1. Log in to your Njalla dashboard at https://njal.la/
# 2. Navigate to the domain (wilkesliberty.com)
# 3. For each record, the ID is visible in the record details or can be obtained via API
# 4. Alternatively, use Njalla's API: https://njal.la/api/1/ (requires API key)
# 5. Replace <record_id> in the commands below with the actual numeric ID from Njalla
#
# Usage:
# 1. Run this script to see the commands: ./import_existing_records.sh
# 2. Execute each terraform import command individually, replacing <record_id>
# 3. After importing, run terraform plan to verify state matches configuration

echo "# Terraform import commands for existing DNS records"
echo "# Replace <record_id> with actual IDs from Njalla dashboard or API"
echo ""

# Records from records.tf
echo "# A records"
echo "terraform import njalla_record_a.apex <record_id>"
echo "terraform import njalla_record_a.www <record_id>"
echo "terraform import njalla_record_a.api <record_id>"
echo "terraform import njalla_record_a.auth <record_id>"
echo "terraform import njalla_record_a.search <record_id>"
echo ""

echo "# AAAA records (IPv6 — only if vps_ipv6 is set)"
echo "# Note: these use count=1, so Terraform's address includes the [0] index"
echo "terraform import 'njalla_record_aaaa.apex[0]' <record_id>"
echo "terraform import 'njalla_record_aaaa.www[0]' <record_id>"
echo "terraform import 'njalla_record_aaaa.api[0]' <record_id>"
echo "terraform import 'njalla_record_aaaa.auth[0]' <record_id>"
echo "terraform import 'njalla_record_aaaa.search[0]' <record_id>"
echo ""

echo "# CNAME records (records.tf)"
echo "terraform import njalla_record_cname.network <record_id>"
echo ""

# Records from mail_proton.tf
echo "# MX records"
echo "terraform import njalla_record_mx.mx_primary <record_id>"
echo "terraform import njalla_record_mx.mx_secondary <record_id>"
echo ""

echo "# TXT records"
echo "terraform import njalla_record_txt.proton_verification <record_id>"
echo "terraform import njalla_record_txt.spf <record_id>"
echo "terraform import njalla_record_txt.dmarc <record_id>"
echo "terraform import njalla_record_txt.domain_verification <record_id>"
echo ""

echo "# CNAME records"
echo "terraform import njalla_record_cname.dkim1 <record_id>"
echo "terraform import njalla_record_cname.dkim2 <record_id>"
echo "terraform import njalla_record_cname.dkim3 <record_id>"
echo ""

echo "# Notes:"
echo "# - Import commands must be run in the directory containing terraform configuration"
echo "# - Source secrets before running: source scripts/load-terraform-secrets-safe.sh"
echo "# - After importing, run 'terraform plan' to verify no changes are needed"
echo "# - The lifecycle prevent_destroy blocks in the .tf files will prevent accidental deletion"
echo "# - search and tailscale records are NEW — only import if they already exist in Njalla"
