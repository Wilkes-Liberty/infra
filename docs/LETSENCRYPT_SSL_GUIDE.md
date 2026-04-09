# Let's Encrypt SSL Certificate Management for Wilkes Liberty

SSL/TLS certificate management for the two-host infrastructure: cloud VPS (public ingress) and on-prem server (internal services via Tailscale).

## Certificate Strategy

### Single Wildcard Certificate (Current Approach)

We use **one wildcard certificate** obtained via certbot DNS-01 challenge, covering all subdomains:

| Certificate | Domains | Where Used |
|-------------|---------|------------|
| `wilkesliberty_wildcard` | `wilkesliberty.com`, `*.wilkesliberty.com` | VPS Caddy (public vhosts) |

This single cert covers `www`, `api`, `auth`, `search`, and any future subdomains. Caddy is configured with `auto_https off` and reads the certbot-managed certificate directly.

> **Internal services** (`*.int.wilkesliberty.com`) are served by the internal Caddy instance on the on-prem server, which also uses this wildcard cert (deployed to on-prem via Ansible).

---

## Quick Start: Obtain Wildcard Certificate (on Cloud VPS)

```bash
certbot certonly \
  --manual \
  --preferred-challenges dns \
  -d "wilkesliberty.com" \
  -d "*.wilkesliberty.com"
```

certbot will prompt you to add a `_acme-challenge` TXT record. Add it via your DNS provider's web UI, wait ~60 seconds for DNS propagation, then press Enter to continue.

### Verify Certificate

```bash
ls /etc/letsencrypt/live/wilkesliberty.com/
openssl x509 -in /etc/letsencrypt/live/wilkesliberty.com/fullchain.pem -noout -dates
```

### Certificate File Locations

```bash
/etc/letsencrypt/live/wilkesliberty.com/fullchain.pem   # Certificate + chain
/etc/letsencrypt/live/wilkesliberty.com/privkey.pem     # Private key
/etc/letsencrypt/live/wilkesliberty.com/cert.pem        # Certificate only
/etc/letsencrypt/live/wilkesliberty.com/chain.pem       # Intermediate chain
```

---

## Caddy TLS Configuration

Caddy on the VPS uses `auto_https off` and references the certbot cert directly:

```caddyfile
{
    auto_https off
    tls {
        protocols tls1.2 tls1.3
    }
}

www.wilkesliberty.com {
    tls /etc/letsencrypt/live/wilkesliberty.com/fullchain.pem \
        /etc/letsencrypt/live/wilkesliberty.com/privkey.pem
    # ... routes
}
```

---

## Automatic Renewal

### Renewal via certbot

```bash
# Renew all certificates
certbot renew

# Dry run (test renewal without making changes)
certbot renew --dry-run

# Force renewal
certbot renew --force-renewal
```

After renewal, reload Caddy to pick up the new cert:

```bash
caddy reload
# Or
systemctl reload caddy
```

### Set Up Automatic Renewal (cron or systemd)

```bash
# Add to crontab (runs daily at 2:30 AM)
echo "30 2 * * * root certbot renew --quiet && systemctl reload caddy" >> /etc/cron.d/certbot-renew
```

Or use the systemd timer that certbot typically installs automatically:

```bash
systemctl status certbot.timer
systemctl enable certbot.timer
```

### Renewal Logs

```bash
tail -f /var/log/letsencrypt/letsencrypt.log
journalctl -u certbot -f
```

---

## DNS-01 Challenge Reference

The wildcard cert (`*.wilkesliberty.com`) requires a DNS-01 challenge — HTTP-01 cannot issue wildcards.

**Manual process** (what we use):
1. Run `certbot certonly --manual --preferred-challenges dns -d "wilkesliberty.com" -d "*.wilkesliberty.com"`
2. certbot provides a TXT record value
3. Add `_acme-challenge.wilkesliberty.com TXT "<value>"` in the DNS provider web UI
4. Verify propagation: `dig TXT _acme-challenge.wilkesliberty.com @8.8.8.8`
5. Press Enter in certbot to complete

**Automated renewal** can be set up with the certbot DNS plugin or by scripting the DNS provider API. For now, renewals are manual (certs are valid 90 days; renew before 30 days remaining).

---

## Monitoring Certificate Expiry

### Check Expiry Date

```bash
openssl x509 -in /etc/letsencrypt/live/wilkesliberty.com/fullchain.pem -noout -enddate
# or
certbot certificates
```

### Prometheus Alert (from alerts.yml)

```yaml
- alert: CertificateExpiringSoon
  expr: (ssl_certificate_expiry_seconds - time()) / 86400 < 30
  labels:
    severity: warning
  annotations:
    summary: "SSL certificate expiring in {{ $value | printf \"%.0f\" }} days"
```

### Monitor Certificate Transparency

Track issued certificates at: https://crt.sh/?q=wilkesliberty.com

This lets you detect any unauthorized certificate issuances (complements CAA records).

---

## Troubleshooting

### DNS-01 Challenge Failure

```bash
# Check DNS propagation
dig TXT _acme-challenge.wilkesliberty.com @8.8.8.8
dig TXT _acme-challenge.wilkesliberty.com @1.1.1.1

# If not propagated, wait 30–60 seconds and retry
# Njalla typically propagates in under 30 seconds
```

### Caddy Not Picking Up Renewed Cert

```bash
# Reload Caddy after renewal
systemctl reload caddy
journalctl -u caddy -n 50

# Verify Caddy is reading the correct cert
echo | openssl s_client -servername www.wilkesliberty.com -connect localhost:443 2>/dev/null \
  | openssl x509 -noout -dates
```

### Certificate Rate Limits

Let's Encrypt allows 5 duplicate certificates per week. If you hit the limit:
- Use `--staging` flag to test: `certbot certonly --staging ...`
- Wait until the weekly window resets
- Staging certs are not trusted by browsers but work for testing

### Permission Issues

```bash
chmod 644 /etc/letsencrypt/live/wilkesliberty.com/fullchain.pem
chmod 600 /etc/letsencrypt/live/wilkesliberty.com/privkey.pem
# Add caddy user to certificate access group if needed
usermod -a -G ssl-cert caddy
```

### Emergency Self-Signed Certificate

```bash
# Temporary self-signed cert (not trusted by browsers — emergency use only)
openssl req -x509 -nodes -days 7 -newkey rsa:2048 \
    -keyout /etc/ssl/private/emergency.key \
    -out /etc/ssl/certs/emergency.crt \
    -subj "/CN=wilkesliberty.com"
```

---

## Security Notes

- **CAA records**: Manually added in the DNS provider web UI — only `letsencrypt.org` can issue certificates for `wilkesliberty.com`. Run `dig CAA wilkesliberty.com` to verify.
- **Private key permissions**: Must be `600`, owned by root (or the user running Caddy)
- **Key storage**: Never commit private keys to git. The cert is only on the VPS filesystem.
- **API token**: The DNS provider API token is in `terraform_secrets.yml` (SOPS-encrypted). DNS-01 manual renewal doesn't require the token at renewal time — only when running certbot interactively.

---

## Related Documentation

- `DNS_RECORDS.md` — DNS record reference including CAA records
- `DEPLOYMENT_CHECKLIST.md` — Full deployment guide (Section 6: Let's Encrypt)
- `docs/DNS_AND_SSL_SETUP.md` — DNS and SSL setup walkthrough
