# DNS Migration Safety Checklist
**WilkesLiberty - DNS to Terraform**

## ⚠️ **IMPORTANT: Read Before Running Terraform**

This checklist ensures we don't accidentally delete critical DNS records.

---

## ✅ **Pre-Migration Checklist**

### **1. Backup Current DNS** (CRITICAL)

Your current DNS records are documented above. Keep this for reference.

**What will be KEPT:**
- ✅ All Proton Mail records (MX, SPF, DKIM, DMARC)
- ✅ Domain verification TXT record
- ✅ ACME challenge records (temporary, auto-managed)

**What will be CHANGED:**
- 🔄 Apex A/AAAA records (will point to new VPS when provisioned)
- 🔄 www, api, auth (will become A records to new VPS)

**What will be DELETED:**
- ❌ Old infrastructure: analytics1.prod, app1.prod, cache1.prod, db1.prod, search1.prod, sso1.prod
- ❌ Old CNAMEs: sso, stats

### **2. Verify Terraform Files**

```bash
cd /Users/jcerda/Repositories/infra

# Verify all Terraform files exist
ls -l *.tf
# Should show:
# - main.tf (provider config)
# - variables.tf (variable definitions)
# - records.tf (new single VPS DNS)
# - mail_proton.tf (Proton Mail records)
# - misc.tf (domain verification)
```

### **3. Configure terraform.tfvars**

```bash
# Copy current values with Proton Mail settings
cp terraform.tfvars.current terraform.tfvars

# Edit to add your DNS API token
vi terraform.tfvars

# Required NOW:
# - njalla_api_token = "YOUR_TOKEN"
# - proton_* values (already filled in)

# Required LATER (after VPS provisioning):
# - vps_ipv4 = "your-vps-ip"
```

### **4. Initialize Terraform**

```bash
# Download DNS provider
terraform init

# Verify provider installed
terraform version
terraform providers
```

---

## 🧪 **DRY RUN (Safe Preview)**

### **Step 1: Plan WITHOUT VPS IP** (Will Show Errors - That's OK)

This validates your API token and shows what Terraform wants to do:

```bash
# This will fail because vps_ipv4 is empty, but that's expected
terraform plan

# Expected output:
# - Error about vps_ipv4 variable
# - OR preview showing what will be added/changed/deleted
```

**What to look for:**
- ✅ Proton Mail records should show "no changes" or "in sync"
- ✅ Old infrastructure records should show "destroy"
- ⚠️ If Proton Mail shows changes, STOP and review

### **Step 2: Comment Out Infrastructure Records Temporarily**

To test ONLY the mail/misc records first:

```bash
# Edit records.tf
vi records.tf

# Comment out ALL service records (lines 12-95)
# Keep only the comments/notes at the bottom
```

Then:

```bash
# Plan again - should only show mail + misc records
terraform plan

# Expected output:
# Plan: 9 to add, 0 to change, 0 to destroy
# (MX x2, TXT x3, CNAME x3, misc TXT x1)
```

---

## 🚨 **Safety Gates**

### **Gate 1: Verify Proton Mail Records**

```bash
# After terraform plan, verify these are UNCHANGED:
# - MX mail.protonmail.ch
# - MX mailsec.protonmail.ch
# - TXT protonmail-verification
# - TXT SPF v=spf1 include:_spf.protonmail.ch
# - TXT DMARC v=DMARC1; p=quarantine
# - CNAME protonmail._domainkey
# - CNAME protonmail2._domainkey
# - CNAME protonmail3._domainkey
```

**If ANY of these show as "destroy" or "change", STOP!**

### **Gate 2: Review What Will Be Deleted**

```bash
# Check the terraform plan output for "destroy" actions
terraform plan | grep "destroy"

# Expected to be destroyed:
# - analytics1.prod.wilkesliberty.com (A + AAAA)
# - app1.prod.wilkesliberty.com (A + AAAA)
# - cache1.prod.wilkesliberty.com (A + AAAA)
# - db1.prod.wilkesliberty.com (A + AAAA)
# - search1.prod.wilkesliberty.com (A + AAAA)
# - sso1.prod.wilkesliberty.com (A + AAAA)
# - sso.wilkesliberty.com (CNAME)
# - stats.wilkesliberty.com (CNAME)
```

**If mail records appear here, STOP!**

### **Gate 3: Manual DNS Queries**

Before applying, verify current DNS:

```bash
# Check that these currently work
dig wilkesliberty.com MX +short
dig wilkesliberty.com TXT +short
dig www.wilkesliberty.com +short
dig api.wilkesliberty.com +short

# Save output to compare after migration
```

---

## 📝 **Migration Steps (When Ready)**

### **Phase 1: Import Mail Records Only** (Safest)

```bash
# With records.tf commented out, apply mail + misc only
terraform plan    # Verify only mail/misc changes
terraform apply   # Type "yes" to confirm

# Verify mail still works
dig wilkesliberty.com MX +short
# Should return: mail.protonmail.ch, mailsec.protonmail.ch
```

### **Phase 2: Wait to Provision VPS**

**DO NOT proceed to Phase 3 until:**
1. ✅ Njalla VPS is provisioned
2. ✅ VPS public IP is known
3. ✅ terraform.tfvars has `vps_ipv4 = "actual-ip"`

### **Phase 3: Add Infrastructure Records**

```bash
# Uncomment records.tf service records
vi records.tf

# Update terraform.tfvars with VPS IP
vi terraform.tfvars
# Set: vps_ipv4 = "your-actual-vps-ip"

# Plan and review
terraform plan

# Should show:
# - Add: @, www, api, auth A records
# - Destroy: Old infrastructure records

# Apply when ready
terraform apply
```

---

## 🆘 **Rollback Plan**

If something goes wrong:

### **Option 1: Terraform Destroy**

```bash
# Remove all Terraform-managed records
terraform destroy

# Manually recreate critical records in Njalla web UI:
# - MX records
# - SPF, DKIM, DMARC
# - www, api A records
```

### **Option 2: Manual Njalla Restore**

You have the full list of current DNS records above. Manually add them back via Njalla web UI.

### **Option 3: Terraform State Manipulation**

```bash
# Remove problematic resources from state
terraform state list
terraform state rm <resource_name>

# Manually fix in Njalla, then re-import
terraform import <resource> <id>
```

---

## ✅ **Post-Migration Verification**

```bash
# Verify DNS propagation (wait 5-10 minutes)
dig wilkesliberty.com MX +short
dig wilkesliberty.com TXT +short | grep spf
dig www.wilkesliberty.com +short
dig api.wilkesliberty.com +short
dig auth.wilkesliberty.com +short

# Test mail (send test email)
echo "Test" | mail -s "DNS Migration Test" your-email@wilkesliberty.com

# Verify Terraform state
terraform show
terraform state list
```

---

## 📊 **Expected Final State**

| Record Type | Name | Target | Status |
|-------------|------|--------|--------|
| A | @ | VPS IPv4 | ✅ Terraform |
| A | www | VPS IPv4 | ✅ Terraform |
| A | api | VPS IPv4 | ✅ Terraform |
| A | auth | VPS IPv4 | ✅ Terraform |
| MX | @ | mail.protonmail.ch | ✅ Terraform |
| MX | @ | mailsec.protonmail.ch | ✅ Terraform |
| TXT | @ | SPF record | ✅ Terraform |
| TXT | @ | protonmail-verification | ✅ Terraform |
| TXT | @ | domain-verification | ✅ Terraform |
| TXT | _dmarc | DMARC policy | ✅ Terraform |
| CNAME | protonmail._domainkey | Proton DKIM1 | ✅ Terraform |
| CNAME | protonmail2._domainkey | Proton DKIM2 | ✅ Terraform |
| CNAME | protonmail3._domainkey | Proton DKIM3 | ✅ Terraform |
| CAA | @ | letsencrypt.org | ✅ Terraform |
| TXT | _acme-challenge.* | (various) | ⚠️ Manual (temp) |

**Deleted (expected):**
- ❌ All *.prod.wilkesliberty.com A/AAAA records
- ❌ sso/stats CNAMEs

---

## 🎯 **Success Criteria**

- ✅ All Proton Mail records intact and functioning
- ✅ Email sending/receiving works
- ✅ SPF/DKIM/DMARC passing
- ✅ Domain verification intact
- ✅ Old infrastructure records removed
- ✅ Terraform managing all DNS (except ACME challenges)
- ✅ CAA records enforcing Let's Encrypt

**Test email authentication:**
- Send email from Proton Mail
- Check headers at https://www.mail-tester.com/
- Should show: SPF pass, DKIM pass, DMARC pass
