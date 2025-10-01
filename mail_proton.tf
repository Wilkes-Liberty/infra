# -------------------------
# Proton Mail — MX
# -------------------------
resource "njalla_record" "mx_primary" {
  domain   = "wilkesliberty.com"
  type     = "MX"
  name     = "@"
  value    = "mail.protonmail.ch."
  priority = 10
  ttl      = 3600
}

resource "njalla_record" "mx_secondary" {
  domain   = "wilkesliberty.com"
  type     = "MX"
  name     = "@"
  value    = "mailsec.protonmail.ch."
  priority = 20
  ttl      = 3600
}

# -------------------------
# Proton Mail — SPF (TXT)
# Ensure only ONE SPF record at apex.
# -------------------------
resource "njalla_record" "spf" {
  domain = "wilkesliberty.com"
  type   = "TXT"
  name   = "@"
  value  = "v=spf1 include:_spf.protonmail.ch ~all"
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
resource "njalla_record" "dmarc" {
  domain = "wilkesliberty.com"
  type   = "TXT"
  name   = "_dmarc"
  value  = "v=DMARC1; p=quarantine; adkim=s; aspf=s; rua=mailto:dmarc@wilkesliberty.com; ruf=mailto:dmarc@wilkesliberty.com"
  ttl    = 3600
}
