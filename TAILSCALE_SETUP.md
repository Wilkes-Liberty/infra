# Tailscale Setup Guide

Quick start guide for deploying Tailscale mesh VPN across all infrastructure hosts.

## Overview

The Tailscale role automatically installs and configures Tailscale on all hosts, creating a secure mesh network that replaces the previous WireGuard implementation.

## Prerequisites

1. **Tailscale Account**: Create a free account at https://tailscale.com
2. **SOPS/age**: Ensure you have your AGE key configured (`SOPS_AGE_KEY_FILE` environment variable)
3. **SSH Access**: SSH access to all target hosts

## Setup Steps

### 1. Generate Tailscale Auth Key

1. Log into Tailscale: https://login.tailscale.com/admin/settings/keys
2. Click **Generate auth key**
3. Configure the key settings:
   - ✅ **Reusable** - Enable (so you can use for multiple hosts)
   - ✅ **Preauthorized** - Enable (auto-approve new devices)
   - ❌ **Ephemeral** - Disable (keep nodes permanently)
   - **Expiration** - Set to 90 days or longer
   - **Tags** - Add `tag:prod` and `tag:infra` for ACL management
4. Copy the generated key (starts with `tskey-auth-`)

### 2. Store Auth Key Securely

Create the encrypted secrets file:

```bash
# Navigate to the repo
cd /Users/jcerda/Repositories/infra

# Create secrets file from template
cp ansible/inventory/group_vars/tailscale_secrets.yml.example \
   ansible/inventory/group_vars/tailscale_secrets.yml

# Edit with SOPS (will automatically encrypt)
sops ansible/inventory/group_vars/tailscale_secrets.yml
```

Replace the placeholder with your actual auth key:
```yaml
---
tailscale_auth_key: "tskey-auth-YOUR_ACTUAL_KEY_HERE"
```

Save and exit. The file will be automatically encrypted by SOPS.

### 3. Verify Configuration

Check that the encrypted file was created:

```bash
# Should show encrypted content (not plaintext)
cat ansible/inventory/group_vars/tailscale_secrets.yml

# Should show decrypted content (requires AGE key)
sops -d ansible/inventory/group_vars/tailscale_secrets.yml
```

### 4. Deploy Tailscale to All Hosts

Run the full site playbook (includes Tailscale role):

```bash
# Full deployment (recommended)
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/site.yml

# Or deploy only Tailscale role
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/site.yml --tags tailscale

# Or deploy to specific hosts
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/site.yml --limit app1.prod.wilkesliberty.com
```

### 5. Verify Tailscale Status

Check that all hosts connected successfully:

```bash
# Check Tailscale status on all hosts
ansible -i ansible/inventory/hosts.ini all -m shell -a "tailscale status" -b

# Check specific host
ansible -i ansible/inventory/hosts.ini app1.prod.wilkesliberty.com -m shell -a "tailscale status" -b
```

## Network Architecture

### IP Address Ranges

- **Tailscale CGNAT**: `100.64.0.0/10` - Automatically assigned by Tailscale
- **Internal Network**: `10.10.0.0/24` - Fixed IPs for CoreDNS resolution
- **Admin Access**: Defined in `admin_allow_cidrs`

### Communication Paths

```
Public Internet
    ↓
Tailscale Mesh (100.64.x.x) ← Encrypted overlay network
    ↓
Internal Network (10.10.0.x) ← CoreDNS resolution
    ↓
Services (app, db, solr, etc.)
```

### Firewall Integration

The firewall rules (in `common` role) already allow SSH from `tailscale_network_cidr`:

```yaml
# From ansible/roles/common/tasks/firewall.yml
- name: Allow SSH from Tailscale mesh
  ufw:
    rule: allow
    port: '22'
    proto: tcp
    src: "{{ tailscale_network_cidr }}"  # 100.64.0.0/10
```

## Advanced Configuration

### Advertise Routes (Subnet Router)

To make a host advertise the internal subnet to other Tailscale clients:

```yaml
# ansible/inventory/host_vars/app1.prod.wilkesliberty.com.yml
tailscale_advertise_routes: ["10.10.0.0/24"]
```

Then enable subnet routing in Tailscale admin console.

### Custom Hostnames

Override the default hostname:

```yaml
# ansible/inventory/host_vars/app1.prod.wilkesliberty.com.yml
tailscale_hostname: "app1-prod-wilkes"
```

### Enable Tailscale SSH

Use Tailscale's built-in SSH instead of traditional SSH:

```yaml
# ansible/inventory/group_vars/all.yml
tailscale_ssh: true
```

### Disable DNS

The role defaults to `--accept-dns=false` to avoid conflicts with CoreDNS. To change:

```yaml
# ansible/inventory/group_vars/all.yml
tailscale_up_args: "--accept-routes --accept-dns=true"
```

## Troubleshooting

### Check Service Status

```bash
# On each host
systemctl status tailscaled
journalctl -u tailscaled -f
```

### Manually Reconnect

If a host becomes disconnected:

```bash
# SSH to the host
ssh user@host

# Check status
sudo tailscale status

# Reconnect
sudo tailscale down
sudo tailscale up --authkey=tskey-auth-YOUR_KEY
```

### View Network Check

```bash
sudo tailscale netcheck
```

### Check Firewall

```bash
# Verify UFW allows Tailscale traffic
sudo ufw status numbered

# Should show rules allowing 100.64.0.0/10 for SSH
```

### Verify Connectivity

```bash
# From your local machine (if connected to Tailscale)
ping 100.64.x.x  # Tailscale IP of a host

# From one host to another
ping app1.prod.wilkesliberty.com  # Via internal DNS
```

## Security Best Practices

### Auth Key Management

1. **Use Reusable Keys**: For infrastructure, reusable keys are more practical
2. **Set Expiration**: Regularly rotate auth keys (e.g., quarterly)
3. **Tag Devices**: Use tags like `tag:prod`, `tag:infra` for ACL control
4. **Preauthorize**: Enable preauth to avoid manual approval for each host

### Access Control Lists (ACLs)

Configure Tailscale ACLs to restrict access between hosts:

```json
{
  "acls": [
    // Allow prod infrastructure to communicate
    {
      "action": "accept",
      "src": ["tag:prod"],
      "dst": ["tag:prod:*"]
    },
    // Allow admin access from specific users
    {
      "action": "accept", 
      "src": ["user@example.com"],
      "dst": ["tag:prod:*"]
    }
  ],
  "tagOwners": {
    "tag:prod": ["user@example.com"],
    "tag:infra": ["user@example.com"]
  }
}
```

### Key Rotation

Rotate auth keys regularly:

1. Generate new auth key in Tailscale admin
2. Update `tailscale_secrets.yml`: `sops ansible/inventory/group_vars/tailscale_secrets.yml`
3. Redeploy: `ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/site.yml --tags tailscale`
4. Revoke old key in Tailscale admin

### MFA

Enable multi-factor authentication on your Tailscale account.

## Comparison: WireGuard vs Tailscale

| Feature | WireGuard (Old) | Tailscale (New) |
|---------|-----------------|-----------------|
| Topology | Hub-and-spoke | Full mesh |
| Configuration | Manual per host | Automatic |
| NAT Traversal | Manual/Limited | Automatic |
| Peer Discovery | Static config | Dynamic |
| Firewall Rules | UDP port 51820 | None needed |
| IP Assignment | Manual (10.10.0.x) | Automatic (100.64.x.x) |
| Key Management | Per-host keys | Single auth key |
| Setup Complexity | High | Low |

## Next Steps

1. ✅ Deploy Tailscale to all hosts
2. ✅ Verify connectivity between hosts
3. Configure Tailscale ACLs for access control
4. Set up MagicDNS (optional)
5. Configure exit nodes (optional)
6. Set up monitoring alerts for disconnected nodes

## Additional Resources

- **Tailscale Documentation**: https://tailscale.com/kb/
- **Role Documentation**: `ansible/roles/tailscale/README.md`
- **ACL Documentation**: https://tailscale.com/kb/1018/acls/
- **Subnet Routing**: https://tailscale.com/kb/1019/subnets/
- **SSH over Tailscale**: https://tailscale.com/kb/1193/tailscale-ssh/
