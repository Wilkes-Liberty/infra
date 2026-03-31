# =============================================
# Wilkes-Liberty Infrastructure Makefile
# =============================================

.PHONY: help bootstrap onprem monitoring vps deploy clean docker-clean

help:
	@echo "Available targets:"
	@echo "  bootstrap     - Bootstrap base tools (Homebrew, etc.)"
	@echo "  onprem        - Deploy wl-onprem role (on-prem server + Docker stack)"
	@echo "  monitoring    - Deploy Prometheus + Grafana"
	@echo "  vps           - Deploy Njalla VPS reverse proxy (Caddy)"
	@echo "  deploy        - Full deployment (onprem + monitoring + vps)"
	@echo "  clean         - Stop Docker services"
	@echo "  docker-clean  - Prune Docker images/cache"

# Bootstrap base tools
bootstrap:
	ansible-playbook -i inventory/hosts.ini playbooks/bootstrap.yml

# Deploy the on-prem server (wl-onprem role)
onprem:
	ansible-playbook -i inventory/hosts.ini playbooks/onprem.yml --limit wl-onprem

# Deploy monitoring stack
monitoring:
	ansible-playbook -i inventory/hosts.ini playbooks/monitoring.yml

# Deploy Njalla VPS reverse proxy
vps:
	ansible-playbook -i inventory/hosts.ini playbooks/vps.yml

# Full deployment (recommended)
deploy: onprem monitoring vps

# Clean Docker services on the on-prem server
clean:
	docker compose -f ~/nas_docker/docker-compose.yml down

# Aggressive Docker cleanup (use when needed)
docker-clean:
	docker system prune -a -f --volumes
	docker builder prune -a -f

# Quick status check
status:
	docker compose -f ~/nas_docker/docker-compose.yml ps