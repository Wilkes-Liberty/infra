# =============================================
# WilkesLiberty DNS Records - Single VPS Architecture
# =============================================
# All public services proxy through single Njalla VPS
# VPS IP configured in terraform.tfvars
# =============================================

# -------------------------
# Apex (root domain)
# -------------------------

resource "njalla_record_a" "apex" {
  domain  = var.domain_name
  name    = "@"
  content = var.vps_ipv4
  ttl     = 3600
}

# Optional: IPv6 support
resource "njalla_record_aaaa" "apex" {
  count   = var.vps_ipv6 != "" ? 1 : 0
  domain  = var.domain_name
  name    = "@"
  content = var.vps_ipv6
  ttl     = 3600
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
# NOTE: Njalla provider v0.10.0 does not support CAA records
# These must be managed manually in Njalla web UI if desired
# CAA records are optional - they restrict which CAs can issue certificates

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
# Private services (NO DNS, Tailscale-only):
# - PostgreSQL (100.x.x.x:5432)
# - Redis (100.x.x.x:6379)
# - Solr (100.x.x.x:8983)
# - Prometheus (100.x.x.x:9090)
# =============================================
