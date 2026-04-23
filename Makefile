# =============================================
# Wilkes-Liberty Infrastructure Makefile
# =============================================

.PHONY: help bootstrap check onprem vps deploy refresh-staging clean docker-clean status test-backup-restore

help:
	@echo "Available targets:"
	@echo "  bootstrap            - Install required local tools (sops, age, terraform, ansible)"
	@echo "  check                - Validate local environment before deploying"
	@echo "  onprem               - Deploy wl-onprem role (on-prem server + Docker stack)"
	@echo "  vps                  - Deploy Njalla VPS (Let's Encrypt + Caddy)"
	@echo "  deploy               - Full deployment (onprem + vps)"
	@echo "  refresh-staging      - Clone prod DB → staging with sanitization (DESTRUCTIVE)"
	@echo "  status               - Show Docker container health"
	@echo "  clean                - Stop Docker services"
	@echo "  docker-clean         - Prune Docker images/cache"
	@echo "  test-backup-restore  - Restore latest backup into a temp container and verify"

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

# Deploy Njalla VPS reverse proxy
vps:
	ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/vps.yml

# Full deployment (recommended)
# Monitoring stack (Prometheus/Grafana/Alertmanager) is part of wl-onprem's docker-compose.
deploy:
	@tmpfile=$$(mktemp) && \
	  sops -d --extract '["ansible_become_pass"]' ansible/inventory/group_vars/become.sops.yml > "$$tmpfile" && \
	  ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/onprem.yml --limit wl-onprem --become-password-file "$$tmpfile" && \
	  ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/vps.yml; \
	  rc=$$?; rm -f "$$tmpfile"; exit $$rc

# Clone prod DB + files → staging, sanitize, then verify.
# Prompts for confirmation — this WIPES the staging database.
# See docs/STAGING_REFRESH.md for full details.
refresh-staging:
	@printf "\033[0;33m⚠️  WARNING: This will wipe the staging database and replace it with sanitized production data.\033[0m\n"
	@printf "Type 'yes' to continue: " && read ans && [ "$${ans}" = "yes" ] || { printf "Aborted.\n"; exit 1; }
	ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/refresh-staging.yml

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

# Restore the latest daily backup into a temporary Postgres container and verify.
# Requires Docker to be running. Exits 0 on pass, 1 on fail.
test-backup-restore:
	./scripts/test-backup-restore.sh