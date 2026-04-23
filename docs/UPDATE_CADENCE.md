# WilkesLiberty — Dependency & Platform Update Cadence

Policy for keeping the stack current. Covers all layers: OS, runtimes, Drupal, Next.js, Docker images, and tooling.

**Owner:** operator (Jeremy)
**Last reviewed:** 2026-04-23

---

## Cadence Matrix

| Component | Check frequency | Apply window | How to check | How to apply |
|---|---|---|---|---|
| **Drupal core (security)** | Weekly | 7 days | `docker exec wl_drupal drush pm:security` | `composer update drupal/core-recommended --with-all-dependencies` in `~/Repositories/webcms`, then `make onprem` |
| **Drupal core (minor/major)** | Monthly | Own schedule | Drupal.org release notes | As above; test in staging first (`make refresh-staging && make onprem-staging`) |
| **Drupal contrib modules (security)** | Weekly | 7 days | `docker exec wl_drupal drush pm:security` | `composer update drupal/<module>` in `~/Repositories/webcms`, then `make onprem` |
| **Drupal contrib modules (non-security)** | Monthly | Best effort | `docker exec wl_drupal drush pm:security` + Available Updates UI (`/admin/reports/updates`) | `composer outdated --direct` in container or via docker run; update individually |
| **Composer deps (all, webcms)** | Monthly | Security: 7 days; non-security: best effort | `docker run --rm -v ~/Repositories/webcms:/app -w /app -e COMPOSER_HOME=/tmp composer:2 audit` | `composer update <package>` — do NOT blanket `composer update`; update targeted packages |
| **Next.js / UI dependencies** | Monthly | Security: 7 days; non-security: best effort | `cd ~/Repositories/ui && npm audit` | `npm install <pkg>@<fixed>` or `npm update <pkg>`; then `make vps` |
| **Next.js outdated (non-security)** | Monthly | Best effort | `cd ~/Repositories/ui && npm outdated` | Update individually; test locally first |
| **Docker base images** | Monthly (minor/patch) · Quarterly (major) | Best effort | Compare `docker compose images` versions against release notes | Edit pinned tags in `docker/docker-compose.yml`, run `make onprem` |
| **Tailscale (on-prem)** | Auto | n/a | `brew list --versions tailscale` | `brew upgrade tailscale` (auto-updates if Cask auto-update enabled) |
| **Tailscale (VPS)** | Monthly | Best effort | `tailscale version` on VPS | `apt-get update && apt-get install tailscale` |
| **PHP runtime (Drupal container)** | Quarterly | Follow upstream support | Check `drupal:11-apache` tag in Docker Hub | Pin a newer `php:<ver>-apache-bookworm` in `docker/drupal/Dockerfile.prod`; test in staging |
| **Node.js runtime (Next.js container)** | Quarterly | Follow LTS schedule | Check `node:20-alpine` tag; monitor nodejs.org/en/about/releases | Pin `node:<LTS>-alpine` in `docker/nextjs/Dockerfile.prod`; test in staging |
| **Keycloak** | Quarterly | Test staging first | `docker exec wl_keycloak sh -c 'echo $KEYCLOAK_VERSION'` vs keycloak.org releases | Update tag in `docker-compose.yml`; run `make onprem`; test SSO flows in staging |
| **Python / Ansible** | Quarterly | Best effort | `pip-audit` · `ansible-galaxy collection list` | `pip install --upgrade ansible`; `ansible-galaxy collection install community.general community.sops --upgrade` |
| **Caddy (custom build)** | Quarterly | Best effort | `caddy version` vs github.com/caddyserver/caddy/releases | Update `caddy_custom_version` in `ansible/inventory/group_vars/all.yml`; `make vps && make onprem` |
| **macOS (on-prem)** | As released | Best effort | System Settings → Software Update | Manual; schedule during low-traffic window |

---

## Emergency Response (CVE Drops)

When a security advisory is published for any component in the stack:

1. **Triage** — determine severity (critical / high / medium / low), affected versions, and whether the vulnerable code path is reachable from the public internet.

2. **Patching window**
   - Critical / High: patch within **24 hours** of a fix being available
   - Medium: patch within **7 days**
   - Low: include in next monthly pass

3. **Process**
   ```bash
   # 1. Pull the fix
   # (see How to apply column above for the specific component)

   # 2. Test locally if possible
   docker exec wl_drupal drush status   # Drupal bootstrap
   docker compose ps                     # all containers healthy

   # 3. Deploy to staging first (if change touches application code)
   make refresh-staging   # clone prod DB → staging
   # make onprem-staging  # (not yet automated; apply same make onprem manually)

   # 4. Deploy to prod
   make onprem   # or make vps, depending on component

   # 5. Verify
   docker compose -f ~/nas_docker/docker-compose.yml ps
   docker exec wl_drupal drush watchdog:show --severity=error --count=20
   ```

4. **Record** — commit message must include the CVE/SA identifier (e.g. `security: drupal/core 11.3.6 → 11.3.8 (SA-CORE-2026-001/002/003)`). No separate changelog file needed; git log is the audit trail.

---

## Commands Reference

### Drupal security check
```bash
# Security advisories for installed packages
docker exec wl_drupal drush pm:security

# All installed module versions
docker exec wl_drupal drush pm:list --status=enabled --format=table
```

### Composer (Drupal/webcms)
```bash
# Full CVE report
docker run --rm \
  -v ~/Repositories/webcms:/app -w /app \
  -e COMPOSER_HOME=/tmp/composer-home \
  --user "$(id -u):$(id -g)" \
  composer:2 audit

# What's outdated (direct deps only)
docker run --rm \
  -v ~/Repositories/webcms:/app -w /app \
  -e COMPOSER_HOME=/tmp/composer-home \
  --user "$(id -u):$(id -g)" \
  composer:2 outdated --direct

# Update a specific package
docker run --rm \
  -v ~/Repositories/webcms:/app -w /app \
  -e COMPOSER_HOME=/tmp/composer-home \
  --user "$(id -u):$(id -g)" \
  composer:2 update drupal/core-recommended --with-all-dependencies --ignore-platform-reqs
```

### npm (Next.js / UI)
```bash
cd ~/Repositories/ui

# CVE report
npm audit

# What's outdated
npm outdated

# Fix audit findings (auto-patch within semver range)
npm audit fix

# Fix a specific package
npm install <package>@<fixed-version>
```

### Docker base images
```bash
# Show currently running image tags
docker compose -f ~/nas_docker/docker-compose.yml images

# Pull latest tags to compare (dry run — don't apply yet)
docker pull postgres:16
docker pull redis:7-alpine

# After updating tags in docker-compose.yml:
make onprem
```

### Ansible / Python
```bash
# Python package audit (requires pip-audit)
pip-audit

# Ansible collection versions
ansible-galaxy collection list

# Upgrade Ansible collections
ansible-galaxy collection install community.general community.sops --upgrade
```

### Tailscale
```bash
# On-prem (macOS)
brew list --versions tailscale
brew upgrade tailscale

# VPS (Debian/Ubuntu)
ssh root@<vps> "apt-get update && apt-get install --only-upgrade tailscale && tailscale version"
```

---

## Known Upstream Blocks

| Package | Installed | Required fix | Block reason | Action |
|---|---|---|---|---|
| `webonyx/graphql-php` | v14.11.10 | ≥ 15.31.5 (CVE-2026-40476) | `drupal/graphql 4.13.0` constrains to `^14.x`; no stable 5.x | Monitor drupal/graphql releases; update when 5.x stable ships |

---

## Tracking

All upgrade decisions are recorded in git commit messages on `master` in the relevant repo:
- Application-level upgrades (Drupal, Next.js) → `~/Repositories/webcms` or `~/Repositories/ui`
- Infrastructure upgrades (Docker images, Ansible, Caddy) → `~/Repositories/infra`

Commit message format for security updates: `security: <component> <old> → <new> (<SA/CVE>)`

No separate changelog file. `git log --grep="security:" --oneline` serves as the audit trail.
