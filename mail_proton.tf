# -------------------------
# Proton Mail — MX
# -------------------------
resource "njalla_record_mx" "mx_primary" {
  domain   = "wilkesliberty.com"
  name     = "@"
  content    = "mail.protonmail.ch."
  priority = 10
  ttl      = 3600
}

resource "njalla_record_mx" "mx_secondary" {
  domain   = "wilkesliberty.com"
  name     = "@"
  content    = "mailsec.protonmail.ch."
  priority = 20
  ttl      = 3600
}

# -------------------------
# Proton Mail — Verification (TXT)
# Domain verification record required by Proton Mail
# -------------------------
resource "njalla_record_txt" "proton_verification" {
  domain = "wilkesliberty.com"
  name   = "@"
  content = var.proton_verification_token
  ttl    = 10800  # 3h as shown in Njalla
}

# -------------------------
# Proton Mail — SPF (TXT)
# Ensure only ONE SPF record at apex.
# -------------------------
resource "njalla_record_txt" "spf" {
  domain = "wilkesliberty.com"
  name   = "@"
  content = "v=spf1 include:_spf.protonmail.ch ~all"
  ttl    = 3600
}

# -------------------------
# Proton Mail — DKIM (3 CNAMEs)
# Paste exact targets from Proton dashboard into terraform.tfvars
# -------------------------
resource "njalla_record" "dkim1" {
  domain = "wilkesliberty.com"
  type   = "CNAME"
  name   = "protonmail._domainkey"
  value  = var.proton_dkim1_target
  ttl    = 3600
}

resource "njalla_record" "dkim2" {
  domain = "wilkesliberty.com"
  type   = "CNAME"
  name   = "protonmail2._domainkey"
  value  = var.proton_dkim2_target
  ttl    = 3600
}

resource "njalla_record" "dkim3" {
  domain = "wilkesliberty.com"
  type   = "CNAME"
  name   = "protonmail3._domainkey"
  value  = var.proton_dkim3_target
  ttl    = 3600
}

# -------------------------
# Proton Mail — DMARC (TXT)
# Start with p=quarantine; use p=none to monitor first if you prefer.
# -------------------------
resource "njalla_record_txt" "dmarc" {
  domain = "wilkesliberty.com"
  name   = "_dmarc"
  content = "v=DMARC1; p=quarantine; adkim=s; aspf=s; rua=mailto:dmarc@wilkesliberty.com; ruf=mailto:dmarc@wilkesliberty.com"
  ttl    = 3600
}
