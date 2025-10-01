# Ansible Configuration Structure

This document explains the Ansible directory structure and variable precedence for the Wilkes Liberty infrastructure.

## Directory Structure

```
ansible/
├── group_vars/              # Global group variables (adjacent to inventory)
│   └── all/                 # Variables for all hosts
│       └── coredns.yml      # CoreDNS-specific configuration
├── inventory/               # Inventory and inventory-specific variables
│   ├── group_vars/          # Inventory-specific group variables
│   │   ├── all.yml          # Main infrastructure variables
│   │   └── sso_secrets.yml  # Encrypted SSO secrets (SOPS)
│   ├── host_vars/           # Host-specific variables
│   │   ├── app1.prod.wilkesliberty.com.yml
│   │   ├── cache1.prod.wilkesliberty.com.yml
│   │   └── [...other host vars...]
│   └── hosts.ini            # Main inventory file
├── playbooks/               # Ansible playbooks
├── roles/                   # Ansible roles
└── templates/               # Global templates (if any)
```

## Variable Precedence (Lowest to Highest)

According to Ansible's variable precedence order, variables are loaded in this order (later takes precedence):

1. **`group_vars/all.yml`** (global, applies to all inventories)
2. **`inventory/group_vars/all.yml`** (inventory-specific, higher precedence)
3. **`group_vars/[group_name].yml`** (group-specific variables)
4. **`inventory/group_vars/[group_name].yml`** (inventory-specific group variables)
5. **`host_vars/[hostname].yml`** (host-specific variables, highest precedence)

## Current Configuration Strategy

### Primary Variables (`inventory/group_vars/all.yml`)
This file contains the **authoritative infrastructure configuration** including:
- Domain configuration
- Network and access control settings
- Service IP addresses  
- Software versions
- WireGuard mesh configuration

### CoreDNS Variables (`group_vars/all/coredns.yml`)
Specialized variables for DNS configuration:
- Internal domain settings
- DNS server configuration
- Host to IP mappings for DNS zones
- Upstream DNS servers

### Encrypted Secrets (`inventory/group_vars/sso_secrets.yml`)
SOPS-encrypted variables for sensitive data:
- SSO configuration secrets
- API keys and tokens
- Certificates and private keys

### Host-Specific Variables (`inventory/host_vars/`)
Individual host configurations:
- WireGuard peer configurations
- Host-specific service settings
- Per-host overrides

## Best Practices

### Variable Organization
1. **Use `inventory/group_vars/all.yml`** for main infrastructure variables
2. **Use `group_vars/all/`** subdirectory for component-specific variables (like CoreDNS)
3. **Use encrypted files** (`*_secrets.yml`) for sensitive data with SOPS
4. **Use host_vars** for host-specific overrides only

### Naming Conventions
- Use descriptive variable names with service prefixes: `cache_int_ip`, `app_int_ip`
- Group related variables with consistent prefixes: `wg_*` for WireGuard
- Use `_int_ip` suffix for internal IP addresses
- Use `_secrets.yml` suffix for SOPS-encrypted files

### Security Considerations
- **Never commit plaintext secrets** to version control
- **Use SOPS encryption** for all sensitive variables
- **Restrict admin access** via `admin_allow_cidrs` variable
- **Validate variables** in playbooks before use

## Common Variables Reference

### Network Configuration
```yaml
wg_network_cidr: "10.10.0.0/24"    # WireGuard mesh subnet
admin_allow_cidrs:                 # Admin access CIDRs
  - 203.0.113.0/24
```

### Service IP Addresses
```yaml
dns_int_ip: 10.10.0.10           # CoreDNS server
app_int_ip: 10.10.0.2            # Application server
db_int_ip: 10.10.0.3             # Database server
search_int_ip: 10.10.0.4         # Solr search server
analytics_int_ip: 10.10.0.7     # Analytics/monitoring
sso_int_ip: 10.10.0.8            # SSO/Authentik server
cache_int_ip: 10.10.0.9          # Cache server (Varnish+Caddy)
```

### Domain Configuration
```yaml
domain: wilkesliberty.com              # Primary domain
int_domain: int.wilkesliberty.com      # Internal domain
```

## Troubleshooting

### Variable Conflicts
If you encounter variable conflicts:
1. Check variable precedence order above
2. Use `ansible-inventory --list` to see final variable values
3. Use `ansible-inventory --host [hostname]` for host-specific values

### Missing Variables
If playbooks fail with undefined variables:
1. Check if variable exists in appropriate group_vars file
2. Verify SOPS decryption is working for encrypted files
3. Confirm host is in correct inventory groups

### SOPS Issues
If encrypted variables can't be loaded:
1. Ensure `SOPS_AGE_KEY_FILE` environment variable is set
2. Verify your AGE private key is accessible
3. Check that `community.sops` collection is installed

## Variable Loading Commands

```bash
# View all variables for a host
ansible-inventory -i inventory/hosts.ini --host app1.prod.wilkesliberty.com

# View all groups and hosts
ansible-inventory -i inventory/hosts.ini --graph

# Test variable resolution
ansible -i inventory/hosts.ini app1.prod.wilkesliberty.com -m debug -a "var=app_int_ip"

# Edit encrypted secrets
sops inventory/group_vars/sso_secrets.yml
```