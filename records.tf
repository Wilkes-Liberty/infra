# -------------------------
# Public service hostnames
# -------------------------

resource "njalla_record" "www" {
  domain = "wilkesliberty.com"
  type   = "CNAME"
  name   = "www"
  value  = "cache1.prod.wilkesliberty.com."
  ttl    = 3600
}

resource "njalla_record" "api" {
  domain = "wilkesliberty.com"
  type   = "CNAME"
  name   = "api"
  value  = "cache1.prod.wilkesliberty.com."
  ttl    = 3600
}

resource "njalla_record" "stats" {
  domain = "wilkesliberty.com"
  type   = "CNAME"
  name   = "stats"
  value  = "analytics1.prod.wilkesliberty.com."
  ttl    = 3600
}

resource "njalla_record" "sso" {
  domain = "wilkesliberty.com"
  type   = "CNAME"
  name   = "sso"
  value  = "sso1.prod.wilkesliberty.com."
  ttl    = 3600
}

# -------------------------
# Apex A + AAAA
# -------------------------

resource "njalla_record" "apex_a" {
  domain = "wilkesliberty.com"
  type   = "A"
  name   = "@"
  value  = "80.78.30.4"  # cache1 IPv4
  ttl    = 3600
}
resource "njalla_record" "apex_aaaa" {
  domain = "wilkesliberty.com"
  type   = "AAAA"
  name   = "@"
  value  = "2a0a:3840:8078:30::504e:1e04:1337"  # cache1 IPv6
  ttl    = 3600
}

# -------------------------
# Per-node A + AAAA
# -------------------------

# app1
resource "njalla_record" "app1_a" {
  domain = "wilkesliberty.com"
  type   = "A"
  name   = "app1.prod"
  value  = "80.78.28.105"
  ttl    = 3600
}
resource "njalla_record" "app1_aaaa" {
  domain = "wilkesliberty.com"
  type   = "AAAA"
  name   = "app1.prod"
  value  = "2a0a:3840:8078:28::504e:1c69:1337"
  ttl    = 3600
}

# db1
resource "njalla_record" "db1_a" {
  domain = "wilkesliberty.com"
  type   = "A"
  name   = "db1.prod"
  value  = "80.78.28.129"
  ttl    = 3600
}
resource "njalla_record" "db1_aaaa" {
  domain = "wilkesliberty.com"
  type   = "AAAA"
  name   = "db1.prod"
  value  = "2a0a:3840:8078:28::504e:1c81:1337"
  ttl    = 3600
}

# search1
resource "njalla_record" "search1_a" {
  domain = "wilkesliberty.com"
  type   = "A"
  name   = "search1.prod"
  value  = "80.78.28.140"
  ttl    = 3600
}
resource "njalla_record" "search1_aaaa" {
  domain = "wilkesliberty.com"
  type   = "AAAA"
  name   = "search1.prod"
  value  = "2a0a:3840:8078:28::504e:1c8c:1337"
  ttl    = 3600
}

# analytics1
resource "njalla_record" "analytics1_a" {
  domain = "wilkesliberty.com"
  type   = "A"
  name   = "analytics1.prod"
  value  = "80.78.28.148"
  ttl    = 3600
}
resource "njalla_record" "analytics1_aaaa" {
  domain = "wilkesliberty.com"
  type   = "AAAA"
  name   = "analytics1.prod"
  value  = "2a0a:3840:8078:28::504e:1c94:1337"
  ttl    = 3600
}

# sso1
resource "njalla_record" "sso1_a" {
  domain = "wilkesliberty.com"
  type   = "A"
  name   = "sso1.prod"
  value  = "80.78.28.217"
  ttl    = 3600
}
resource "njalla_record" "sso1_aaaa" {
  domain = "wilkesliberty.com"
  type   = "AAAA"
  name   = "sso1.prod"
  value  = "2a0a:3840:8078:28::504e:1cd9:1337"
  ttl    = 3600
}

# cache1
resource "njalla_record" "cache1_a" {
  domain = "wilkesliberty.com"
  type   = "A"
  name   = "cache1.prod"
  value  = "80.78.30.4"
  ttl    = 3600
}
resource "njalla_record" "cache1_aaaa" {
  domain = "wilkesliberty.com"
  type   = "AAAA"
  name   = "cache1.prod"
  value  = "2a0a:3840:8078:30::504e:1e04:1337"
  ttl    = 3600
}

# -------------------------
# OPTIONAL: CAA (cert authority) best-practice
# Allow Let's Encrypt (and only that) to issue certs for your domain.
# Uncomment if you want to enforce CA policy.
# -------------------------
# resource "njalla_record" "caa_issue" {
#   domain = "wilkesliberty.com"
#   type   = "CAA"
#   name   = "@"
#   value  = "0 issue \"letsencrypt.org\""
#   ttl    = 3600
# }
# resource "njalla_record" "caa_iodef" {
#   domain = "wilkesliberty.com"
#   type   = "CAA"
#   name   = "@"
#   value  = "0 iodef \"mailto:security@wilkesliberty.com\""
#   ttl    = 3600
# }
