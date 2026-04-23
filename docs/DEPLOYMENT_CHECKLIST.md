# WilkesLiberty Infrastructure — Complete Deployment Checklist

**Version**: 2.1
**Last Updated**: April 2026
**Estimated Time**: 3–4 hours for initial setup

> **Variable notation**: Values shown as `{{ variable_name }}` are stored in SOPS-encrypted secrets files. Decrypt with `sops -d ansible/inventory/group_vars/network_secrets.yml` to see actual values. Never commit plaintext IPs or credentials.

---

## Architecture Summary

```
Internet → Cloud VPS (Caddy, Next.js) ←── Tailscale ──→ On-prem server (Docker Compose)
Internal devices (Tailscale) → *.int.wilkesliberty.com (CoreDNS on on-prem)
```

The **on-prem server** runs all backend services. The **cloud VPS** is the single public ingress — it serves Next.js directly and proxies everything else (Drupal, Keycloak, Solr) over the Tailscale mesh to the on-prem server. Internal monitoring and admin services are accessible only over Tailscale via `*.int.wilkesliberty.com`.

---

## PRE-DEPLOYMENT CHECKLIST

### Prerequisites (Verify Before Starting)

- [ ] On-prem server is operational (macOS, adequate RAM/disk)
- [ ] Docker Desktop installed and running
- [ ] Homebrew installed
- [ ] Git repository cloned to `~/Repositories/infra`
- [ ] **Sibling repositories** cloned:
  - `~/Repositories/webcms` — Drupal CMS source (Docker build context)
  - `~/Repositories/ui` — Next.js frontend source (Docker build context)
- [ ] SOPS and AGE installed (`brew install sops age`)
- [ ] AGE private key present at `~/.config/sops/age/keys.txt`
- [ ] `SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt` set in shell profile
- [ ] Tailscale account created
- [ ] Cloud VPS provisioned with static IPv4 (and optionally IPv6)
- [ ] Terraform CLI installed
- [ ] Ansible CLI installed with required collections:
  ```bash
  ansible-galaxy collection install community.sops community.general
  ```

---

## PHASE 1: SECRETS & CONFIGURATION

### Step 1.1: Decrypt and Review Encrypted Secrets

```bash
cd ~/Repositories/infra

# Verify your AGE key can decrypt
sops -d ansible/inventory/group_vars/sso_secrets.yml
sops -d ansible/inventory/group_vars/tailscale_secrets.yml
sops -d terraform_secrets.yml
```

**All three should decrypt without errors.** If not, see `SECRETS_MANAGEMENT.md`.

### Step 1.2: Configure Docker Environment

```bash
cd ~/Repositories/infra/docker

# Copy the environment template
cp .env.example .env

# Restrict permissions immediately
chmod 600 .env

# Edit with actual secrets
nano .env
```

**Required values to set in `.env`** (generate passwords with `openssl rand -base64 32`):

```bash
# Database
DRUPAL_DB_PASSWORD=<strong_password>
KEYCLOAK_DB_PASSWORD=<strong_password>

# Redis (required — Drupal and Redis both use this)
REDIS_PASSWORD=<strong_password>

# Application credentials
KEYCLOAK_ADMIN_PASSWORD=<strong_password>
GRAFANA_ADMIN_PASSWORD=<strong_password>

# Backup
BACKUP_ENCRYPTION_KEY=<strong_key>       # REQUIRED — backups are encrypted
BACKUP_NOTIFICATION_EMAIL=admin@wilkesliberty.com

# Alert routing (optional)
ALERT_EMAIL_FROM=alerts@wilkesliberty.com
ALERT_EMAIL_TO=admin@wilkesliberty.com
ALERT_SMTP_HOST=smtp.example.com
ALERT_SMTP_PORT=587
ALERT_SMTP_USER=<smtp_user>
ALERT_SMTP_PASSWORD=<smtp_password>
```

### Step 1.3: Create Docker Data Directories

```bash
mkdir -p ~/nas_docker/{drupal,postgres,redis,keycloak,solr}
mkdir -p ~/nas_docker/prometheus/data
mkdir -p ~/nas_docker/grafana/{provisioning/datasources,provisioning/dashboards,dashboards}
mkdir -p ~/nas_docker/alertmanager
mkdir -p ~/Backups/wilkesliberty/{daily,weekly,monthly,encrypted,logs}
```

### Step 1.4: Configure Grafana Datasource

```bash
cat > ~/nas_docker/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
    jsonData:
      timeInterval: 15s
EOF
```

---

## PHASE 2: TAILSCALE VPN MESH

> **Steps 2.1 and 2.2 are fully automated by Ansible.** `make onprem` handles the on-prem server; `make vps` handles the VPS. The manual steps below are included for reference and recovery.

### Step 2.1: Install and Connect Tailscale (On-prem server)

**Automated by `make onprem`** — installs via Homebrew Cask, authenticates with SOPS-decrypted auth key, advertises `{{ dns_reverse_cidr }}`, configures Split DNS. Idempotent.

> ⚠ **First install only (manual step):** Approve the Tailscale network extension at **System Settings → Privacy & Security → Network Extensions → Allow Tailscale**.

Manual equivalent:
```bash
brew install --cask tailscale

sudo tailscale up \
  --authkey=<from tailscale_secrets.yml> \
  --advertise-routes={{ dns_reverse_cidr }} \
  --hostname=wilkesliberty-onprem \
  --accept-routes \
  --accept-dns=false

tailscale ip -4  # Note this — stored as onprem_tailscale_ip in network_secrets.yml
```

### Step 2.2: Install and Connect Tailscale (Cloud VPS)

**Automated by `make vps`** — installs Tailscale (Linux apt), authenticates with SOPS-decrypted auth key, joins tailnet as `wilkesliberty-vps`. Idempotent.

Manual equivalent:
```bash
curl -fsSL https://tailscale.com/install.sh | sh

sudo tailscale up \
  --authkey=<from tailscale_secrets.yml> \
  --hostname=wilkesliberty-vps \
  --accept-routes \
  --accept-dns=false

tailscale ip -4
```

### Step 2.3: Approve Subnet Routes in Tailscale Admin

> **Manual step — required regardless of automation.** Tailscale admin console approval cannot be automated.

1. Open https://login.tailscale.com (or `network.wilkesliberty.com` once DNS is live)
2. Find the `wilkesliberty-onprem` machine
3. Under **Subnet routes**, approve `{{ dns_reverse_cidr }}`
4. This allows the VPS to reach on-prem LAN services directly over Tailscale

### Step 2.4: Configure Tailscale Split DNS

**Automated by `make onprem`** — runs `tailscale set --dns-domain=int.wilkesliberty.com={{ coredns_ts_ip }}` automatically.

Manual equivalent — in Tailscale admin → DNS tab → Custom Nameservers:
- **Domain**: `int.wilkesliberty.com`
- **Nameserver**: `{{ coredns_ts_ip }}` (on-prem Tailscale IP from network_secrets.yml)

This routes all `*.int.wilkesliberty.com` queries to CoreDNS on the on-prem server, only for Tailscale-connected devices.

### Step 2.5: Verify Tailscale Connectivity

```bash
# From VPS — ping on-prem Tailscale IP
ping -c 3 <on-prem-tailscale-ip>

# From on-prem — ping VPS Tailscale IP
ping -c 3 <vps-tailscale-ip>
```

---

## PHASE 3: TERRAFORM DNS

### Step 3.1: Configure Terraform Variables

```bash
cd ~/Repositories/infra

# Decrypt and review Terraform secrets
sops -d terraform_secrets.yml

# Create terraform.tfvars (gitignored)
cat > terraform.tfvars << EOF
njalla_api_token = "<your_dns_api_token>"
vps_ipv4         = "<your_vps_ipv4>"
vps_ipv6         = "<your_vps_ipv6_or_empty_string>"
EOF

chmod 600 terraform.tfvars
```

### Step 3.2: Apply DNS Records

```bash
terraform init
terraform plan    # Review all records to be created
terraform apply   # Apply when satisfied
```

**Records applied**: apex A/AAAA, www, api, auth, search (all → VPS IP), network CNAME, Proton Mail records.

### Step 3.3: Add CAA Records Manually (DNS provider web UI)

The Terraform provider doesn't support CAA. Log in to your DNS provider and add these three records manually for `wilkesliberty.com`:

| Tag | Value |
|-----|-------|
| `issue` | `"letsencrypt.org"` |
| `issuewild` | `"letsencrypt.org"` |
| `iodef` | `"mailto:security@wilkesliberty.com"` |

Verify:
```bash
dig CAA wilkesliberty.com
```

---

## PHASE 4: ANSIBLE DEPLOYMENT (ON-PREM SERVER)

The `wl-onprem` Ansible role deploys and configures everything on the on-prem server in one run.

### Step 4.1: Validate Inventory

```bash
cd ~/Repositories/infra
ansible-inventory -i ansible/inventory/hosts.ini --graph
ansible -i ansible/inventory/hosts.ini all -m ping
```

### Step 4.2: Run the Deployment Playbook

```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml
```

This playbook:
1. Creates directory structure (`~/nas_docker/`, `~/nas_docker_staging/`, etc.)
2. Installs Docker Desktop, Tailscale, Proton VPN via Homebrew
3. Copies Docker Compose files and monitoring configs
4. Renders Alertmanager config from Jinja2 template
5. Deploys Caddy (internal — binds on Tailscale IP only)
6. Deploys CoreDNS with zone file for `int.wilkesliberty.com`
7. Deploys launchd plist for daily backups (02:00 AM)
8. Starts the production Docker stack (builds Drupal from `webcms`, Next.js from `ui`)

### Step 4.3: Configure SSH Access to the Cloud VPS

Ansible must be able to SSH into the VPS as root before running the VPS playbook. The inventory (`hosts.ini`) is already configured to use `~/.ssh/id_rsa`.

**On your local machine — copy your public key to the VPS:**

```bash
# Replace <vps-ip> with your actual VPS public IP
ssh-copy-id -i ~/.ssh/id_rsa.pub root@<vps-ip>
```

If `ssh-copy-id` is not available (rare on macOS), do it manually:

```bash
cat ~/.ssh/id_rsa.pub | ssh root@<vps-ip> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

**Verify Ansible can reach the VPS:**

```bash
cd ~/Repositories/infra
ansible -i ansible/inventory/hosts.ini cloud-vps -m ping
# Expected: <vps-ip> | SUCCESS => { "ping": "pong" }
```

If this fails, check:
- VPS firewall allows port 22 from your IP
- The `cloud_vps_ip` value in `network_secrets.yml` matches your actual VPS IP
- Your VPS provider hasn't disabled root SSH (some require enabling it in the control panel first)

### Step 4.4: Run the VPS Deployment Playbook

```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/vps.yml
```

This playbook deploys to the cloud VPS:
1. Installs Docker, Caddy, certbot
2. Deploys `Caddyfile.production.j2` (binds on all interfaces; uses certbot wildcard certs)
3. Deploys Next.js (built from `ui` repo)
4. Starts Caddy

---

## PHASE 5: LET'S ENCRYPT WILDCARD CERTIFICATE

### Step 5.1: Obtain Wildcard Certificate

On the cloud VPS:

```bash
# DNS-01 challenge for wildcard cert
certbot certonly \
  --manual \
  --preferred-challenges dns \
  -d "wilkesliberty.com" \
  -d "*.wilkesliberty.com"
```

Certbot will ask you to add a `_acme-challenge` TXT record. Add it manually in your DNS provider's web UI, wait ~60 seconds for propagation, then press Enter.

### Step 5.2: Verify Certificate

```bash
# Check cert is present and valid
ls -la /etc/letsencrypt/live/wilkesliberty.com/
openssl x509 -in /etc/letsencrypt/live/wilkesliberty.com/fullchain.pem -noout -dates
```

### Step 5.3: Caddy TLS Configuration

Caddy (`Caddyfile.production.j2`) is configured with `auto_https off` and uses the certbot-managed cert directly. Verify Caddy is reading the cert:

```bash
caddy reload
journalctl -u caddy -f
```

See `LETSENCRYPT_SSL_GUIDE.md` for renewal procedures.

---

## PHASE 6: DOCKER STACK VERIFICATION (ON-PREM SERVER)

### Step 6.1: Check Container Health

```bash
cd ~/nas_docker
docker compose ps
```

All services should show `healthy` or `running`:

```
wl_drupal              healthy   (built from webcms repo, serves api.wilkesliberty.com)
wl_postgres            healthy
wl_redis               healthy
wl_keycloak            healthy   (serves auth.wilkesliberty.com)
wl_solr                healthy
wl_prometheus          running
wl_grafana             running
wl_alertmanager        running
wl_node_exporter       running
wl_cadvisor            running
wl_postgres_exporter   running
```

### Step 6.2: Verify Redis Authentication

```bash
# Without password — should fail
docker exec wl_redis redis-cli ping
# Expected: NOAUTH Authentication required.

# With password — should succeed
docker exec wl_redis redis-cli -a "$REDIS_PASSWORD" ping
# Expected: PONG
```

### Step 6.3: Test Drupal (via internal Caddy)

From a device connected to Tailscale:

```bash
# Internal Caddy serves Drupal at api.int.wilkesliberty.com
curl -I https://api.int.wilkesliberty.com
# Expected: 200 OK

# Verify Redis connection in Drupal
docker exec wl_drupal drush status | grep cache
```

### Step 6.4: Create Solr Core

```bash
docker exec -it wl_solr bash -c "solr create -c drupal"

# Verify
curl http://localhost:8983/solr/admin/cores?action=STATUS
```

---

## PHASE 7: KEYCLOAK SSO SETUP

### Step 7.1: Access Keycloak Admin (Internal)

From a Tailscale-connected device:

```
https://sso.int.wilkesliberty.com
```

Or via public DNS (proxied through VPS):

```
https://auth.wilkesliberty.com
```

**Login**: admin / `KEYCLOAK_ADMIN_PASSWORD` from `.env`

### Step 7.2: Create Realm

1. Click **Add realm**
2. Name: `wilkesliberty`
3. Click **Create**

### Step 7.3: Create Grafana OAuth2 Client (Optional)

To enable Grafana SSO via Keycloak:

1. Go to **Clients** → **Create**
2. Client ID: `grafana`
3. Client Protocol: `openid-connect`
4. Valid Redirect URIs: `https://monitor.int.wilkesliberty.com/login/generic_oauth`
5. Note the client secret
6. Uncomment the `GF_AUTH_GENERIC_OAUTH_*` variables in `docker/.env` and fill in the client secret

---

## PHASE 8: COREDNS INTERNAL DNS

CoreDNS is deployed by the `wl-onprem` Ansible role and binds **only on the Tailscale IP** — it is not accessible from the public internet.

### Step 8.1: Verify CoreDNS Resolution

From a Tailscale-connected device:

```bash
# Query CoreDNS directly
dig @<on-prem-tailscale-ip> api.int.wilkesliberty.com
# Expected: {{ onprem_int_ip }}

dig @<on-prem-tailscale-ip> monitor.int.wilkesliberty.com
# Expected: {{ onprem_int_ip }}

dig @<on-prem-tailscale-ip> network.int.wilkesliberty.com
# Expected: A record (Tailscale IP); Caddy redirects to login.tailscale.com
```

### Step 8.2: Verify Split DNS is Working

After Tailscale Split DNS is configured (Phase 2, Step 2.4):

```bash
# From any Tailscale-connected device (should resolve without specifying @)
ping api.int.wilkesliberty.com
# Expected: resolves to {{ onprem_int_ip }}

# These should NOT resolve (no public DNS for int.wilkesliberty.com)
# Test from a non-Tailscale device — should get NXDOMAIN
```

### Step 8.3: Update Zone Serial (When Making Changes)

If you edit `coredns/zones/int.wilkesliberty.com.zone`, increment the serial in `YYYYMMDDNN` format before re-running Ansible.

---

## PHASE 9: VALIDATION & TESTING

### Step 9.1: Public URLs

From any internet-connected browser (no Tailscale required):

| URL | Expected |
|-----|----------|
| `https://www.wilkesliberty.com` | Next.js frontend |
| `https://api.wilkesliberty.com` | Drupal JSON:API / GraphQL |
| `https://auth.wilkesliberty.com` | Keycloak login page |

### Step 9.2: Internal URLs (Tailscale required)

From a Tailscale-connected device:

| URL | Expected |
|-----|----------|
| `https://api.int.wilkesliberty.com` | Drupal admin |
| `https://sso.int.wilkesliberty.com` | Keycloak admin |
| `https://monitor.int.wilkesliberty.com` | Grafana dashboards |
| `https://metrics.int.wilkesliberty.com` | Prometheus UI |
| `https://alerts.int.wilkesliberty.com` | Alertmanager |
| `https://uptime.int.wilkesliberty.com` | Uptime Kuma |

### Step 9.3: Security Header Verification

```bash
# Check public headers on www
curl -I https://www.wilkesliberty.com | grep -i "strict-transport\|x-frame\|content-security\|permissions"

# Check API headers
curl -I https://api.wilkesliberty.com | grep -i "strict-transport\|referrer"
```

Expected headers on HTML endpoints: `Strict-Transport-Security`, `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, `Content-Security-Policy`.

### Step 9.4: TLS Verification

```bash
# Verify TLS 1.2+ and certificate
openssl s_client -connect www.wilkesliberty.com:443 -tls1_1 2>&1 | grep "alert"
# Expected: handshake failure (TLS 1.1 rejected)

openssl s_client -connect www.wilkesliberty.com:443 -tls1_2 2>&1 | grep "Cipher"
# Expected: valid cipher suite

# Verify wildcard cert covers all subdomains
openssl s_client -connect api.wilkesliberty.com:443 2>&1 | grep "subject\|CN"
```

### Step 9.5: Monitoring Verification

From a Tailscale-connected device:

1. Open `https://monitor.int.wilkesliberty.com` → Grafana
   - Log in with admin / `GRAFANA_ADMIN_PASSWORD`
   - Go to **Configuration** → **Data Sources** → **Prometheus** → **Test**
   - Should show: "Data source is working"

2. Open `https://metrics.int.wilkesliberty.com` → Prometheus
   - Go to **Status** → **Targets**
   - All targets should be **UP**

3. Open `https://alerts.int.wilkesliberty.com` → Alertmanager
   - Should show "No alerts" (healthy)

### Step 9.6: Backup Verification

```bash
# Run backup manually
~/Scripts/backup-onprem.sh

# Verify backup created and encrypted
ls -lh ~/Backups/wilkesliberty/daily/

# Check automated backup is scheduled
launchctl list | grep wilkesliberty

# Test the backup is actually restorable (run quarterly)
make test-backup-restore
```

See `docs/BACKUP_RESTORE.md` for the full restore procedure. If `~/Backups/wilkesliberty/daily/` contains ~20-byte files, see `docs/SECURITY_CHECKLIST.md §6.8`.

---

## PHASE 10: OPERATIONAL PROCEDURES

### Daily Operations

```bash
cd ~/nas_docker

# Check service status
docker compose ps

# Stream all logs
docker compose logs -f

# Specific service logs
docker compose logs -f drupal
docker compose logs -f caddy
```

### Restart a Service

```bash
docker compose restart drupal

# Prometheus (note: --web.enable-lifecycle is intentionally disabled)
docker compose restart prometheus
```

### Update Docker Stack

```bash
cd ~/nas_docker

# Rebuild images (picks up latest commits from webcms/ui repos)
docker compose build --no-cache drupal nextjs

# Restart updated services
docker compose up -d drupal nextjs
```

### Weekly Maintenance

1. Check `https://monitor.int.wilkesliberty.com` for anomalies
2. Review backup logs: `tail -100 ~/Backups/wilkesliberty/logs/backup.log`
3. Check disk: `df -h ~/nas_docker`
4. Review Prometheus targets at `https://metrics.int.wilkesliberty.com/targets`

### Monthly Maintenance

1. Update Drupal core/modules:
   ```bash
   docker exec -it wl_drupal bash
   composer update drupal/core
   drush updb -y && drush cr
   exit
   ```

2. Rotate `REDIS_PASSWORD` if needed (update `.env`, restart drupal + redis)
3. Review certificate expiry: `openssl x509 -in /etc/letsencrypt/live/wilkesliberty.com/fullchain.pem -noout -enddate`
4. Review SOPS keys: `cat .sops.yaml` — rotate quarterly

---

## TROUBLESHOOTING

### Internal URLs Not Resolving

```bash
# Check Tailscale is connected
tailscale status

# Check Split DNS is configured (Tailscale admin → DNS tab)
# Verify CoreDNS is running on on-prem
docker exec wl_coredns sh -c "dig @localhost api.int.wilkesliberty.com"
```

### Redis Connection Refused / Auth Failure

```bash
# Verify REDIS_PASSWORD is set in .env
grep REDIS_PASSWORD ~/nas_docker/.env

# Test auth
docker exec wl_redis redis-cli -a "$REDIS_PASSWORD" ping

# Check Drupal's Redis connection
docker exec wl_drupal drush eval "var_dump(\Drupal::cache()->get('test'));"
```

### Drupal Trusted Host Rejection

If Drupal returns "The provided host name is not valid":
- Check `docker/drupal/settings.docker.php` — only explicitly listed hosts are allowed
- Allowed: `localhost`, `drupal`, `api.wilkesliberty.com`, `api.int.wilkesliberty.com`, `auth.wilkesliberty.com`, `sso.int.wilkesliberty.com`

### Caddy Can't Connect to On-prem Services

```bash
# Verify Tailscale mesh is up from VPS
tailscale ping <on-prem-tailscale-ip>

# Check Caddy upstream addresses in Caddyfile
# They should use the on-prem Tailscale IP (100.x.x.x), not LAN IP
```

### Service Won't Start

```bash
# Check logs
docker compose logs <service_name>

# Check disk
df -h ~/nas_docker

# Check permissions
ls -la ~/nas_docker/
```

### Database Connection Issues

```bash
docker exec -it wl_postgres pg_isready -U drupal
docker exec -it wl_drupal nc -zv postgres 5432
```

### Backup Failures

```bash
tail -100 ~/Backups/wilkesliberty/logs/backup.err
bash -x ~/Repositories/infra/scripts/backup-onprem.sh
```

---

## SUCCESS CRITERIA

Deployment is complete when:

- [ ] All 11 Docker containers running healthy on on-prem
- [ ] `https://www.wilkesliberty.com` loads Next.js frontend
- [ ] `https://api.wilkesliberty.com` returns Drupal JSON:API response
- [ ] `https://auth.wilkesliberty.com` shows Keycloak login
- [ ] `https://monitor.int.wilkesliberty.com` shows Grafana (Tailscale required)
- [ ] `https://metrics.int.wilkesliberty.com` — all targets UP
- [ ] Redis authentication working (`redis-cli -a $REDIS_PASSWORD ping` → PONG)
- [ ] TLS 1.1 rejected on public endpoints
- [ ] Security headers present on all public vhosts
- [ ] CAA records added in DNS provider web UI; `dig CAA wilkesliberty.com` returns 3 records
- [ ] `*.int.wilkesliberty.com` NOT resolvable from non-Tailscale devices
- [ ] Automated backups running daily at 2:00 AM (encrypted)
- [ ] No critical alerts firing in Alertmanager

---

## Related Documentation

- `README.md` — Architecture overview and quick reference
- `SECRETS_MANAGEMENT.md` — SOPS + AGE encryption guide
- `TAILSCALE_SETUP.md` — Tailscale VPN mesh and Split DNS
- `DNS_RECORDS.md` — DNS records reference
- `LETSENCRYPT_SSL_GUIDE.md` — Wildcard certificate management
- `ansible/README.md` — Ansible variable precedence and structure
