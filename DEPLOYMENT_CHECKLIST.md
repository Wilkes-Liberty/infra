# WilkesLiberty Infrastructure - Complete Deployment Checklist

**Version**: 1.0  
**Last Updated**: March 30, 2026  
**Estimated Time**: 2-3 hours for initial setup

---

## 📋 **PRE-DEPLOYMENT CHECKLIST**

### ✅ **Prerequisites** (Verify Before Starting)

- [ ] **Mac Mini M4 Pro** is operational
- [ ] **Docker Desktop** installed and running
- [ ] **Homebrew** installed (`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`)
- [ ] **Git** repository cloned to `/Users/jcerda/Repositories/infra`
- [ ] **4TB Synology NAS** mounted and accessible
- [ ] **Internet connectivity** verified
- [ ] **Proton VPN** installed (optional but recommended)
- [ ] **Tailscale** account created (for VPN mesh)

---

## 🚀 **PHASE 1: ENVIRONMENT SETUP**

### Step 1.1: Create Required Directories

```bash
# Navigate to home
cd ~

# Create main backup directory structure
mkdir -p ~/Backups/wilkesliberty/{daily,weekly,monthly,encrypted,logs}

# Create Docker data directories
mkdir -p ~/nas_docker/{drupal,postgres,redis,keycloak,solr}
mkdir -p ~/nas_docker/prometheus/{data,}
mkdir -p ~/nas_docker/grafana/{provisioning/datasources,provisioning/dashboards,dashboards}
mkdir -p ~/nas_docker/alertmanager

# Verify creation
ls -la ~/nas_docker/
ls -la ~/Backups/wilkesliberty/
```

### Step 1.2: Configure Environment Variables

```bash
# Navigate to docker directory
cd /Users/jcerda/Repositories/infra/docker

# Copy environment template
cp .env.example .env

# Edit with your actual secrets
nano .env
```

**IMPORTANT**: Update these values in `.env`:

```bash
# Strong passwords (generate with: openssl rand -base64 32)
DRUPAL_DB_PASSWORD=your_strong_password_here
KEYCLOAK_ADMIN_PASSWORD=your_strong_password_here
GRAFANA_ADMIN_PASSWORD=your_strong_password_here

# Email alerts (optional)
ALERT_EMAIL_FROM=alerts@wilkesliberty.com
ALERT_EMAIL_TO=your_email@example.com
ALERT_SMTP_HOST=smtp.gmail.com
ALERT_SMTP_PORT=587
ALERT_SMTP_USER=your_email@gmail.com
ALERT_SMTP_PASSWORD=your_smtp_password

# Backup encryption (generate with: openssl rand -base64 32)
BACKUP_ENCRYPTION_KEY=your_encryption_key_here
BACKUP_NOTIFICATION_EMAIL=your_email@example.com
```

### Step 1.3: Create Grafana Datasource Configuration

```bash
# Create Prometheus datasource
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

### Step 1.4: Create Grafana Dashboard Provisioning

```bash
# Create dashboard provisioning config
cat > ~/nas_docker/grafana/provisioning/dashboards/dashboards.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF
```

---

## 🐳 **PHASE 2: DOCKER STACK DEPLOYMENT**

### Step 2.1: Validate Docker Compose Configuration

```bash
cd /Users/jcerda/Repositories/infra/docker

# Validate syntax
docker compose config

# Check for errors
echo $?  # Should output: 0
```

### Step 2.2: Deploy the Stack

```bash
# Pull all images (this may take 10-15 minutes)
docker compose pull

# Start all services
docker compose up -d

# Watch the startup logs
docker compose logs -f
```

**Expected Output**: All 11 containers should start successfully

### Step 2.3: Verify Service Health

```bash
# Check container status
docker compose ps

# All services should show "healthy" or "running"
# Wait 2-3 minutes for health checks to pass

# Detailed health status
docker inspect wl_drupal | grep -A 10 Health
docker inspect wl_postgres | grep -A 10 Health
docker inspect wl_keycloak | grep -A 10 Health
```

### Step 2.4: Test Service Connectivity

```bash
# Test Drupal
curl -I http://localhost:8080

# Test Keycloak
curl -I http://localhost:8081

# Test Solr
curl http://localhost:8983/solr/admin/ping

# Test Prometheus
curl http://localhost:9090/-/healthy

# Test Grafana
curl http://localhost:3001/api/health

# Test Alertmanager
curl http://localhost:9093/-/healthy
```

**Expected**: All should return successful responses (200 OK or similar)

---

## 📊 **PHASE 3: MONITORING CONFIGURATION**

### Step 3.1: Access Grafana

```bash
# Open Grafana in browser
open http://localhost:3001
```

**Login Credentials**:
- Username: `admin`
- Password: (value from `GRAFANA_ADMIN_PASSWORD` in `.env`)

### Step 3.2: Verify Prometheus Data Source

1. Go to **Configuration** → **Data Sources**
2. Click on **Prometheus**
3. Click **Test** button
4. Should see: "Data source is working"

### Step 3.3: Import Pre-built Dashboards (Optional)

```bash
# Download community dashboards
cd ~/nas_docker/grafana/dashboards

# Node Exporter Full dashboard
curl -o node-exporter-full.json https://grafana.com/api/dashboards/1860/revisions/27/download

# Docker Container dashboard
curl -o docker-containers.json https://grafana.com/api/dashboards/193/revisions/5/download

# PostgreSQL dashboard
curl -o postgresql.json https://grafana.com/api/dashboards/9628/revisions/7/download
```

Dashboards will auto-load in Grafana within 10 seconds.

### Step 3.4: Test Alerting

```bash
# Trigger a test alert by stopping a service
docker stop wl_redis

# Wait 5 minutes, then check Alertmanager
open http://localhost:9093

# You should see "ServiceDown" alert firing

# Restart the service
docker start wl_redis
```

---

## 💾 **PHASE 4: BACKUP SYSTEM SETUP**

### Step 4.1: Test Manual Backup

```bash
# Run backup script manually
/Users/jcerda/Repositories/infra/scripts/backup-onprem.sh

# Check backup was created
ls -lh ~/Backups/wilkesliberty/daily/

# Verify manifest
cat ~/Backups/wilkesliberty/daily/$(ls -t ~/Backups/wilkesliberty/daily/ | head -1)/MANIFEST.txt
```

**Expected**: Backup completes successfully with no errors

### Step 4.2: Configure Automated Backups

```bash
# Copy launchd plist to LaunchAgents
cp /Users/jcerda/Repositories/infra/config/com.wilkesliberty.backup.plist ~/Library/LaunchAgents/

# Load the launch agent
launchctl load ~/Library/LaunchAgents/com.wilkesliberty.backup.plist

# Verify it's loaded
launchctl list | grep wilkesliberty

# Test immediate run
launchctl start com.wilkesliberty.backup

# Check logs
tail -f ~/Backups/wilkesliberty/logs/backup.log
```

### Step 4.3: Configure Mac Mini Wake Schedule (Optional)

1. **System Settings** → **Battery** (or Energy Saver)
2. Click **Options**
3. Enable **"Wake for network access"**
4. Enable **"Start up automatically after power failure"**

This ensures backups run even if Mac Mini sleeps.

---

## 🔐 **PHASE 5: DRUPAL INSTALLATION**

### Step 5.1: Access Drupal Installer

```bash
open http://localhost:8080
```

### Step 5.2: Complete Drupal Installation

1. **Choose language**: English
2. **Select profile**: Standard
3. **Database configuration**:
   - Database type: **PostgreSQL**
   - Database name: `drupal`
   - Database username: `drupal`
   - Database password: (value from `DRUPAL_DB_PASSWORD` in `.env`)
   - Advanced options:
     - Host: `postgres`
     - Port: `5432`

4. **Site configuration**:
   - Site name: `WilkesLiberty`
   - Site email: your email
   - Username: `admin`
   - Password: (create strong password)
   - Email: your email

5. Click **Save and continue**

**Expected**: Drupal installation completes successfully

### Step 5.3: Install Required Modules

```bash
# Access Drupal container
docker exec -it wl_drupal bash

# Enable GraphQL modules (should already be in composer.json)
drush en graphql graphql_compose graphql_compose_menus -y

# Enable Search API + Solr
drush en search_api search_api_solr -y

# Enable Redis
drush en redis -y

# Clear cache
drush cr

# Exit container
exit
```

---

## 🔍 **PHASE 6: SOLR CONFIGURATION**

### Step 6.1: Configure Search API Solr

1. Access Drupal admin: `http://localhost:8080/admin`
2. Go to **Configuration** → **Search and metadata** → **Search API**
3. Click **Add server**
4. Configure:
   - Server name: `Solr Server`
   - Backend: **Solr**
   - Solr Connector: **Standard**
   - HTTP protocol: `http`
   - Solr host: `solr`
   - Solr port: `8983`
   - Solr path: `/`
   - Solr core: `drupal` (create this in Solr first)

### Step 6.2: Create Solr Core

```bash
# Access Solr container
docker exec -it wl_solr bash

# Create Drupal core
solr create -c drupal

# Exit container
exit

# Verify core was created
curl http://localhost:8983/solr/admin/cores?action=STATUS
```

---

## 🔑 **PHASE 7: KEYCLOAK SSO SETUP** (Optional)

### Step 7.1: Access Keycloak Admin

```bash
open http://localhost:8081
```

**Login**:
- Username: `admin`
- Password: (value from `KEYCLOAK_ADMIN_PASSWORD` in `.env`)

### Step 7.2: Create Realm

1. Click **Add realm**
2. Name: `wilkesliberty`
3. Click **Create**

### Step 7.3: Create Client for Drupal

1. Go to **Clients** → **Create**
2. Client ID: `drupal`
3. Client Protocol: `openid-connect`
4. Root URL: `http://localhost:8080`
5. **Save**

---

## 🌐 **PHASE 8: NETWORKING (FUTURE - NJALLA VPS)**

### Step 8.1: Tailscale Setup (On Mac Mini)

```bash
# Install Tailscale
brew install tailscale

# Start Tailscale
sudo tailscaled

# Authenticate (opens browser)
sudo tailscale up

# Get your Tailscale IP
tailscale ip -4
```

**Note this IP** - you'll need it for Njalla VPS configuration

### Step 8.2: Njalla VPS Deployment (When Ready)

**This step is for future deployment**. You'll need to:

1. Provision Njalla VPS
2. Install Tailscale on VPS
3. Connect to same Tailnet
4. Deploy Next.js frontend (from `ui` repo)
5. Configure Caddy reverse proxy to Mac Mini Tailscale IP

See `ansible/playbooks/vps.yml` for automation.

---

## ✅ **PHASE 9: VALIDATION & TESTING**

### Step 9.1: Service Health Dashboard

```bash
# Check all services
docker compose ps

# Should see:
# - wl_drupal: healthy
# - wl_postgres: healthy
# - wl_redis: healthy
# - wl_keycloak: healthy
# - wl_solr: healthy
# - wl_prometheus: healthy
# - wl_grafana: healthy
# - wl_alertmanager: healthy
# - wl_node_exporter: running
# - wl_cadvisor: running
# - wl_postgres_exporter: running
```

### Step 9.2: Monitoring Verification

1. **Grafana**: `http://localhost:3001`
   - Verify Prometheus data source connected
   - Check dashboards showing metrics
   
2. **Prometheus**: `http://localhost:9090`
   - Go to **Status** → **Targets**
   - All targets should be "UP"
   
3. **Alertmanager**: `http://localhost:9093`
   - Should show "No alerts" (healthy state)

### Step 9.3: Backup Verification

```bash
# Check latest backup exists
ls -lh ~/Backups/wilkesliberty/daily/

# Check backup manifest
cat ~/Backups/wilkesliberty/daily/$(ls -t ~/Backups/wilkesliberty/daily/ | head -1)/MANIFEST.txt

# Verify automated backup is scheduled
launchctl list | grep wilkesliberty
```

### Step 9.4: Resource Usage Check

```bash
# Check Docker resource usage
docker stats --no-stream

# Check Mac Mini resources
top -l 1 | head -10
```

**Expected Resource Usage**:
- CPU: 20-40% average
- Memory: 16-20GB used (of 24GB+ available)
- Disk: Check with `df -h ~/nas_docker`

---

## 🎯 **PHASE 10: OPERATIONAL PROCEDURES**

### Daily Operations

**View logs**:
```bash
cd /Users/jcerda/Repositories/infra/docker

# All services
docker compose logs -f

# Specific service
docker compose logs -f drupal
docker compose logs -f postgres
```

**Restart service**:
```bash
# Restart single service
docker compose restart drupal

# Restart all services
docker compose restart
```

**Stop services**:
```bash
# Stop all
docker compose down

# Stop and remove volumes (CAUTION: DATA LOSS)
# docker compose down -v
```

**Start services**:
```bash
docker compose up -d
```

### Weekly Maintenance

1. **Check Grafana dashboards** for anomalies
2. **Review backup logs**: `tail -100 ~/Backups/wilkesliberty/logs/backup.log`
3. **Check disk space**: `df -h ~/nas_docker`
4. **Review Prometheus alerts**: `http://localhost:9093`

### Monthly Maintenance

1. **Update Docker images**:
   ```bash
   cd /Users/jcerda/Repositories/infra/docker
   docker compose pull
   docker compose up -d
   ```

2. **Test backup restore** (create separate test script)
3. **Review performance baselines** in Grafana
4. **Update Drupal core/modules**:
   ```bash
   docker exec -it wl_drupal bash
   composer update drupal/core
   drush updb -y
   drush cr
   ```

---

## 🐛 **TROUBLESHOOTING**

### Service Won't Start

```bash
# Check logs
docker compose logs service_name

# Check disk space
df -h

# Check permissions
ls -la ~/nas_docker/
```

### Database Connection Issues

```bash
# Verify PostgreSQL is running
docker exec -it wl_postgres pg_isready -U drupal

# Check connection from Drupal
docker exec -it wl_drupal nc -zv postgres 5432
```

### Backup Failures

```bash
# Check backup logs
tail -100 ~/Backups/wilkesliberty/logs/backup.err

# Run manual backup with verbose output
bash -x /Users/jcerda/Repositories/infra/scripts/backup-onprem.sh
```

### Prometheus Not Scraping

```bash
# Check Prometheus targets
open http://localhost:9090/targets

# Verify containers are on correct network
docker network inspect wl_monitoring
```

### High Resource Usage

```bash
# Check container resource usage
docker stats

# Identify heavy container
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Check Mac Mini resources
top -o cpu
```

---

## 📞 **EMERGENCY CONTACTS**

**Infrastructure Issues**:
- Check `IMPLEMENTATION_STATUS.md` for details
- Review logs in `~/Backups/wilkesliberty/logs/`

**Backup Restoration**:
- See backup manifest in backup directory
- Use `pg_restore` for database recovery

---

## 🎉 **SUCCESS CRITERIA**

You've successfully deployed when:

- ✅ All 11 Docker containers running and healthy
- ✅ Drupal accessible at `http://localhost:8080`
- ✅ Grafana showing metrics at `http://localhost:3001`
- ✅ Prometheus scraping all targets at `http://localhost:9090`
- ✅ Automated backups running daily at 4:00 AM
- ✅ Alert notifications configured and tested
- ✅ No critical alerts firing in Alertmanager
- ✅ Resource usage within normal limits (CPU < 50%, RAM < 20GB)

**Congratulations! Your enterprise-grade infrastructure is operational.** 🚀

---

**Next Steps**:
1. Deploy Next.js frontend to Njalla VPS (see `ui` repo)
2. Configure Drupal content types and GraphQL schema
3. Set up Tailscale VPN mesh between Mac Mini and Njalla
4. Establish performance baselines (run for 7 days)
5. Create operational runbooks for team

**Documentation**:
- **Implementation Status**: `IMPLEMENTATION_STATUS.md`
- **Implementation Plan**: View in Warp (plan ID: 4d902060-84ed-40fe-986e-e814b122e283)
- **WARP.md**: Architecture overview and history
