# =============================================
# Miscellaneous DNS Records
# =============================================
# Non-mail TXT records, verifications, etc.
# =============================================

# -------------------------
# Domain Ownership Verification
# -------------------------
# This record is used by external services (Google, etc.) to verify domain ownership
# Keep this value - it was already configured in Njalla
resource "njalla_record_txt" "domain_verification" {
  domain  = var.domain_name
  name    = "@"
  content = "domain-verification=8c1af8eb0ad4599c1ab2c76d7d3210a2df9cfe3fac1a8b8afc2874e0b2cbd03b"
  ttl     = 3600
}

# -------------------------
# ACME Challenge Records
# -------------------------
# Note: Let's Encrypt DNS-01 challenge records (_acme-challenge.*)
# are temporary and auto-managed by certbot/ACME clients.
# DO NOT add them to Terraform - they change frequently.
# Current ACME records in Njalla are safe to leave as-is.
# -------------------------
