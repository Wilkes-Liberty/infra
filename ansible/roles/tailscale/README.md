# Tailscale Role

Installs and configures Tailscale on all hosts, creating a secure mesh network.

## Requirements

- **VPS (Linux)**: Ubuntu/Debian or RHEL/CentOS — managed by this role directly via `vps.yml`
- **On-prem (macOS)**: Handled by the `wl-onprem` role (Homebrew Cask install + idempotent `tailscale up`)
- Tailscale auth key stored in SOPS-encrypted `ansible/inventory/group_vars/tailscale_secrets.yml`

## Role Variables

### Required Variables

```yaml
tailscale_auth_key: "tskey-auth-xxxxx"  # Tailscale authentication key
```

### Optional Variables

```yaml
# Tailscale up arguments (default: accepts routes but not DNS)
tailscale_up_args: "--accept-routes --accept-dns=false"

# Custom hostname for Tailscale (default: uses system hostname)
tailscale_hostname: ""

# Routes to advertise from this node (example for subnet router)
tailscale_advertise_routes: ["{{ dns_reverse_cidr }}"]

# Exit node to use (hostname or IP)
tailscale_exit_node: ""

# Enable SSH over Tailscale
tailscale_ssh: false

# Service configuration
tailscale_service_enabled: true
tailscale_service_state: started
```

## Setup Instructions

### 1. Generate Tailscale Auth Key

1. Go to https://login.tailscale.com/admin/settings/keys
2. Generate a new auth key with these recommended settings:
   - **Reusable**: Yes (so you can reuse for multiple hosts)
   - **Ephemeral**: No (unless you want nodes to auto-delete when offline)
   - **Pre-authorized**: Yes (auto-approve devices)
   - **Tags**: Add tags for ACL management (e.g., `tag:prod`, `tag:infra`)

### 2. Store Auth Key Securely

Add the auth key to your SOPS-encrypted secrets file:

```bash
# Create or edit the secrets file
sops ansible/inventory/group_vars/tailscale_secrets.yml
```

Add this content:
```yaml
---
tailscale_auth_key: "tskey-auth-xxxxxxxxxxxxxxxxxxxxx"
```

### 3. Configure .sops.yaml (if not already done)

Ensure `.sops.yaml` includes the secrets file:
```yaml
creation_rules:
  - path_regex: ansible/inventory/group_vars/.*_secrets\.yml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 4. Optional: Configure Per-Host Settings

For hosts that need to advertise routes (subnet routers):

```yaml
# ansible/inventory/host_vars/wilkesliberty-onprem.yml
tailscale_advertise_routes: ["{{ dns_reverse_cidr }}"]
tailscale_hostname: "wilkesliberty-onprem"
```

## Usage

### Deploy to All Hosts

```bash
# Deploy Tailscale role to all hosts
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml
```

### Deploy Only Tailscale

```bash
# Run only the Tailscale role
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml # (or vps.yml for VPS)
```

### Verify Installation

```bash
# Check Tailscale status on all hosts
ansible -i ansible/inventory/hosts.ini all -m shell -a "tailscale status" -b
```

## How It Works

1. **Checks Installation**: Verifies if Tailscale is already installed
2. **Adds Repository**: Adds Tailscale's official package repository
3. **Installs Package**: Installs Tailscale if not present
4. **Enables Service**: Ensures tailscaled service is running
5. **Connects to Network**: Authenticates and connects to your Tailscale network
6. **Displays Status**: Shows the current Tailscale mesh status

## Features

- **Idempotent**: Safe to run multiple times, only makes changes when needed
- **Cross-platform**: Supports Ubuntu/Debian and RHEL/CentOS
- **Configurable**: Extensive options for routes, hostnames, exit nodes, SSH
- **Secure**: Uses SOPS-encrypted auth keys
- **Status Reporting**: Shows connection status after deployment

## Network Architecture

After deployment, all hosts will be connected via Tailscale mesh:

- **Automatic peer discovery**: All nodes can communicate directly
- **NAT traversal**: Works across different networks and firewalls
- **Encrypted**: All traffic between nodes is encrypted
- **CGNAT addressing**: Uses 100.64.0.0/10 IP range
- **MagicDNS**: Optional DNS resolution for Tailscale hostnames

## Troubleshooting

### Check if Tailscale is Running
```bash
systemctl status tailscaled
```

### View Tailscale Logs
```bash
journalctl -u tailscaled -f
```

### Manually Connect
```bash
sudo tailscale up --authkey=tskey-auth-xxxxx
```

### Check Network Status
```bash
tailscale status
tailscale netcheck
```

### Force Reconnect
```bash
sudo tailscale down
sudo tailscale up --authkey=tskey-auth-xxxxx
```

## Security Considerations

- **Auth Key Storage**: Always store auth keys in SOPS-encrypted files
- **Key Rotation**: Regenerate auth keys periodically
- **ACL Tags**: Use Tailscale ACL tags to control access between hosts
- **Ephemeral Keys**: Consider ephemeral keys for temporary/test hosts
- **MFA**: Enable MFA on your Tailscale account

## Integration with Firewall

The `common` role already allows SSH access from `tailscale_network_cidr` (100.64.0.0/10). No additional firewall rules are needed for Tailscale itself.
