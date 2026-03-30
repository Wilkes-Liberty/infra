# Terraform DNS Quick Reference
**WilkesLiberty Infrastructure**

## 🚀 **Quick Start**

### **1. First Time Setup**

```bash
cd /Users/jcerda/Repositories/infra

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vi terraform.tfvars
```

**Fill in these required values:**

```hcl
njalla_api_token = "your-token-from-njalla"
vps_ipv4        = "1.2.3.4"  # Your VPS IP
```

### **2. Initialize Terraform**

```bash
# First time only - downloads Njalla provider
terraform init
```

### **3. Deploy DNS Records**

```bash
# Preview changes (always safe)
terraform plan

# Apply changes to Njalla DNS
terraform apply

# Auto-approve (skip confirmation)
terraform apply -auto-approve
```

---

## 📋 **Common Commands**

### **View Current DNS State**

```bash
# Show all Terraform-managed resources
terraform show

# Show state in JSON format
terraform show -json | jq

# List all resources
terraform state list
```

### **Update DNS Records**

```bash
# Edit terraform.tfvars (change IPs, etc.)
vi terraform.tfvars

# Preview changes
terraform plan

# Apply updates
terraform apply
```

### **Add New DNS Records**

```bash
# Edit records.tf
vi records.tf

# Add new resource, e.g.:
# resource "njalla_record_a" "staging" {
#   domain  = var.domain_name
#   name    = "staging"
#   content = var.vps_ipv4
#   ttl     = 3600
# }

# Apply changes
terraform plan
terraform apply
```

### **Enable Analytics Subdomain**

```bash
# Uncomment analytics records in records.tf (lines 82-95)
vi records.tf

# Apply changes
terraform apply
```

---

## 🗂️ **File Structure**

```
/Users/jcerda/Repositories/infra/
├── main.tf                    # Provider configuration
├── variables.tf               # Variable definitions
├── records.tf                 # DNS records
├── mail_proton.tf            # Proton Mail records
├── terraform.tfvars          # YOUR VALUES (gitignored)
├── terraform.tfvars.example  # Template
└── .terraform/               # Provider cache (auto-generated)
```

---

## 📝 **Current DNS Records**

### **Automatically Created:**

| Subdomain | Record Type | Points To | Purpose |
|-----------|-------------|-----------|---------|
| `@` (root) | A + AAAA | VPS IP | Redirects to www |
| `www` | A + AAAA | VPS IP | Next.js frontend |
| `api` | A + AAAA | VPS IP | Drupal GraphQL |
| `auth` | A + AAAA | VPS IP | Keycloak SSO |
| `@` | CAA x3 | Let's Encrypt | SSL enforcement |

### **Available (Commented Out):**

| Subdomain | Status | Purpose |
|-----------|--------|---------|
| `analytics` | 📝 Commented | Grafana dashboard (uncomment in records.tf) |

---

## 🔧 **Troubleshooting**

### **Provider Authentication Failed**

```bash
# Check your API token
grep njalla_api_token terraform.tfvars

# Verify token at Njalla:
# https://njal.la/settings/api/
```

### **Plan Shows Unexpected Changes**

```bash
# Refresh state from Njalla
terraform refresh

# Re-run plan
terraform plan
```

### **DNS Not Propagating**

```bash
# Check DNS propagation (usually 5-60 minutes)
dig @8.8.8.8 www.wilkesliberty.com
dig @1.1.1.1 api.wilkesliberty.com

# Force lower TTL for faster updates (edit records.tf)
# Change ttl from 3600 to 300
```

### **Destroy All DNS Records** (⚠️ DANGEROUS)

```bash
# Preview what will be deleted
terraform plan -destroy

# Delete all Terraform-managed DNS
terraform destroy
```

---

## 🔐 **Security Notes**

### **terraform.tfvars is Gitignored**

- ✅ Contains sensitive API tokens
- ✅ Already in `.gitignore`
- ❌ **NEVER commit to git**

### **Verify .gitignore:**

```bash
git check-ignore terraform.tfvars
# Should output: terraform.tfvars
```

### **CAA Records Enabled**

Terraform automatically enforces CAA records:
- ✅ Only Let's Encrypt can issue certificates
- ✅ Prevents rogue certificate authorities
- ✅ Email notifications to `security@wilkesliberty.com`

---

## 🎯 **After VPS Provisioning**

Once you provision your Njalla VPS:

```bash
# 1. Get VPS IP
ssh root@<vps-ip> "hostname -I"

# 2. Update terraform.tfvars
echo 'vps_ipv4 = "1.2.3.4"' >> terraform.tfvars

# 3. Deploy DNS
terraform plan
terraform apply

# 4. Verify DNS (wait 5-10 minutes)
dig www.wilkesliberty.com +short
dig api.wilkesliberty.com +short
dig auth.wilkesliberty.com +short

# Should all return your VPS IP
```

---

## 📚 **Additional Resources**

- **Njalla DNS Provider Docs**: https://registry.terraform.io/providers/Sighery/njalla/latest/docs
- **Terraform CLI Docs**: https://www.terraform.io/cli/commands
- **Full Setup Guide**: `docs/DNS_AND_SSL_SETUP.md`
