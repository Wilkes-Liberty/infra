# Phase B: Tailscale OIDC Design

Design notes for integrating Keycloak as the OIDC provider for Tailscale authentication (Phase B of the W&L infra buildout).

## Goal

Replace Tailscale's Google-SSO login with Keycloak OIDC so that:
- Jeremy (`jeremy` / `wl-operator`) gets full Tailscale access
- Aleksandra (`aleksandra` / `wl-business-continuity`) gets read-only Tailscale access
- ACL decisions can be driven by the `groups` claim from Keycloak

## Current State (Phase A complete)

The `tailscale` OIDC client is configured in Keycloak (`setup-realm.sh`) but not yet activated. Tailscale auth still uses the existing method. Phase B activates the OIDC integration.

## Network Constraints — Russia / DPI Considerations

Aleksandra will sometimes connect from Russia. Russia operates deep packet inspection (DPI) that can interfere with WireGuard and Tailscale.

### WireGuard UDP 41641

Tailscale uses WireGuard over UDP port 41641 by default. Russia's TSPU (Технические средства противодействия угрозам) system has been observed blocking or throttling UDP traffic patterns consistent with WireGuard.

**Mitigations already in place:**
- Tailscale's DERP relay network provides TCP-based fallback when direct WireGuard UDP is blocked
- DERP relays are geographically distributed; Aleksandra's client will automatically select the nearest available relay

### DERP Relay Behavior

When UDP 41641 is blocked:
1. Tailscale falls back to DERP (Designated Encrypted Relay for Packets)
2. DERP uses HTTPS (TCP/443) — harder to block without breaking all HTTPS
3. Performance degrades (relay adds latency) but connectivity is maintained

The nearest DERP relays to Russia:
- `fra` (Frankfurt) — typical choice for western Russia
- `hel` (Helsinki) — lowest latency from St. Petersburg / Moscow

No configuration change is needed — DERP fallback is automatic.

### Exit Node Consideration

For cases where the DPI blocks even DERP, or where Aleksandra needs a non-Russian egress IP:

**Exit node candidates:**
- The on-prem server can be configured as a Tailscale exit node (routes all traffic through the home office's AT&T connection)
- A dedicated VPS in Finland or Estonia would provide lower-latency European egress

**Current decision:** No exit node configured in Phase B. Aleksandra's use case is administrative access (Tailscale network visibility), not general internet egress. DERP fallback is sufficient for the Phase B scope.

**Revisit if:** Aleksandra reports consistent connectivity failures from Russia, or if the use case expands to require internet egress through a clean IP.

### Protocol Obfuscation

Tailscale does not natively support traffic obfuscation (unlike tools like obfs4 or Shadowsocks). If DERP is also blocked:

1. **Manual DERP relay**: self-hosted DERP server in a jurisdiction with better connectivity to Russia (e.g., a VPS in Finland). Not planned for Phase B — operational complexity is high.
2. **Tailscale over HTTPS proxy**: some deployments route Tailscale through an HTTPS proxy to avoid fingerprinting. Not supported natively in Tailscale as of 2026.
3. **Alternative**: if Tailscale is fully blocked from Russia, Aleksandra's access falls back to the Njalla console for emergency VPS access only (see `BREAK_GLASS_ACCESS.md`).

## Keycloak OIDC Client (`tailscale`)

The `tailscale` client in the `wilkesliberty` realm is configured as a public client with PKCE:

```
Client ID:     tailscale
Client type:   public (no secret — Tailscale doesn't support confidential OIDC)
Redirect URI:  https://login.tailscale.com/a/oidc/callback
Scopes:        openid, profile, email, groups
```

The `groups` claim carries `/operators` or `/business-continuity`, which maps to Tailscale ACL tags.

## Tailscale ACL Design (Phase B target)

```json
{
  "tagOwners": {
    "tag:operator": ["autogroup:admin"],
    "tag:business-continuity": ["autogroup:admin"]
  },
  "grants": [
    {
      "src": ["tag:operator"],
      "dst": ["*:*"],
      "ip": ["*"]
    },
    {
      "src": ["tag:business-continuity"],
      "dst": ["tag:operator"],
      "ip": ["22"]
    }
  ]
}
```

`tag:operator` → full mesh access (Jeremy)
`tag:business-continuity` → SSH-only access to operator-tagged devices (Aleksandra — emergency access, not day-to-day)

## OIDC Activation Steps (Phase B execution)

1. Verify `setup-realm.sh` created the `tailscale` client in Keycloak
2. In Tailscale admin console (`https://login.tailscale.com`):
   - Settings → General → Identity provider
   - Provider: Custom OIDC
   - Issuer: `https://auth.wilkesliberty.com/realms/wilkesliberty`
   - Client ID: `tailscale`
   - (No client secret — public client)
3. Test login with Jeremy's Keycloak account
4. Apply the ACL policy above
5. Test Aleksandra's login and confirm tag assignment
6. Test connectivity from a Russian IP (VPN or ask Aleksandra to test)

## Dependencies

- Phase A must be complete: Keycloak realm configured, `tailscale` client exists
- `auth.wilkesliberty.com` (public Keycloak endpoint) must be reachable from `login.tailscale.com`
- OIDC discovery endpoint: `https://auth.wilkesliberty.com/realms/wilkesliberty/.well-known/openid-configuration`
