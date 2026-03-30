# Secrets Management with SOPS and AGE

This document explains how secrets are encrypted, stored, and managed in this infrastructure repository using SOPS (Secrets OPerationS) and AGE encryption.

## Overview

We use **SOPS** (by Mozilla) with **AGE** encryption to securely store secrets in git. This allows us to:
- ✅ Commit encrypted secrets to version control
- ✅ Share secrets securely with team members
- ✅ Maintain audit trail of secret changes
- ✅ Use secrets in Ansible playbooks automatically

## How It Works

### The Tools

**SOPS (Secrets OPerationS)**
- Encrypts/decrypts YAML, JSON, and other files
- Preserves file structure (only encrypts values)
- Supports multiple encryption backends (AGE, PGP, AWS KMS, etc.)
- GitHub: https://github.com/mozilla/sops

**AGE (Actually Good Encryption)**
- Modern, simple encryption tool
- Uses small public/private key pairs
- No complex key management like PGP
- GitHub: https://github.com/FiloSottile/age

### The Workflow

```
Plain text secret → SOPS + AGE → Encrypted file → Commit to git
                                        ↓
                    Team member clones → SOPS + Their AGE key → Decrypted secret
```

## Your AGE Keys

### Location

Your AGE private key is stored at:
```
~/.config/sops/age/keys.txt
```

Environment variable (set in your shell):
```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
```

### Your Key Information

**Public Key**: `age10q0tj8gewf6rgx8plzz0lh9z8mamha6zw5qa7k2ea0d7q7kt8f5srrzmmn`
- This is in `.sops.yaml` in the repo
- Safe to share - used to encrypt files FOR you
- Like your email address or SSH public key

**Private Key**: `AGE-SECRET-KEY-15N68T5...` (starts with `AGE-SECRET-KEY-`)
- Stored in `~/.config/sops/age/keys.txt`
- **NEVER SHARE THIS** - used to decrypt files
- Like your password or SSH private key

### View Your Keys

```bash
# View your private key file
cat ~/.config/sops/age/keys.txt

# Output format:
# created: 2025-09-18T16:34:46-04:00
# public key: age10q0tj8gewf6rgx8plzz0lh9z8mamha6zw5qa7k2ea0d7q7kt8f5srrzmmn
# AGE-SECRET-KEY-15N68T5AGGFPY7CJU9WH62CSGHEYQDU6W974SA3U7ESV7XF0V7JMSJT7J3S
```

## Working with Encrypted Files

### Current Encrypted Files

All files matching this pattern are encrypted:
- `ansible/inventory/group_vars/*_secrets.yml`

Current files:
- `ansible/inventory/group_vars/sso_secrets.yml`
- `ansible/inventory/group_vars/tailscale_secrets.yml`

### Creating a New Encrypted File

```bash
# Method 1: Create from template
cp ansible/inventory/group_vars/tailscale_secrets.yml.example \
   ansible/inventory/group_vars/mysecret_secrets.yml

# Edit with SOPS (automatically encrypts on save)
sops ansible/inventory/group_vars/mysecret_secrets.yml

# Method 2: Encrypt existing file
sops --encrypt --in-place ansible/inventory/group_vars/mysecret_secrets.yml
```

### Editing Encrypted Files

```bash
# SOPS automatically decrypts, opens editor, and re-encrypts on save
sops ansible/inventory/group_vars/tailscale_secrets.yml

# Use specific editor
EDITOR=vim sops ansible/inventory/group_vars/tailscale_secrets.yml
```

### Viewing Encrypted Files

```bash
# View encrypted content (what's in git)
cat ansible/inventory/group_vars/tailscale_secrets.yml

# View decrypted content (requires your private key)
sops -d ansible/inventory/group_vars/tailscale_secrets.yml

# Extract specific value
sops -d --extract '["tailscale_auth_key"]' ansible/inventory/group_vars/tailscale_secrets.yml
```

### Committing Encrypted Files

✅ **YES - It's safe to commit encrypted secrets files**

```bash
# Add and commit as normal
git add ansible/inventory/group_vars/tailscale_secrets.yml
git commit -m "Add/update Tailscale auth key"
git push
```

The file is encrypted, so only people with the AGE private key can read it.

## SOPS Configuration

Configuration is in `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: ansible/inventory/group_vars/.*_secrets\.yml$
    encrypted_regex: '^(.*)$'
    age: 'age10q0tj8gewf6rgx8plzz0lh9z8mamha6zw5qa7k2ea0d7q7kt8f5srrzmmn'
  - path_regex: terraform_secrets\.yml$
    encrypted_regex: '^(.*)$'
    age: 'age10q0tj8gewf6rgx8plzz0lh9z8mamha6zw5qa7k2ea0d7q7kt8f5srrzmmn'
```

This tells SOPS:
- Which files to encrypt (pattern matching)
- Which AGE public keys can decrypt them
- What parts of the file to encrypt (values only, structure preserved)

## Ansible Integration

Ansible automatically decrypts SOPS files during playbook runs.

### Configuration

Set in `ansible/ansible.cfg`:

```ini
[defaults]
vars_plugins_enabled = host_group_vars,community.sops.sops
```

This requires the `community.sops` collection:

```bash
ansible-galaxy collection install community.sops
```

### How It Works

When Ansible runs:
1. Reads `*_secrets.yml` files from `group_vars/`
2. SOPS plugin automatically decrypts them
3. Variables become available in playbooks
4. No manual decryption needed!

### Example Usage

```yaml
# ansible/inventory/group_vars/tailscale_secrets.yml (encrypted)
---
tailscale_auth_key: "tskey-auth-xxxxx"

# In playbook, use like any other variable
- name: Configure Tailscale
  command: tailscale up --authkey={{ tailscale_auth_key }}
```

## Backup and Recovery

### ⚠️ CRITICAL: Back Up Your Private Key

Your AGE private key is the **ONLY** way to decrypt secrets. If you lose it, you lose access to all encrypted data.

### Backup Methods

**Option 1: Password Manager (Recommended)**
```bash
# Copy to clipboard
cat ~/.config/sops/age/keys.txt | pbcopy

# Then save in:
# - 1Password (Secure Note)
# - Bitwarden (Secure Note)
# - LastPass (Secure Note)
# - etc.
```

**Option 2: Encrypted ZIP**
```bash
# Create encrypted backup
zip -e ~/Dropbox/sops-age-key-backup.zip ~/.config/sops/age/keys.txt
# Enter a strong password when prompted
```

**Option 3: Print and Store**
```bash
# Print and store in physical safe
cat ~/.config/sops/age/keys.txt | lpr
```

### Recovery

If you lose your private key and don't have a backup:
1. Generate a new AGE key pair: `age-keygen -o ~/.config/sops/age/keys.txt`
2. Update `.sops.yaml` with new public key
3. **Manually re-enter all secrets** (no way to decrypt old files)
4. Re-encrypt all `*_secrets.yml` files

## Adding Team Members

When someone needs access to encrypted secrets:

### 1. They Generate Their Own Key

```bash
# New team member runs on their machine
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# They share ONLY their public key with you
# Example: age1abc123def456ghi789...
```

### 2. You Add Their Public Key

Edit `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: ansible/inventory/group_vars/.*_secrets\.yml$
    encrypted_regex: '^(.*)$'
    age: >-
      age10q0tj8gewf6rgx8plzz0lh9z8mamha6zw5qa7k2ea0d7q7kt8f5srrzmmn,
      age1abc123def456ghi789...
```

### 3. Re-encrypt All Secrets

```bash
# Update encryption for all recipients
sops updatekeys ansible/inventory/group_vars/sso_secrets.yml
sops updatekeys ansible/inventory/group_vars/tailscale_secrets.yml

# Or use find to update all
find ansible/inventory/group_vars -name "*_secrets.yml" -exec sops updatekeys {} \;
```

### 4. Commit and Share

```bash
git add .sops.yaml ansible/inventory/group_vars/*_secrets.yml
git commit -m "Add team member's AGE public key"
git push
```

Now the new team member can decrypt with their private key!

## Security Best Practices

### ✅ DO

- Back up your private key in multiple secure locations
- Use different keys for different environments (dev/staging/prod)
- Set `SOPS_AGE_KEY_FILE` in your shell profile (`~/.zshrc`)
- Commit encrypted secrets files to git
- Share only public keys with team members
- Rotate keys periodically (quarterly recommended)
- Use descriptive commit messages when changing secrets
- Review who has access (audit `.sops.yaml` recipients)

### ❌ DON'T

- Share your private key with anyone
- Commit unencrypted secrets files
- Store private keys in cloud storage unencrypted
- Use the same key across multiple organizations
- Email or message private keys
- Store private keys in git (even private repos)
- Assume secrets are safe without encryption

## Troubleshooting

### SOPS Can't Decrypt File

**Error**: `Failed to get the data key required to decrypt the SOPS file`

**Solution**:
```bash
# Check your AGE key file exists
ls -l ~/.config/sops/age/keys.txt

# Check environment variable is set
echo $SOPS_AGE_KEY_FILE

# Verify your public key is in .sops.yaml
grep -A5 "age:" .sops.yaml
```

### Ansible Can't Find SOPS Plugin

**Error**: `vars_plugins_enabled includes community.sops.sops`

**Solution**:
```bash
# Install the community.sops collection
ansible-galaxy collection install community.sops

# Verify installation
ansible-galaxy collection list | grep sops
```

### File Won't Encrypt

**Error**: `no key groups defined`

**Solution**:
```bash
# Check .sops.yaml syntax
cat .sops.yaml

# Manually specify key
sops --age age10q0tj8gewf6rgx8plzz0lh9z8mamha6zw5qa7k2ea0d7q7kt8f5srrzmmn \
     --encrypt --in-place file.yml
```

### Need to Rotate Keys

```bash
# 1. Generate new key
age-keygen -o ~/.config/sops/age/keys-new.txt

# 2. Add new public key to .sops.yaml (keep old one temporarily)

# 3. Update all secrets files
find ansible/inventory/group_vars -name "*_secrets.yml" -exec sops updatekeys {} \;

# 4. Replace old key file
mv ~/.config/sops/age/keys-new.txt ~/.config/sops/age/keys.txt

# 5. Remove old public key from .sops.yaml

# 6. Update all secrets files again
find ansible/inventory/group_vars -name "*_secrets.yml" -exec sops updatekeys {} \;
```

## Quick Reference

### Common Commands

```bash
# Create/edit encrypted file
sops ansible/inventory/group_vars/mysecret_secrets.yml

# View decrypted content
sops -d ansible/inventory/group_vars/mysecret_secrets.yml

# Encrypt existing file
sops --encrypt --in-place file.yml

# Update encryption keys
sops updatekeys file.yml

# Extract single value
sops -d --extract '["key_name"]' file.yml

# View your public key
grep "public key" ~/.config/sops/age/keys.txt

# Check SOPS version
sops --version

# Check AGE version
age --version
```

### File Naming Convention

All encrypted secrets files must end with `_secrets.yml`:
- ✅ `tailscale_secrets.yml`
- ✅ `sso_secrets.yml`
- ✅ `database_secrets.yml`
- ❌ `secrets.yml` (too generic)
- ❌ `tailscale.yml` (missing _secrets)

## Additional Resources

- **SOPS Documentation**: https://github.com/mozilla/sops
- **AGE Documentation**: https://age-encryption.org/
- **Ansible SOPS Plugin**: https://docs.ansible.com/ansible/latest/collections/community/sops/
- **SOPS Tutorial**: https://dev.to/stack-labs/manage-your-secrets-in-git-with-sops-common-operations-118g

## Related Documentation

- `TAILSCALE_SETUP.md` - How to set up Tailscale secrets
- `ansible/README.md` - Variable precedence and structure
- `WARP.md` - Overall infrastructure documentation
