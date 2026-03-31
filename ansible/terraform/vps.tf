# =============================================
# Njalla VPS - Tailscale Inner Mesh + Proton VPN Outer Layer
# =============================================

resource "njalla_firewall_rule" "tailscale_internal" {
  for_each = toset(["8080", "8081", "8123", "9090", "3000"])  # Drupal, Keycloak, ClickHouse, Prometheus, Grafana

  protocol    = "tcp"
  port        = each.value
  direction   = "in"
  action      = "accept"
  description = "Allow Tailscale mesh traffic (inner private network)"

  # Tailscale subnet (100.64.0.0/10) + your on-prem server Tailscale IP range
  source      = "100.64.0.0/10"
}

resource "njalla_firewall_rule" "ssh_tailscale_only" {
  protocol    = "tcp"
  port        = "22"
  direction   = "in"
  action      = "accept"
  description = "SSH only from Tailscale (no public exposure)"

  source      = "100.64.0.0/10"
}

# Deny all other inbound traffic (zero public exposure)
resource "njalla_firewall_rule" "default_deny" {
  protocol    = "all"
  direction   = "in"
  action      = "drop"
  description = "Default deny - everything except Tailscale"
  source      = "0.0.0.0/0"
}

# Output the Tailscale IP of the on-prem server for easy reference
output "onprem_tailscale_ip" {
  value       = "100.82.73.91"   # Your current Tailscale IP from earlier
  description = "Use this in Caddy reverse_proxy on the Njalla VPS"
}