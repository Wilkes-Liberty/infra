# =============================================
# Wilkes-Liberty Infrastructure Makefile
# =============================================

.PHONY: help bootstrap check onprem monitoring vps deploy clean docker-clean status

help:
	@echo "Available targets:"
	@echo "  bootstrap     - Install required local tools (sops, age, terraform, ansible)"
	@echo "  check         - Validate local environment before deploying"
	@echo "  onprem        - Deploy wl-onprem role (on-prem server + Docker stack)"
	@echo "  monitoring    - Deploy Prometheus + Grafana"
	@echo "  vps           - Deploy Njalla VPS (Let's Encrypt + Caddy)"
	@echo "  deploy        - Full deployment (onprem + vps)"
	@echo "  status        - Show Docker container health"
	@echo "  clean         - Stop Docker services"
	@echo "  docker-clean  - Prune Docker images/cache"

# Install required local operator tools (run once on a new machine)
bootstrap:
	./scripts/bootstrap.sh

# Validate local environment before deploying
check:
	./scripts/dev-environment-check.sh

# Deploy the on-prem server (wl-onprem role)
# Decrypts sudo password from SOPS at run time and passes via --become-password-file.
# The temp file is always removed, even if the playbook fails.
onprem:
	@tmpfile=$$(mktemp) && \
	  sops -d --extract '["ansible_become_pass"]' ansible/inventory/group_vars/become.sops.yml > "$$tmpfile" && \
	  ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml --limit wl-onprem --become-password-file "$$tmpfile"; \
	  rc=$$?; rm -f "$$tmpfile"; exit $$rc

# Deploy monitoring stack
monitoring:
	ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/monitoring.yml

# Deploy Njalla VPS reverse proxy
vps:
	ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/vps.yml

# Full deployment (recommended)
# Note: monitoring stack (Prometheus/Grafana/Alertmanager) is part of wl-onprem's
# docker-compose — the separate 'monitoring' role/playbook was a dead stub and has
# been removed from this target.
deploy:
	@tmpfile=$$(mktemp) && \
	  sops -d --extract '["ansible_become_pass"]' ansible/inventory/group_vars/become.sops.yml > "$$tmpfile" && \
	  ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml --limit wl-onprem --become-password-file "$$tmpfile" && \
	  ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/vps.yml; \
	  rc=$$?; rm -f "$$tmpfile"; exit $$rc

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