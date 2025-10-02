# -------------------------
# Public service hostnames
# -------------------------

resource "njalla_record_cname" "www" {
  domain = "wilkesliberty.com"
  name   = "www"
  content = "cache1.prod.wilkesliberty.com."
  ttl    = 3600
}

resource "njalla_record_cname" "api" {
  domain = "wilkesliberty.com"
  name   = "api"
  content = "cache1.prod.wilkesliberty.com."
  ttl    = 3600
}

resource "njalla_record_cname" "stats" {
  domain = "wilkesliberty.com"
  name   = "stats"
  content = "analytics1.prod.wilkesliberty.com."
  ttl    = 3600
}

resource "njalla_record_cname" "sso" {
  domain = "wilkesliberty.com"
  name   = "sso"
  content = "sso1.prod.wilkesliberty.com."
  ttl    = 3600
}

# -------------------------
# Apex A + AAAA
# -------------------------

resource "njalla_record_a" "apex_a" {
  domain = "wilkesliberty.com"
  name   = "@"
  content  = "80.78.30.4"  # cache1 IPv4
  ttl    = 3600
}
resource "njalla_record_aaaa" "apex_aaaa" {
  domain = "wilkesliberty.com"
  name   = "@"
  content = "2a0a:3840:8078:30::504e:1e04:1337"  # cache1 IPv6
  ttl    = 3600
}

# -------------------------
# Per-node A + AAAA
# -------------------------

# app1
resource "njalla_record_a" "app1_a" {
  domain = "wilkesliberty.com"
  name   = "app1.prod"
  content = "80.78.28.105"
  ttl    = 3600
}
resource "njalla_record_aaaa" "app1_aaaa" {
  domain = "wilkesliberty.com"
  name   = "app1.prod"
  content = "2a0a:3840:8078:28::504e:1c69:1337"
  ttl    = 3600
}

# db1
resource "njalla_record_a" "db1_a" {
  domain = "wilkesliberty.com"
  name   = "db1.prod"
  content = "80.78.28.129"
  ttl    = 3600
}
resource "njalla_record_aaaa" "db1_aaaa" {
  domain = "wilkesliberty.com"
  name   = "db1.prod"
  content = "2a0a:3840:8078:28::504e:1c81:1337"
  ttl    = 3600
}

# search1
resource "njalla_record_a" "search1_a" {
  domain = "wilkesliberty.com"
  name   = "search1.prod"
  content = "80.78.28.140"
  ttl    = 3600
}
resource "njalla_record_aaaa" "search1_aaaa" {
  domain = "wilkesliberty.com"
  name   = "search1.prod"
  content = "2a0a:3840:8078:28::504e:1c8c:1337"
  ttl    = 3600
}

# analytics1
resource "njalla_record_a" "analytics1_a" {
  domain = "wilkesliberty.com"
  name   = "analytics1.prod"
  content = "80.78.28.148"
  ttl    = 3600
}
resource "njalla_record_aaaa" "analytics1_aaaa" {
  domain = "wilkesliberty.com"
  name   = "analytics1.prod"
  content = "2a0a:3840:8078:28::504e:1c94:1337"
  ttl    = 3600
}

# sso1
resource "njalla_record_a" "sso1_a" {
  domain = "wilkesliberty.com"
  name   = "sso1.prod"
  content = "80.78.28.217"
  ttl    = 3600
}
resource "njalla_record_aaaa" "sso1_aaaa" {
  domain = "wilkesliberty.com"
  name   = "sso1.prod"
  content = "2a0a:3840:8078:28::504e:1cd9:1337"
  ttl    = 3600
}

# cache1
resource "njalla_record_a" "cache1_a" {
  domain = "wilkesliberty.com"
  name   = "cache1.prod"
  content = "80.78.30.4"
  ttl    = 3600
}
resource "njalla_record_aaaa" "cache1_aaaa" {
  domain = "wilkesliberty.com"
  name   = "cache1.prod"
  content = "2a0a:3840:8078:30::504e:1e04:1337"
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
#   content = "0 issue \"letsencrypt.org\""
#   ttl    = 3600
# }
# resource "njalla_record" "caa_iodef" {
#   domain = "wilkesliberty.com"
#   type   = "CAA"
#   name   = "@"
#   content = "0 iodef \"mailto:security@wilkesliberty.com\""
#   ttl    = 3600
# }
