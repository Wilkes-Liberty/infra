# WilkesLiberty Infrastructure - Deployment Ready Summary

**Date**: March 30, 2026  
**Status**: ✅ **READY TO DEPLOY**  
**Deployment Method**: Fully Automated via Ansible

---

## 🎉 What's Complete

### Infrastructure Modernization
- ✅ **Simplified from 9 VPS hosts to 2-host architecture** (wl-onprem + future njalla-vps)
- ✅ **Removed 9 conflicting Ansible roles** - All functionality now in Docker Compose
- ✅ **Created comprehensive Docker Compose stack** - 11 containers with health checks
- ✅ **Implemented enterprise monitoring** - Prometheus/Grafana/Alertmanager with 16 alert rules
- ✅ **Automated backup system** - Daily backups with 90-day retention via launchd
- ✅ **Enhanced wl-onprem role** - Fully automated deployment (creates dirs, configs, starts services)
- ✅ **Updated all documentation** - Reflects current Docker-first architecture

### Documentation Accuracy
- ✅ **WARP.md** - Updated to reflect current on-prem Docker architecture
- ✅ **README.md** - Removed stale VPS references, updated to Docker-first
- ✅ **DEPLOYMENT_CHECKLIST.md** - 677-line step-by-step guide (already existed)
- ✅ **IMPLEMENTATION_STATUS.md** - Current progress tracking
- ✅ **SECRETS_MANAGEMENT.md** - SOPS/AGE guide (accurate)
- ✅ **TAILSCALE_SETUP.md** - VPN mesh setup (accurate)

---

## 🚀 Single-Command Deployment

Deploy the entire infrastructure with **ONE command**:

```bash
cd /Users/jcerda/Repositories/infra
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml
```

### What This Command Does:
1. ✅ Installs Homebrew (if missing)
2. ✅ Installs Docker Desktop
3. ✅ Creates all required directories:
   - `~/Backups/wilkesliberty/{daily,weekly,monthly,encrypted,logs}`
   - `~/nas_docker/{drupal,postgres,redis,keycloak,solr,prometheus,grafana,alertmanager}`
   - `~/Scripts/`
4. ✅ Copies `.env.example` to `.env` (you'll configure passwords after)
5. ✅ Deploys Grafana datasource and dashboard provisioning configs
6. ✅ Copies docker-compose.yml and monitoring configs to ~/nas_docker
7. ✅ Deploys backup script to ~/Scripts/backup-onprem.sh
8. ✅ Creates and loads launchd backup agent (daily at 4:00 AM)
9. ✅ Installs Tailscale and Proton VPN
10. ✅ Pulls all Docker images
11. ✅ Starts Docker Compose stack with 11 containers
12. ✅ Validates service health

---

## 📋 Post-Deployment Steps

After running the automated deployment, you need to:

### 1. Configure Environment Variables
```bash
# Edit the .env file
nano ~/nas_docker/.env

# Set these values:
# - DRUPAL_DB_PASSWORD (generate with: openssl rand -base64 32)
# - KEYCLOAK_ADMIN_PASSWORD
# - GRAFANA_ADMIN_PASSWORD
# - BACKUP_ENCRYPTION_KEY
# - SMTP settings (optional for alerts)
```

### 2. Complete Drupal Installation
- Visit http://localhost:8080
- Follow the installation wizard
- Database settings:
  - Type: PostgreSQL
  - Database: `drupal`
  - User: `drupal`
  - Password: (from DRUPAL_DB_PASSWORD in .env)
  - Host: `postgres`
  - Port: `5432`

### 3. Configure Solr
```bash
# Create Solr core
docker exec -it wl_solr solr create -c drupal

# Then configure Search API in Drupal at:
# Configuration → Search and metadata → Search API
```

### 4. Access Services
- **Drupal**: http://localhost:8080
- **Keycloak**: http://localhost:8081 (admin / KEYCLOAK_ADMIN_PASSWORD)
- **Grafana**: http://localhost:3001 (admin / GRAFANA_ADMIN_PASSWORD)
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093
- **Solr**: http://localhost:8983

### 5. Test Backup
```bash
~/Scripts/backup-onprem.sh
ls -lh ~/Backups/wilkesliberty/daily/
```

---

## 🔒 Prerequisites (Before Running Deployment)

### On Mac Mini:
- [ ] **Homebrew installed** (or let Ansible install it)
- [ ] **SOPS AGE key available**:
  ```bash
  export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
  ```
- [ ] **Ansible installed** on your control machine:
  ```bash
  pip install ansible
  ansible-galaxy collection install community.general
  ansible-galaxy collection install community.sops
  ```

### Secrets Configuration:
- [ ] **Tailscale auth key** stored in encrypted file:
  ```bash
  sops ansible/inventory/group_vars/tailscale_secrets.yml
  # Add: tailscale_auth_key: "tskey-auth-..."
  ```

---

## 📊 Infrastructure Summary

### Current Architecture
**Mac Mini M4 Pro** running **Docker Compose** with:

#### Application Services (5):
- Drupal 11 (port 8080)
- PostgreSQL 16
- Redis 7
- Keycloak (port 8081)
- Apache Solr 9.6 (port 8983)

#### Monitoring Stack (6):
- Prometheus (port 9090)
- Grafana (port 3001)
- Alertmanager (port 9093)
- Node Exporter (port 9100)
- cAdvisor (port 8082)
- Postgres Exporter (port 9187)

**Total**: 11 containers, ~13 CPUs, ~25GB RAM

### Network Topology
- **wl_frontend** (172.20.0.0/24): Public services
- **wl_backend** (172.21.0.0/24): Internal services
- **wl_monitoring** (172.22.0.0/24): Monitoring isolation

### VPN Layers
- **Outer**: Proton VPN (kill-switch, always-on)
- **Inner**: Tailscale mesh (100.64.0.0/10) for future VPS connectivity

---

## ✅ Success Criteria

You've deployed successfully when:

- ✅ All 11 Docker containers show "healthy" status
- ✅ Drupal accessible at http://localhost:8080
- ✅ Grafana showing metrics at http://localhost:3001
- ✅ Prometheus scraping all targets (Status → Targets)
- ✅ Automated backup scheduled (launchctl list | grep wilkesliberty)
- ✅ No critical alerts in Alertmanager
- ✅ Resource usage within limits (docker stats)

---

## 🔮 Future Work (Phase 1.5-2)

### Phase 1.5: Pre-Production (Optional)
- Import Grafana community dashboards
- Create test-restore.sh script
- Document 7-day performance baseline
- Create operational runbooks

### Phase 2: Distributed Architecture (Future)
- Deploy Njalla VPS with Next.js frontend
- Configure Tailscale mesh between VPS and Mac Mini
- Set up Caddy reverse proxy for public access
- Configure Let's Encrypt SSL

---

## 📚 Documentation Index

| Document | Purpose |
|----------|---------|
| **DEPLOYMENT_READY.md** | This document - deployment readiness summary |
| **DEPLOYMENT_CHECKLIST.md** | Detailed 677-line step-by-step deployment guide |
| **WARP.md** | Complete infrastructure architecture and commands |
| **README.md** | Repository overview and quick start |
| **IMPLEMENTATION_STATUS.md** | Current implementation progress tracking |
| **SECRETS_MANAGEMENT.md** | SOPS/AGE encryption guide |
| **TAILSCALE_SETUP.md** | VPN mesh configuration |
| **ansible/README.md** | Ansible variable precedence |

---

## 🎯 Next Steps

1. **Review this document** - Understand what will happen
2. **Ensure prerequisites met** - SOPS key, Ansible installed
3. **Run the deployment**:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml
   ```
4. **Configure .env passwords** - Edit ~/nas_docker/.env
5. **Complete Drupal installation** - Visit http://localhost:8080
6. **Verify all services healthy** - Check Grafana dashboards
7. **Test backup** - Run ~/Scripts/backup-onprem.sh

---

**You're ready to deploy!** 🚀

The infrastructure is fully automated, documented, and production-ready.
