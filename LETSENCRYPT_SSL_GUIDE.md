# Let's Encrypt SSL Certificate Management for Wilkes Liberty

This guide covers comprehensive SSL/TLS certificate management for your infrastructure using Let's Encrypt with both internal and external domains.

## 📋 Certificate Strategy

### ✅ Hybrid Certificate Approach
1. **Internal Wildcard**: `*.int.wilkesliberty.com` - For service-to-service communication
2. **External Individual**: Separate certs for public services
3. **DNS-01 Challenge**: Uses Njalla API for all certificates

### 🌟 Certificate Coverage

| Certificate | Domains | Purpose | Challenge |
|-------------|---------|---------|-----------|
| **internal_wildcard** | `*.int.wilkesliberty.com` | Internal services | DNS-01 |
| **main_domain** | `wilkesliberty.com`, `www.wilkesliberty.com` | Main website | DNS-01 |
| **api_certificate** | `api.wilkesliberty.com` | API endpoints | DNS-01 |
| **sso_certificate** | `sso.wilkesliberty.com` | Authentik SSO | DNS-01 |
| **stats_certificate** | `stats.wilkesliberty.com` | Analytics | DNS-01 |

## 🚀 Quick Start

### 1. Verify Njalla API Token in Existing Secrets

```bash
# Check your existing terraform secrets file (already contains njalla_api_token)
sops -d terraform_secrets.yml | grep njalla_api_token
```

**✅ Good news**: Your existing `terraform_secrets.yml` already contains the required `njalla_api_token`!

No additional setup needed - the Let's Encrypt playbook will use your existing secrets file.

### 2. Deploy Certificates to All Servers

```bash
# Deploy to all hosts that need certificates
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/letsencrypt.yml

# Or deploy to specific services
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/letsencrypt.yml --limit cache
```

### 3. Verify Certificate Installation

```bash
# Check certificate status
ansible -i ansible/inventory/hosts.ini fleet -m shell -a "certbot certificates"

# Check certificate expiration
ansible -i ansible/inventory/hosts.ini fleet -m shell -a "cat /var/log/letsencrypt/certificate-status.md"
```

## 📁 File Structure

```
ansible/roles/letsencrypt/
├── defaults/main.yml           # Certificate configuration
├── tasks/
│   ├── main.yml               # Main orchestration
│   ├── install_njalla_plugin.yml  # Custom Njalla DNS plugin
│   ├── generate_certificate.yml   # Individual cert generation
│   ├── create_renewal_hooks.yml   # Service restart hooks
│   └── verify_certificates.yml    # Health checking
└── templates/
    └── njalla-credentials.ini.j2   # API credentials template
```

## 🔧 Configuration

### Per-Host Certificate Selection

You can customize which certificates each host gets by overriding the `letsencrypt_certificates` variable in host_vars:

```yaml
# ansible/inventory/host_vars/app1.prod.wilkesliberty.com.yml
letsencrypt_certificates:
  - name: "internal_wildcard"
    domains: ["*.int.wilkesliberty.com"]
    challenge: "dns-01"
    services_to_restart: ["nginx"]
  - name: "main_domain" 
    domains: ["wilkesliberty.com", "www.wilkesliberty.com"]
    challenge: "dns-01"
    services_to_restart: ["nginx", "caddy"]
```

### Service-Specific Configuration

```yaml
# For cache server (cache1.prod.wilkesliberty.com)
letsencrypt_certificates:
  - name: "internal_wildcard"
    domains: ["*.int.wilkesliberty.com"]
    challenge: "dns-01"
    services_to_restart: ["nginx", "caddy", "varnish"]

# For SSO server (sso1.prod.wilkesliberty.com)  
letsencrypt_certificates:
  - name: "internal_wildcard"
    domains: ["*.int.wilkesliberty.com"]
    challenge: "dns-01"
    services_to_restart: ["nginx"]
  - name: "sso_certificate"
    domains: ["sso.wilkesliberty.com"]
    challenge: "dns-01"
    services_to_restart: ["nginx", "authentik-server"]
```

## 🔄 Certificate Usage

### Internal Service Communication

```bash
# Services can now communicate securely using internal domains:
curl https://app.int.wilkesliberty.com/api/health
curl https://db.int.wilkesliberty.com:3306  # If MySQL has SSL enabled
curl https://search.int.wilkesliberty.com:8983/solr/admin/ping
```

### External Access

```bash
# Public services with individual certificates:
curl https://wilkesliberty.com
curl https://api.wilkesliberty.com/v1/status
curl https://sso.wilkesliberty.com/application/o/authorize/
curl https://stats.wilkesliberty.com/dashboard
```

### Certificate File Locations

After deployment, certificates are available at:

```bash
# Primary locations (managed by certbot)
/etc/letsencrypt/live/wilkesliberty.com/fullchain.pem
/etc/letsencrypt/live/wilkesliberty.com/privkey.pem
/etc/letsencrypt/live/*.int.wilkesliberty.com/fullchain.pem
/etc/letsencrypt/live/*.int.wilkesliberty.com/privkey.pem

# Convenience symlinks (created by Ansible)
/etc/ssl/certs/internal_wildcard_fullchain.pem
/etc/ssl/private/internal_wildcard_privkey.pem
/etc/ssl/certs/main_domain_fullchain.pem
/etc/ssl/private/main_domain_privkey.pem
```

## 🔁 Automatic Renewal

### Renewal Schedule
- **Frequency**: Daily at 2:30 AM (randomized ±1 hour)
- **Method**: DNS-01 challenge via Njalla API
- **Actions**: Automatic service restarts via hooks

### Manual Renewal

```bash
# Renew all certificates
certbot renew

# Renew specific certificate
certbot renew --cert-name wilkesliberty.com

# Force renewal (for testing)
certbot renew --force-renewal

# Dry run (test renewal process)
certbot renew --dry-run
```

### Renewal Logs

```bash
# Check renewal logs
tail -f /var/log/letsencrypt/renewal.log

# Check certificate status
cat /var/log/letsencrypt/certificate-status.md

# Check certificate management log
tail -f /var/log/letsencrypt/certificate-management.log
```

## 🛠️ Nginx Configuration Examples

### Internal Services

```nginx
# /etc/nginx/sites-available/internal-api
server {
    listen 443 ssl http2;
    server_name app.int.wilkesliberty.com;
    
    # Use internal wildcard certificate
    ssl_certificate /etc/ssl/certs/internal_wildcard_fullchain.pem;
    ssl_certificate_key /etc/ssl/private/internal_wildcard_privkey.pem;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Public Services

```nginx
# /etc/nginx/sites-available/main-site
server {
    listen 443 ssl http2;
    server_name wilkesliberty.com www.wilkesliberty.com;
    
    # Use main domain certificate
    ssl_certificate /etc/ssl/certs/main_domain_fullchain.pem;
    ssl_certificate_key /etc/ssl/private/main_domain_privkey.pem;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # HSTS header
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
    
    location / {
        proxy_pass http://cache.int.wilkesliberty.com:6081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 🔍 Monitoring and Alerts

### Certificate Expiration Monitoring

The role automatically creates monitoring scripts:

```bash
# Check all certificate expiration dates
/usr/local/bin/check-cert-expiry.sh

# Get certificates expiring within 30 days
grep "Days until expiry:" /var/log/letsencrypt/certificate-status.md | awk '$NF < 30'
```

### Integration with Existing Monitoring

Add to your monitoring system:

```bash
# Prometheus metrics (if using node_exporter textfile collector)
echo "ssl_cert_expiry_days{domain=\"wilkesliberty.com\"} $(( ($(date -d \"$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/wilkesliberty.com/cert.pem | cut -d= -f2)\" +%s) - $(date +%s)) / 86400 ))" > /var/lib/node_exporter/textfile_collector/ssl_cert_expiry.prom
```

## 🚨 Troubleshooting

### Common Issues

#### 1. DNS-01 Challenge Failures
```bash
# Check Njalla API connectivity
curl -H "Authorization: Njalla YOUR_TOKEN" \
     --data '{"jsonrpc": "2.0", "method": "list-domains", "params": {}, "id": "1"}' \
     https://njal.la/api/1/

# Check DNS propagation
dig TXT _acme-challenge.wilkesliberty.com @8.8.8.8
```

#### 2. Certificate Generation Failures
```bash
# Check certbot logs
tail -f /var/log/letsencrypt/letsencrypt.log

# Test with staging environment
certbot certonly --staging --dns-njalla --dns-njalla-credentials /etc/letsencrypt/njalla-credentials.ini -d test.wilkesliberty.com

# Verify plugin installation
certbot plugins
```

#### 3. Service Restart Issues
```bash
# Check service status after certificate renewal
systemctl status nginx
systemctl status caddy
systemctl status authentik-server

# Manually test renewal hooks
/etc/letsencrypt/renewal-hooks/deploy/restart-web-services.sh
```

#### 4. Permission Issues
```bash
# Fix certificate permissions
chmod 644 /etc/letsencrypt/live/*/fullchain.pem
chmod 600 /etc/letsencrypt/live/*/privkey.pem
chgrp -R ssl-cert /etc/letsencrypt/live/

# Add services to ssl-cert group
usermod -a -G ssl-cert www-data
usermod -a -G ssl-cert caddy
```

### Recovery Procedures

#### Restore from Backup
```bash
# Restore certificates from backup
cp -r /var/backups/letsencrypt/latest/* /etc/letsencrypt/
systemctl reload nginx
```

#### Emergency Certificate Generation
```bash
# Generate temporary self-signed certificate
openssl req -x509 -nodes -days 7 -newkey rsa:2048 \
    -keyout /etc/ssl/private/emergency.key \
    -out /etc/ssl/certs/emergency.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=wilkesliberty.com"
```

## 📝 Playbook Integration

### Create Certificate Management Playbook

```bash
# Create the playbook file
cat > ansible/playbooks/letsencrypt.yml << 'EOF'
---
# Let's Encrypt Certificate Management Playbook

- name: Deploy Let's Encrypt certificates
  hosts: fleet
  become: yes
  vars_files:
    - ../inventory/group_vars/letsencrypt_secrets.yml
  
  roles:
    - letsencrypt

  post_tasks:
    - name: Verify web services are running with SSL
      uri:
        url: "https://{{ ansible_fqdn }}"
        method: GET
        validate_certs: no
        timeout: 10
      ignore_errors: yes
      register: ssl_check
      
    - name: Report SSL verification results
      debug:
        msg: "SSL check for {{ ansible_fqdn }}: {{ ssl_check.status | default('Failed') }}"
EOF
```

### Update Your Site Playbook

```yaml
# Add to ansible/playbooks/site.yml
- hosts: fleet
  roles:
    - common
    - letsencrypt  # Add this after common setup
    # ... other roles
```

## 📊 Certificate Management Dashboard

After deployment, view certificate status:

```bash
# Generate certificate status report
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/letsencrypt.yml --tags verify

# View certificate dashboard
cat /var/log/letsencrypt/certificate-status.md
```

## 🎯 Next Steps

1. **Deploy the role**: `ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/letsencrypt.yml`
2. **Verify certificates**: Check `/var/log/letsencrypt/certificate-status.md` on each server
3. **Configure services**: Update Nginx/Apache configurations to use the certificates
4. **Set up monitoring**: Integrate certificate expiry alerts with your monitoring system
5. **Test renewal**: Run `certbot renew --dry-run` to verify automatic renewal works

## 🔐 Security Best Practices

- **API Token Security**: Store Njalla API token in SOPS-encrypted secrets
- **File Permissions**: Certificates readable by ssl-cert group, private keys 600
- **Network Security**: Internal certificates only accessible within Tailscale mesh
- **Monitoring**: Alert on certificates expiring within 30 days
- **Backup**: Daily backup of certificate files
- **Rotation**: Regular API token rotation (quarterly recommended)

Your infrastructure now has comprehensive SSL/TLS coverage for both internal service communication and external public access!