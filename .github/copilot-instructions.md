# Copilot Instructions for `infra` Repository

## Overview

This repository manages infrastructure-as-code and automation for the Wilkes-Liberty organization. It is structured for modular, maintainable, and auditable infrastructure changes.

### Architecture

- **Major Components:**
    - Each top-level directory is a distinct infrastructure domain (e.g., `terraform/`, `ansible/`, `scripts/`).
    - Service boundaries are enforced by separating cloud resources, configuration management, and automation scripts.
    - Data flows from configuration files (YAML, HCL) through automation scripts to cloud APIs and on-prem resources.

- **Rationale:**
    - Separation of concerns enables parallel development and easier auditing.
    - Modular directories allow for targeted CI/CD pipelines and environment-specific deployments.

## Developer Workflows

### Build & Deploy

- Use `make` commands (see `Makefile`) for common tasks: `make plan`, `make apply`, `make lint`.
- **Terraform:**
    - Initialize: `terraform init`
    - Plan: `terraform plan -var-file=env/dev.tfvars`
    - Apply: `terraform apply -var-file=env/dev.tfvars`
- **Ansible:**
    - Run playbooks: `ansible-playbook -i inventory/hosts playbook.yml`
- Custom scripts are in `scripts/` and may require `python3` or `bash`.

### Testing

- Linting: `make lint` or `terraform fmt -check`
- Unit tests (if present): `pytest` in relevant directories.
- Integration tests: See `test/` or `tests/` directories.

### Debugging

- Use verbose flags: `terraform plan -out=plan.out -detailed-exitcode`
- For Ansible: `-vvv` for increased verbosity.

## Project Conventions

- **Naming:**
    - Resource names are prefixed by environment and service (e.g., `dev-db-instance`).
    - Variables and outputs use `snake_case`.
- **Secrets Management:**
    - Secrets are never committed; use environment variables or secret managers (see `README.md`).
- **Branching:**
    - All changes go through PRs to `master`. Feature branches: `feature/<description>`.

## Integration Points

- **Cloud Providers:** Integrates with AWS, Azure, and GCP via Terraform providers.
- **CI/CD:** GitHub Actions workflows in `.github/workflows/` handle linting, planning, and applying changes.
- **Notifications:** Slack and email notifications are configured for deployment events.

## Patterns & Anti-Patterns

- **Do:**
    - Use modules for reusable infrastructure.
    - Document all changes in PRs.
- **Don't:**
    - Hardcode credentials or environment-specific values.
    - Bypass CI/CD for production changes.

## Getting Help

- See `README.md` for onboarding.
- For questions, open an issue or contact the `#infra` Slack channel.

---

# AI Agent Guidance

**Status:** ACTIVE (infrastructure repo: Terraform + Ansible + CoreDNS + service configs)

## 1. Purpose

Guidance for AI coding agents to produce minimal, safe, context-aware changes. Prioritize correctness, idempotence, and auditability. Never invent secrets.

## 2. Quick Start Checklist

1. List root files (expect: `main.tf`, `records.tf`, `mail_proton.tf`, `variables.tf`, `outputs.tf`, `provider.tf`).
2. Read strategy docs: `README.md`, `MULTI_ENVIRONMENT_STRATEGY.md`, `TERRAFORM_ORGANIZATION.md`, `DNS_RECORDS.md`, `GITHUB_ACTIONS_STRATEGY.md`.
3. Inspect scripts: `scripts/load-terraform-secrets.sh`, `scripts/dev-environment-check.sh`.
4. For config changes, open: `ansible/inventory/hosts.ini` and sample `host_vars/*.yml`.
5. Before altering providers or backend: request contents of `provider.tf`.

## 3. High-Level Architecture

- Terraform (single root) manages external/public concerns (currently DNS + Proton Mail records).
- Ansible manages host-level service configuration (app, cache, db, solr, authentik, wireguard, coredns, analytics, resolver).
- CoreDNS (deployed via Ansible) serves internal authoritative and reverse zones.
- Separation rationale: immutable/public infra via Terraform; faster mutable config via Ansible; clear public vs internal DNS boundary.
- Email deliverability (SPF/MX/DKIM/DMARC/verification) via `mail_proton.tf`.

## 4. Directory Map (Condensed)

- **Root:** `main.tf`, `provider.tf`, `variables.tf`, `outputs.tf`, `records.tf`, `mail_proton.tf`, `terraform.tfvars`, `terraform_secrets.yml`
- **Docs:** `README.md`, `MULTI_ENVIRONMENT_STRATEGY.md`, `TERRAFORM_ORGANIZATION.md`, `DNS_RECORDS.md`, `GITHUB_ACTIONS_STRATEGY.md`, `AUDIT_SUMMARY.md`, `WARP.md`, `CONTRIBUTING.md`
- **Ansible:** `ansible.cfg`, `inventory/`, `group_vars/`, `host_vars/`, `playbooks/`, `roles/`
- **Roles:** `analytics_obs`, `app`, `authentik`, `cache`, `common`, `coredns`, `db`, `resolved`, `solr`, `wireguard`
- **CoreDNS Reference:** `coredns/Corefile`, `coredns/zones/int.wilkesliberty.com.zone`
- **Scripts:** `load-terraform-secrets.sh`, `dev-environment-check.sh`, `backup-db.sh`, `migrate-to-multi-env.sh`
- **Makefile:** Contains helper targets (inspect before duplicating).

## 5. Environments

Current inventory shows only prod hosts (`<service>1.prod.wilkesliberty.com`).  
Adding an environment requires:
- New hostnames + `inventory/hosts.ini` entries.
- Corresponding `host_vars/` files.
- Internal + (if needed) external DNS updates.
- Documentation update in `MULTI_ENVIRONMENT_STRATEGY.md`.

**Do not introduce Terraform workspaces or extra state backends without aligning with documented strategy.**

## 6. Data & Traffic Flows

- Public user → Public DNS (Terraform records) → (cache / caddy / varnish) → app → db / solr
- User auth → authentik (SSO) → app
- Internal resolution → CoreDNS (internal + reverse zones)
- Admin / ops → WireGuard tunnel → hosts
- Email MTAs → Proton Mail DNS records (Terraform)

## 7. External / Service Integrations

- Proton Mail DNS (mail delivery + authentication)
- Authentik (identity / SSO)
- WireGuard (secure admin network)
- Solr (search)
- CoreDNS (internal authoritative DNS)
- Analytics / observability role (internal metrics/logs)

## 8. Terraform Standards

- Single root module (no nested `modules/` currently).
- Thematic file separation (`records.tf`, `mail_proton.tf`).
- All input variables in `variables.tf` only.
- Keep outputs minimal (no secrets / sensitive info).
- Group related DNS records together; avoid interleaving unrelated changes.
- Prefer data sources instead of hardcoded identifiers.
- Summarize plan impact (add / change / destroy counts) before proposing apply.
- 