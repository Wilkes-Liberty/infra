# Project outputs
output "environment" {
  description = "Current environment"
  value       = var.environment
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

# Network outputs
output "internal_network" {
  description = "Internal network CIDR"
  value       = var.internal_cidr
}

output "internal_domain" {
  description = "Internal domain name"
  value       = var.internal_domain
}

# Host configuration (matching your Ansible inventory)
output "host_ips" {
  description = "Internal host IP addresses"
  value = {
    app       = "10.10.0.2"
    db        = "10.10.0.3"
    search    = "10.10.0.4"
    analytics = "10.10.0.7"
    sso       = "10.10.0.8"
    cache     = "10.10.0.9"
  }
}

output "host_fqdns" {
  description = "Internal host FQDNs"
  value = {
    app       = "app.${var.internal_domain}"
    db        = "db.${var.internal_domain}"
    search    = "search.${var.internal_domain}"
    analytics = "analytics.${var.internal_domain}"
    sso       = "sso.${var.internal_domain}"
    cache     = "cache.${var.internal_domain}"
  }
}