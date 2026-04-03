# DNS and SSL Setup Guide
## WilkesLiberty Infrastructure

**Last Updated**: March 30, 2026  
**Domain**: wilkesliberty.com

---

## 🎯 **Architecture Overview**

### **Security Model: Single Public Endpoint**

```
┌──────────────────────────────────────────────────────────┐
│ Internet (Public)                                        │
│ All DNS records point to cloud VPS                      │
└────────────────────┬─────────────────────────────────────┘
                     │
         ┌───────────▼────────────┐
         │   Cloud VPS            │  ← ONLY public server
         │   Caddy Reverse Proxy  │
         │   • Ports 80, 443 open │
         │   • Auto SSL (Let's    │
         │     Encrypt)           │
         ├────────────────────────┤
         │ www → localhost:3000   │  (Next.js local)
         │ api → Tailscale:8080   │  (Drupal on on-prem server)
         │ auth → Tailscale:8081  │  (Keycloak on on-prem server)
         └────────────────────────┘
                     │
                     │ Tailscale VPN (100.x.x.x)
                     │ Encrypted Tunnel
                     ▼
         ┌────────────────────────┐
         │   on-prem server      │  ← Private, no public ports
         │   ALL Backend Services │
         │   • Drupal :8080       │
         │   • Keycloak :8081     │
         │   • PostgreSQL :5432   │
         │   • Redis :6379        │
         │   • Solr :8983         │
         │   • Prometheus :9090   │
         │   • Grafana :3001      │
         └────────────────────────┘
              (Private Network)
```

**Key Security Points:**
- ✅ **on-prem server has ZERO public ports** — completely private
- ✅ **Only Tailscale can reach on-prem server** — no direct internet access
- ✅ **Njalla VPS is the only public server** — minimal attack surface
- ✅ **Wildcard TLS cert** — certbot DNS-01 challenge for `*.wilkesliberty.com`; Caddy uses `auto_https off` and reads the certbot-managed cert directly
- ✅ **TLS 1.2+ enforced** — TLS 1.0/1.1 rejected in Caddy global block
- ✅ **Security headers** — HSTS, CSP, X-Frame-Options, Referrer-Policy, Permissions-Policy on all vhosts

---

## 📋 **Step 1: DNS Configuration with Terraform**

### **Automated DNS Management** ✨

**Your DNS is managed via Terraform!** No manual DNS entry required.

#### **1.1: Configure Terraform Variables**

```bash
cd /Users/jcerda/Repositories/infra

# Copy example to create your config
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vi terraform.tfvars
```

**Required variables in `terraform.tfvars`:**

```hcl
# Njalla API token (get from Njalla account settings)
njalla_api_token = "your-njalla-api-token-here"

# VPS IP addresses (fill in after provisioning VPS)
vps_ipv4 = "1.2.3.4"           # Your VPS IPv4
vps_ipv6 = "2001:db8::1"        # Optional: Your VPS IPv6

# Proton Mail (if using Proton)
proton_verification_token = "..."
proton_dkim1_target       = "..."
proton_dkim2_target       = "..."
proton_dkim3_target       = "..."
```

#### **1.2: Deploy DNS Records**

```bash
# Initialize Terraform (first time only)
terraform init

# Preview DNS changes
terraform plan

# Apply DNS records to Njalla
terraform apply
```

**Terraform will create:**

| Record | Type | Name | Target | Purpose |
|--------|------|------|--------|---------|
| ✅ | A / AAAA | `@` | `vps_ipv4` / `vps_ipv6` | Root domain |
| ✅ | A / AAAA | `www` | VPS IP | Next.js frontend |
| ✅ | A / AAAA | `api` | VPS IP | Drupal CMS / GraphQL (webcms repo) |
| ✅ | A / AAAA | `auth` | VPS IP | Keycloak SSO |
| ✅ | A / AAAA | `search` | VPS IP | Solr search (admin-CIDR restricted) |
| ✅ | CNAME | `network` | `login.tailscale.com.` | VPN/network admin console |
| 📝 | A / AAAA | `analytics` | VPS IP | Grafana (commented out — use internal URL instead) |

**AAAA records** are conditional: only created when `vps_ipv6` variable is non-empty.

> **CAA records are NOT managed by Terraform** — the Njalla provider (v0.10.0) doesn't support CAA. Add them manually in the Njalla web UI. See `DNS_RECORDS.md` for the exact values and verification command.

### **Services NOT in Public DNS** (Internal / Tailscale-only)

These services use `*.int.wilkesliberty.com` (CoreDNS, Tailscale Split DNS):

- **Grafana** — `https://monitor.int.wilkesliberty.com`
- **Prometheus** — `https://metrics.int.wilkesliberty.com`
- **Alertmanager** — `https://alerts.int.wilkesliberty.com`
- **PostgreSQL, Redis** — never externally accessible
- **Internal Drupal / Keycloak admin** — `https://app.int.wilkesliberty.com`, `https://sso.int.wilkesliberty.com`

---

## 🔐 **Step 2: SSL Certificate Strategy**

### **Wildcard Certificate via certbot (DNS-01 challenge)**

Caddy is configured with `auto_https off` and uses a wildcard certificate obtained manually via certbot. This covers all subdomains with a single cert.

**Obtain the certificate** (run on Njalla VPS):

```bash
certbot certonly \
  --manual \
  --preferred-challenges dns \
  -d "wilkesliberty.com" \
  -d "*.wilkesliberty.com"
```

certbot will prompt you to add a `_acme-challenge` TXT record in Njalla. Add it via the web UI, wait ~60 seconds, then press Enter.

**Certificate location**: `/etc/letsencrypt/live/wilkesliberty.com/`

**Renewal**: Run `certbot renew` and reload Caddy. Set up a cron job or systemd timer for automatic renewal. See `LETSENCRYPT_SSL_GUIDE.md` for full renewal instructions.

**Verify certificate**:
```bash
openssl x509 -in /etc/letsencrypt/live/wilkesliberty.com/fullchain.pem -noout -dates
```

---

## 🚀 **Step 3: Njalla VPS Setup**

### **3.1: Provision Njalla VPS**

**Minimum Specs:**
- **CPU**: 1 vCPU
- **RAM**: 1GB
- **Disk**: 20GB
- **Bandwidth**: Unlimited (or 1TB+)
- **OS**: Ubuntu 24.04 LTS

**Estimated Cost**: ~$5-15/month

### **3.2: Initial Server Setup**

```bash
# SSH into your Njalla VPS
ssh root@<njalla-vps-ip>

# Update system
apt update && apt upgrade -y

# Install required packages
apt install -y curl git ufw fail2ban

# Set timezone
timedatectl set-timezone America/New_York  # or your timezone

# Set hostname
hostnamectl set-hostname njalla-vps
```

### **3.3: Install Tailscale on VPS**

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Connect to your Tailnet
tailscale up

# Get Tailscale IP
tailscale ip -4

# Note this IP - you'll use it in Caddyfile
```

### **3.4: Install Caddy**

```bash
# Install Caddy
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list

apt update
apt install -y caddy

# Verify installation
caddy version

# Enable Caddy service
systemctl enable caddy
systemctl start caddy
```

### **3.5: Configure Firewall**

```bash
# Reset UFW
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (IMPORTANT: Do this first!)
ufw allow 22/tcp comment 'SSH'

# Allow HTTP/HTTPS
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Allow Tailscale
ufw allow in on tailscale0

# Enable firewall
ufw enable

# Verify
ufw status verbose
```

### **3.6: Deploy Caddyfile**

```bash
# Create Caddyfile (use the template from Step 4)
nano /etc/caddy/Caddyfile

# Test configuration
caddy validate --config /etc/caddy/Caddyfile

# Reload Caddy
systemctl reload caddy

# Check logs
journalctl -u caddy -f
```

---

## 📝 **Step 4: Update Caddyfile with Your Details**

**File**: `/etc/caddy/Caddyfile` on Njalla VPS

Replace these placeholders:

```bash
# Get on-prem server Tailscale IP
# Run this ON ON-PREM SERVER:
tailscale ip -4

# Example output: {{ coredns_ts_ip }}
```

**Update Caddyfile:**
```caddyfile
# Replace this:
reverse_proxy {{ onprem_tailscale_ip }}:8080

# With your actual IP:
reverse_proxy {{ coredns_ts_ip }}:8080
```

**Update email:**
```caddyfile
{
    email admin@wilkesliberty.com  # ← Your email for Let's Encrypt
}
```

---

## 🔍 **Step 5: Deploy Next.js Frontend to Njalla VPS**

### **5.1: Clone ui Repository**

```bash
# On Njalla VPS
cd /opt
git clone https://github.com/your-org/ui.git wilkesliberty-frontend
cd wilkesliberty-frontend

# Install dependencies
npm install

# Configure environment
cp .env.example .env.production
nano .env.production
```

### **5.2: Configure Next.js Environment**

**File**: `/opt/wilkesliberty-frontend/.env.production`

```bash
# Drupal Backend Configuration
NEXT_PUBLIC_DRUPAL_BASE_URL=https://api.wilkesliberty.com
NEXT_IMAGE_DOMAIN=api.wilkesliberty.com

# OAuth2 (from Drupal admin)
DRUPAL_CLIENT_ID=your-client-id
DRUPAL_CLIENT_SECRET=your-client-secret

# Preview/Draft Mode
DRUPAL_PREVIEW_SECRET=your-preview-secret

# Production Settings
NODE_ENV=production
```

### **5.3: Build and Deploy**

```bash
# Build for production
npm run build

# Test production build
npm run start

# Install PM2 for process management
npm install -g pm2

# Start with PM2
pm2 start npm --name "nextjs" -- start

# Save PM2 config
pm2 save

# Set PM2 to start on boot
pm2 startup
# Follow the command it outputs

# Check status
pm2 status
pm2 logs nextjs
```

---

## ✅ **Step 6: Verification & Testing**

### **6.1: DNS Propagation Check**

```bash
# Check DNS resolution (run from your local machine)
dig www.wilkesliberty.com +short
dig api.wilkesliberty.com +short
dig auth.wilkesliberty.com +short

# All should return your Njalla VPS IP
```

**Online tools:**
- https://dnschecker.org/
- https://www.whatsmydns.net/

**Note**: DNS propagation can take 5 minutes to 48 hours.

### **6.2: SSL Certificate Verification**

```bash
# Check certificate (run after DNS propagates)
curl -I https://www.wilkesliberty.com
curl -I https://api.wilkesliberty.com
curl -I https://auth.wilkesliberty.com

# Should return:
# HTTP/2 200
# server: Caddy
# (certificate valid)

# Detailed SSL check
openssl s_client -connect www.wilkesliberty.com:443 -servername www.wilkesliberty.com | grep -A 2 "Verify return code"

# Should show: Verify return code: 0 (ok)
```

**Online SSL testers:**
- https://www.ssllabs.com/ssltest/
- https://www.digicert.com/help/

**Expected SSL Labs Score**: A+

### **6.3: Service Connectivity Tests**

```bash
# Test frontend
curl -I https://www.wilkesliberty.com
# Should return 200 OK (Next.js homepage)

# Test Drupal API
curl https://api.wilkesliberty.com/user/login
# Should return Drupal login page HTML

# Test Keycloak
curl https://auth.wilkesliberty.com/health/ready
# Should return health status JSON

# Test from browser
open https://www.wilkesliberty.com
open https://api.wilkesliberty.com
open https://auth.wilkesliberty.com
```

### **6.4: HTTPS Enforcement Check**

```bash
# Test HTTP → HTTPS redirect
curl -I http://www.wilkesliberty.com
# Should return 301/302 redirect to https://

curl -I http://api.wilkesliberty.com
# Should return 301/302 redirect to https://
```

### **6.5: Security Headers Check**

```bash
# Check security headers
curl -I https://www.wilkesliberty.com | grep -i "strict-transport-security"
# Should show: Strict-Transport-Security: max-age=31536000; includeSubDomains; preload

curl -I https://www.wilkesliberty.com | grep -i "x-frame-options"
# Should show: X-Frame-Options: SAMEORIGIN
```

---

## 🔒 **Security Best Practices**

### **on-prem server Firewall** (On-Prem)

```bash
# On on-prem server - verify NO public ports are open
# Your firewall should ONLY allow:
# - Tailscale (100.64.0.0/10)
# - Local network if needed

# macOS Firewall settings:
# System Settings → Network → Firewall → Options
# Enable Firewall
# Block all incoming connections except:
#   - Tailscale
```

### **Njalla VPS Firewall**

```bash
# Verify firewall rules
ufw status numbered

# Should only show:
# [1] 22/tcp    ALLOW IN    Anywhere  # SSH
# [2] 80/tcp    ALLOW IN    Anywhere  # HTTP
# [3] 443/tcp   ALLOW IN    Anywhere  # HTTPS
# [4] Anywhere on tailscale0 ALLOW IN Anywhere  # Tailscale
```

### **Fail2ban Configuration**

```bash
# Install fail2ban (already installed in Step 3.2)
# Configure for SSH protection

nano /etc/fail2ban/jail.local
```

**Add:**
```ini
[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
```

```bash
# Restart fail2ban
systemctl restart fail2ban

# Check status
fail2ban-client status sshd
```

---

## 📊 **Monitoring SSL Certificates**

### **Certificate Expiration Monitoring**

Caddy auto-renews, but you should monitor:

```bash
# On Njalla VPS - check certificate expiration
echo | openssl s_client -servername www.wilkesliberty.com -connect localhost:443 2>/dev/null | openssl x509 -noout -dates

# Output shows:
# notBefore=Mar 30 00:00:00 2026 GMT
# notAfter=Jun 28 23:59:59 2026 GMT
```

**Prometheus Alert** (already in your alerts.yml):
```yaml
- alert: CertificateExpiringSoon
  expr: (ssl_certificate_expiry_seconds - time()) / 86400 < 30
  labels:
    severity: info
  annotations:
    summary: "SSL certificate expiring soon"
    description: "Certificate expires in {{ $value }} days"
```

### **Caddy Logs**

```bash
# Watch Caddy logs
journalctl -u caddy -f

# Check for SSL renewal
journalctl -u caddy | grep -i "renew\|certificate"

# Caddy access logs
tail -f /var/log/caddy/www.log
tail -f /var/log/caddy/api.log
```

---

## 🛠️ **Troubleshooting**

### **Issue: DNS not resolving**

```bash
# Check DNS records
dig www.wilkesliberty.com +short

# If empty, DNS not propagated yet (wait 5-60 minutes)
# If shows old IP, clear local DNS cache:
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder  # macOS
```

### **Issue: SSL certificate not issued**

```bash
# Check Caddy logs
journalctl -u caddy -n 50

# Common issues:
# 1. Port 80 not open (Let's Encrypt needs it for validation)
#    Fix: ufw allow 80/tcp
# 2. DNS not pointed to VPS
#    Fix: Wait for DNS propagation
# 3. Rate limit hit (5 certs/week for same domain)
#    Fix: Use Let's Encrypt staging (in Caddyfile global block)
```

### **Issue: Cannot reach backend services**

```bash
# On Njalla VPS - test Tailscale connectivity
tailscale ping <onprem-tailscale-ip>

# Test backend service directly
curl http://<onprem-tailscale-ip>:8080

# If fails:
# 1. Verify Tailscale is running on on-prem server
# 2. Verify on-prem server services are running (docker compose ps)
# 3. Check on-prem server firewall allows Tailscale
```

### **Issue: 502 Bad Gateway**

```bash
# Service is down or unreachable
# On on-prem server:
cd /Users/jcerda/Repositories/infra/docker
docker compose ps

# Restart service if unhealthy
docker compose restart drupal

# Check logs
docker compose logs drupal
```

---

## 📈 **Optional: Expose Grafana Publicly**

If you want to access Grafana from anywhere (with authentication):

### **1. Add DNS Record at Njalla**

```
grafana     A       <njalla-vps-ip>     300
```

### **2. Uncomment Grafana Section in Caddyfile**

**File**: `/etc/caddy/Caddyfile`

Uncomment lines 146-173 (grafana.wilkesliberty.com section)

### **3. Generate Password Hash**

```bash
# On Njalla VPS
caddy hash-password

# Enter your desired password
# Copy the hash (starts with $2a$14$...)
```

### **4. Update Caddyfile**

```caddyfile
grafana.wilkesliberty.com {
    basicauth {
        admin $2a$14$your_generated_hash_here
    }
    # ... rest of config
}
```

### **5. Reload Caddy**

```bash
systemctl reload caddy
```

Now access Grafana at: `https://grafana.wilkesliberty.com`

---

## 📋 **Summary Checklist**

- [ ] DNS records created via Terraform (www, api, auth, search, network CNAME, apex)
- [ ] CAA records added manually in Njalla web UI (3 records)
- [ ] Njalla VPS provisioned (Ubuntu 24.04, 1+ GB RAM)
- [ ] Tailscale installed and connected on VPS and on-prem server
- [ ] Subnet route `{{ dns_reverse_cidr }}` approved in Tailscale admin
- [ ] Tailscale Split DNS configured for `int.wilkesliberty.com`
- [ ] Caddy installed on VPS
- [ ] Firewall configured (ports 22, 80, 443 only + Tailscale interface)
- [ ] Wildcard cert obtained via certbot (`*.wilkesliberty.com`)
- [ ] Caddyfile deployed (from `Caddyfile.production.j2` via Ansible)
- [ ] Next.js frontend deployed on VPS (built from `ui` repo)
- [ ] DNS propagated — `dig www.wilkesliberty.com` returns VPS IP
- [ ] HTTPS working for all subdomains
- [ ] TLS 1.1 rejected (TLS 1.2+ enforced)
- [ ] Security headers present on all vhosts
- [ ] Internal `*.int.wilkesliberty.com` resolves only on Tailscale
- [ ] `dig CAA wilkesliberty.com` returns 3 records

---

## Related Documentation

- `DNS_RECORDS.md` — Full DNS record reference
- `TAILSCALE_SETUP.md` — Tailscale mesh and Split DNS
- `LETSENCRYPT_SSL_GUIDE.md` — Certificate renewal procedures
- `docs/TERRAFORM_DNS_QUICKSTART.md` — Terraform quick reference
- `DEPLOYMENT_CHECKLIST.md` — Full deployment guide
