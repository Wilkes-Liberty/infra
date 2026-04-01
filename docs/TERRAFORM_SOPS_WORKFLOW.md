# Terraform + SOPS Secrets Workflow
**WilkesLiberty Infrastructure**

## 🔐 **Security Architecture**

All sensitive values are stored in **SOPS-encrypted** `terraform_secrets.yml`:
- ✅ DNS provider API token (`njalla_api_token`)
- ✅ Proton Mail DKIM targets (3)
- ✅ Proton Mail verification token

These are loaded as **environment variables** (`TF_VAR_*`) which Terraform reads automatically.

---

## 📋 **Complete Workflow**

### **Step 1: Load Secrets from SOPS**

```bash
cd /Users/jcerda/Repositories/infra

# Load secrets as environment variables
source scripts/load-terraform-secrets.sh
```

**Output:**
```
🔒 Loading Terraform secrets from SOPS...
✅ Terraform secrets loaded successfully!
   Available variables:
   - TF_VAR_njalla_api_token  (DNS provider API token)
   - TF_VAR_proton_dkim1_target
   - TF_VAR_proton_dkim2_target
   - TF_VAR_proton_dkim3_target

💡 You can now run terraform commands normally:
   terraform plan
   terraform apply
```

### **Step 2: Initialize Terraform** (First Time Only)

```bash
terraform init
```

### **Step 3: Preview Changes** (Safe - No Changes)

```bash
# This will show what Terraform wants to do
terraform plan

# Expected: Error about vps_ipv4 being empty (that's OK for now)
```

### **Step 4: When VPS is Ready**

After provisioning your Njalla VPS:

```bash
# Edit terraform.tfvars to add VPS IP
vi terraform.tfvars

# Change:
# vps_ipv4 = ""
# To:
# vps_ipv4 = "your-actual-vps-ip"

# Then run plan/apply
source scripts/load-terraform-secrets.sh
terraform plan
terraform apply
```

---

## 🗂️ **File Structure**

```
/Users/jcerda/Repositories/infra/
├── terraform_secrets.yml              # SOPS-encrypted secrets
├── terraform.tfvars                   # Only VPS IP (not sensitive)
├── scripts/
│   └── load-terraform-secrets.sh      # Loads SOPS → TF_VAR_*
├── main.tf                            # Terraform provider
├── variables.tf                       # Variable definitions
├── records.tf                         # DNS records
├── mail_proton.tf                     # Proton Mail records
└── misc.tf                            # Domain verification
```

---

## 🔑 **What's in Each File**

### **terraform_secrets.yml** (SOPS-encrypted)

```yaml
# Encrypted with AGE
njalla_api_token: da58004e...
proton_dkim1_target: protonmail.domainkey...
proton_dkim2_target: protonmail2.domainkey...
proton_dkim3_target: protonmail3.domainkey...
proton_verification_token: bbae3ac7...
```

**Edit with:** `sops terraform_secrets.yml`

### **terraform.tfvars** (Minimal, only VPS IP)

```hcl
# Only non-secret values here
vps_ipv4 = ""  # TODO: Fill after VPS provisioning
vps_ipv6 = ""  # Optional
```

---

## 📝 **Common Tasks**

### **View Decrypted Secrets**

```bash
sops --decrypt terraform_secrets.yml
```

### **Edit Secrets**

```bash
sops terraform_secrets.yml
# Opens your $EDITOR with decrypted content
# Saves back encrypted when you exit
```

### **Add New Secret**

```bash
sops terraform_secrets.yml
# Add new line, e.g.:
# new_secret: value
```

Then update `scripts/load-terraform-secrets.sh` to export it.

### **Test Terraform Without Applying**

```bash
source scripts/load-terraform-secrets.sh
terraform plan
```

### **Apply DNS Changes**

```bash
source scripts/load-terraform-secrets.sh
terraform apply
```

---

## 🔄 **Daily Workflow**

```bash
# 1. Load secrets (do this once per shell session)
source scripts/load-terraform-secrets.sh

# 2. Make changes to Terraform files
vi records.tf

# 3. Preview changes
terraform plan

# 4. Apply changes
terraform apply

# Secrets remain loaded for the shell session
# Re-run "source scripts/load-terraform-secrets.sh" if you open a new terminal
```

---

## 🛡️ **Security Benefits**

| Aspect | Status |
|--------|--------|
| **API token in plaintext** | ❌ Never - encrypted with SOPS/AGE |
| **Committed to git** | ❌ Never - terraform_secrets.yml is encrypted |
| **Environment variables** | ✅ Only in current shell session |
| **terraform.tfvars plaintext** | ✅ Only non-sensitive data (VPS IP) |
| **AGE key location** | `~/.config/sops/age/keys.txt` (private) |

---

## 🆘 **Troubleshooting**

### **Error: SOPS_AGE_KEY_FILE not set**

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
# Add to ~/.zshrc to make permanent
echo 'export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt' >> ~/.zshrc
```

### **Error: Failed to decrypt secrets file**

```bash
# Verify AGE key exists
ls -la ~/.config/sops/age/keys.txt

# Verify SOPS can decrypt
sops --decrypt terraform_secrets.yml
```

### **Error: vps_ipv4 variable is empty**

This is expected until you provision a VPS. Edit `terraform.tfvars`:

```bash
vi terraform.tfvars
# Set: vps_ipv4 = "your-actual-ip"
```

### **Secrets not loaded**

Make sure you **source** the script (not just run it):

```bash
# ✅ Correct
source scripts/load-terraform-secrets.sh

# ❌ Wrong (won't export to current shell)
./scripts/load-terraform-secrets.sh
bash scripts/load-terraform-secrets.sh
```

---

## 🎯 **Quick Commands**

```bash
# Load secrets
source scripts/load-terraform-secrets.sh

# Verify secrets loaded
env | grep TF_VAR

# Preview DNS changes
terraform plan

# Apply DNS changes
terraform apply

# View current DNS state
terraform show

# Edit encrypted secrets
sops terraform_secrets.yml
```

---

## 📚 **Related Documentation**

- **DNS Migration Safety**: `docs/DNS_MIGRATION_CHECKLIST.md`
- **Terraform Quick Start**: `docs/TERRAFORM_DNS_QUICKSTART.md`
- **DNS & SSL Setup**: `docs/DNS_AND_SSL_SETUP.md`
- **Secrets Management**: `SECRETS_MANAGEMENT.md` (Ansible-focused)

---

## ✅ **Checklist for First-Time Setup**

- [ ] SOPS and AGE installed (`brew install sops age`)
- [ ] AGE key exists at `~/.config/sops/age/keys.txt`
- [ ] `SOPS_AGE_KEY_FILE` environment variable set
- [ ] Secrets can be decrypted: `sops --decrypt terraform_secrets.yml`
- [ ] Load secrets: `source scripts/load-terraform-secrets.sh`
- [ ] Initialize Terraform: `terraform init`
- [ ] Test plan: `terraform plan` (OK if vps_ipv4 error)
- [ ] VPS provisioned (when ready)
- [ ] VPS IP added to `terraform.tfvars`
- [ ] Apply: `terraform apply`

**Current Status:** Ready to test with `terraform plan` (will error on empty VPS IP until you provision VPS)
