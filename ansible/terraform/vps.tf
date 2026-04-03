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

# The on-prem Tailscale IP is stored in SOPS-encrypted network_secrets.yml
# as onprem_tailscale_ip. It is consumed by Ansible (Caddyfile.production.j2),
# not managed here in Terraform.