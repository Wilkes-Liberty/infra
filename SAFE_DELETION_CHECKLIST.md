# 🛡️ Safe DNS Record Deletion Checklist

## ✅ TERRAFORM-MANAGED RECORDS (DO NOT DELETE)

Your Terraform manages **26 DNS records** with these specific IDs:

### 🔒 **PROTECTED RECORD IDs** - NEVER DELETE THESE:
```
1755422, 1755423, 1755424, 1755425, 1755426, 1755427, 1755428, 1755429, 
1755430, 1755431, 1755432, 1755433, 1755434, 1755435, 1755436, 1755437, 
1755438, 1755439, 1755440, 1755445, 1755446, 1755448, 1755450, 1755451, 
1755452, 1755454
```

## 🚨 CONFIRMED DUPLICATES TO DELETE

### **DMARC Duplicate**
- **Status**: ❌ Found 2 DMARC records (should be 1)
- **Keep**: Record ID `1755448` with enhanced policy
- **Delete**: Any other DMARC record at `_dmarc` with different ID

## 📋 STEP-BY-STEP DELETION PROCESS

### Step 1: Login to Njalla
1. Go to [Njalla Control Panel](https://njalla.com/domains/)
2. Select `wilkesliberty.com`
3. Navigate to DNS Management

### Step 2: Identify Duplicates
1. **Sort records by ID** (ascending order)
2. Look for records **NOT** in the protected list above
3. Focus on these common duplicate types:
   - Multiple records with same hostname but different IDs
   - Extra DMARC records
   - Extra SPF records
   - Duplicate MX records

### Step 3: Safe Deletion Rules
- ✅ **SAFE TO DELETE**: Any record with ID NOT in the protected list
- 🚨 **NEVER DELETE**: Records with IDs 1755422-1755454 (see full list above)
- ⚠️ **Double-check**: Before deleting, verify the record content doesn't match your Terraform config

### Step 4: Verification After Cleanup
Run these commands to verify cleanup was successful:

```bash
# Check for configuration drift
terraform plan

# Verify single DMARC record
dig +short _dmarc.wilkesliberty.com TXT | wc -l

# Verify single SPF record  
dig +short wilkesliberty.com TXT | grep "v=spf1" | wc -l
```

## 🎯 EXPECTED RESULTS AFTER CLEANUP

- **Terraform Plan**: Should show "No changes"
- **DMARC Records**: Exactly 1
- **SPF Records**: Exactly 1
- **Total DNS Records**: Only the 26 managed by Terraform

## 🆘 IF YOU ACCIDENTALLY DELETE A TERRAFORM RECORD

Don't panic! You can restore it:

```bash
# This will recreate any accidentally deleted records
terraform apply
```

## 🔍 QUICK VERIFICATION COMMANDS

```bash
# Check total Terraform records
terraform show -json | jq '.values.root_module.resources[] | select(.type | startswith("njalla_record")) | .values.id' | wc -l

# Check for DMARC duplicates
dig +short _dmarc.wilkesliberty.com TXT

# Run the identification script
./identify_terraform_records.sh
```

---
**Remember**: When in doubt, don't delete! The protected IDs list above is your safety net.