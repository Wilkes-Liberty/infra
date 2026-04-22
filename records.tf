# =============================================
# WilkesLiberty DNS Records - Single VPS Architecture
# =============================================
# All public services proxy through single Njalla VPS
# VPS IP configured in terraform.tfvars
# =============================================
# NOTE: Existing DNS records should be imported rather than recreated to avoid downtime.
# Use the import_existing_records.sh script to generate import commands.

# -------------------------
# Apex (root domain)
# -------------------------

resource "njalla_record_a" "apex" {
  domain  = var.domain_name
  name    = "@"
  content = var.vps_ipv4
  ttl     = 3600

  lifecycle {
    prevent_destroy = true
  }
}

# Optional: IPv6 support
# WARNING: These AAAA resources use count, so Terraform addresses them as njalla_record_aaaa.<name>[0].
# If vps_ipv6 is later set to "", Terraform will attempt to destroy the instance and
# prevent_destroy will block it with an error rather than silently skipping. You must
# explicitly remove the lifecycle block before unsetting vps_ipv6 to avoid a plan failure.
resource "njalla_record_aaaa" "apex" {
  count   = var.vps_ipv6 != "" ? 1 : 0
  domain  = var.domain_name
  name    = "@"
  content = var.vps_ipv6
  ttl     = 3600

  lifecycle {
    prevent_destroy = true
  }
}

# -------------------------
# Public service subdomains
# -------------------------

# www - Next.js frontend (runs on VPS)
resource "njalla_record_a" "www" {
  domain  = var.domain_name
  name    = "www"
  content = var.vps_ipv4
  ttl     = 3600

  lifecycle {
    prevent_destroy = true
  }
}

# WARNING: count + prevent_destroy interaction — see note above on njalla_record_aaaa.apex
resource "njalla_record_aaaa" "www" {
  count   = var.vps_ipv6 != "" ? 1 : 0
  domain  = var.domain_name
  name    = "www"
  content = var.vps_ipv6
  ttl     = 3600

  lifecycle {
    prevent_destroy = true
  }
}

# api - Drupal GraphQL backend (proxied to on-prem server via Tailscale)
resource "njalla_record_a" "api" {
  domain  = var.domain_name
  name    = "api"
  content = var.vps_ipv4
  ttl     = 3600

  lifecycle {
    prevent_destroy = true
  }
}

# WARNING: count + prevent_destroy interaction — see note above on njalla_record_aaaa.apex
resource "njalla_record_aaaa" "api" {
  count   = var.vps_ipv6 != "" ? 1 : 0
  domain  = var.domain_name
  name    = "api"
  content = var.vps_ipv6
  ttl     = 3600

  lifecycle {
    prevent_destroy = true
  }
}

# auth - Keycloak SSO (proxied to on-prem server via Tailscale)
resource "njalla_record_a" "auth" {
  domain  = var.domain_name
  name    = "auth"
  content = var.vps_ipv4
  ttl     = 3600

  lifecycle {
    prevent_destroy = true
  }
}

# WARNING: count + prevent_destroy interaction — see note above on njalla_record_aaaa.apex
resource "njalla_record_aaaa" "auth" {
  count   = var.vps_ipv6 != "" ? 1 : 0
  domain  = var.domain_name
  name    = "auth"
  content = var.vps_ipv6
  ttl     = 3600

  lifecycle {
    prevent_destroy = true
  }
}

# network - Tailscale admin console shortcut
# Points to VPS (same as all other public subdomains); Caddy holds a valid TLS cert
# and issues a 301 to login.tailscale.com. A CNAME direct to login.tailscale.com
# would cause an SNI mismatch/ERR_SSL_PROTOCOL_ERROR at Tailscale's edge.
resource "njalla_record_a" "network" {
  domain  = var.domain_name
  name    = "network"
  content = var.vps_ipv4
  ttl     = 3600
}

# WARNING: count + prevent_destroy interaction — see note above on njalla_record_aaaa.apex
resource "njalla_record_aaaa" "network" {
  count   = var.vps_ipv6 != "" ? 1 : 0
  domain  = var.domain_name
  name    = "network"
  content = var.vps_ipv6
  ttl     = 3600
}

# analytics - Grafana monitoring (proxied to on-prem server via Tailscale)
# Uncomment when ready to expose publicly
# resource "njalla_record_a" "analytics" {
#   domain  = var.domain_name
#   name    = "analytics"
#   content = var.vps_ipv4
#   ttl     = 3600
# }
#
# resource "njalla_record_aaaa" "analytics" {
#   count   = var.vps_ipv6 != "" ? 1 : 0
#   domain  = var.domain_name
#   name    = "analytics"
#   content = var.vps_ipv6
#   ttl     = 3600
# }

# -------------------------
# Security: CAA records
# -------------------------
# CAA records restrict which Certificate Authorities are permitted to issue
# certificates for wilkesliberty.com. Without them, any CA can issue certs for
# your domain, enabling phishing/MITM via rogue certificates.
#
# STATUS: Njalla provider v0.10.0 does NOT support CAA records via Terraform.
# ACTION REQUIRED: Add these records manually in the Njalla web UI:
#   https://njal.la/ → wilkesliberty.com → Add record → Type: CAA
#
#   Record 1 — restrict issuance to Let's Encrypt only:
#     Name: @    TTL: 3600    Value: 0 issue "letsencrypt.org"
#
#   Record 2 — restrict wildcard issuance to Let's Encrypt only:
#     Name: @    TTL: 3600    Value: 0 issuewild "letsencrypt.org"
#
#   Record 3 — report policy violations to your security email:
#     Name: @    TTL: 3600    Value: 0 iodef "mailto:security@wilkesliberty.com"
#
# Verify after creation:
#   dig CAA wilkesliberty.com
#
# Monitor for unauthorized cert issuance via Certificate Transparency logs:
#   https://crt.sh/?q=wilkesliberty.com

# Terraform placeholders (uncomment if/when Njalla provider adds CAA support):
# resource "njalla_record_caa" "caa_issue" {
#   domain  = var.domain_name
#   name    = "@"
#   content = "0 issue \"letsencrypt.org\""
#   ttl     = 3600
# }
#
# resource "njalla_record_caa" "caa_issuewild" {
#   domain  = var.domain_name
#   name    = "@"
#   content = "0 issuewild \"letsencrypt.org\""
#   ttl     = 3600
# }
#
# resource "njalla_record_caa" "caa_iodef" {
#   domain  = var.domain_name
#   name    = "@"
#   content = "0 iodef \"mailto:security@wilkesliberty.com\""
#   ttl     = 3600
# }

# =============================================
# DNS Architecture Notes:
# =============================================
# - All public DNS points to single Njalla VPS
# - VPS runs Caddy reverse proxy with automatic SSL
# - Backend services on on-prem server (private, Tailscale-only)
# - IPv6 optional (enable by setting vps_ipv6 variable)
# - CAA records enforce Let's Encrypt certificates only
# - TTL: 1 hour (3600s) for all records
#
# Public subdomains (A/AAAA → VPS → proxied to on-prem via Tailscale):
# - www        → Next.js frontend (runs on VPS)
# - api        → Drupal CMS / GraphQL API (webcms repo, on-prem:8080)
# - auth       → Keycloak SSO (on-prem:8081)
# NOTE: search.wilkesliberty.com removed — Solr is admin-only, use search.int.wilkesliberty.com over Tailscale
#
# Special subdomains:
# - network    → A/AAAA to VPS (Caddy 301s to login.tailscale.com — proper TLS, no SNI mismatch)
#
# Internal-only subdomains (CoreDNS / Tailscale Split DNS — not in public DNS):
# - *.int.wilkesliberty.com → Tailscale-only, served by on-prem CoreDNS
#
# Private services (no public DNS, Tailscale-only):
# - PostgreSQL (on-prem:5432)
# - Redis (on-prem:6379)
# - metrics.int (Prometheus UI, on-prem:9090, admin-CIDR restricted)
# =============================================
