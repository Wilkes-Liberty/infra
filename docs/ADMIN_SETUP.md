# First-Run Admin Setup

Post-deploy manual configuration required for each service. Start with Drupal + Next.js wiring since that's the content-delivery blocker; Keycloak and Grafana can follow at your own pace.

All credentials are SOPS-encrypted. Reveal any secret with:
```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
sops -d ansible/inventory/group_vars/sso_secrets.yml
sops -d ansible/inventory/group_vars/app_secrets.yml
```

---

## 1. Drupal OAuth2 Consumer (blocker for Next.js content fetching)

Next.js uses the `client_credentials` OAuth2 grant to fetch protected/draft Drupal content server-side. Until this is wired up, only publicly cached content renders; ISR revalidation is also broken.

### Step 1 — Create a service-account user in Drupal

Next.js needs a Drupal user to impersonate when fetching content. Create a dedicated one:

1. Go to `https://api.int.wilkesliberty.com/admin/people/create` (Tailscale required) or `https://api.wilkesliberty.com/admin/people/create`
2. Fill in:
   - **Username**: `nextjs-service`
   - **Email**: `nextjs@wilkesliberty.com` (doesn't need to be real)
   - **Password**: generate something strong (it will never be used to log in)
   - **Status**: Active
   - **Roles**: `Administrator` for initial setup (tighten later once content permissions are clear)
3. Save.

### Step 2 — Create the OAuth2 consumer

Go to: `https://api.wilkesliberty.com/admin/config/services/consumer/add`

Fill in each field exactly as follows:

| Field | Value | Why |
|-------|-------|-----|
| **Label** | `Next.js Frontend` | Display name only — anything works |
| **New Secret** | *(click the button — Drupal generates it)* | Copy this immediately — it is only shown once |
| **Client ID** | `drupal-client` | Matches the default in `docker/.env.example`; Ansible writes this into `DRUPAL_CLIENT_ID` |
| **Redirect URI** | `https://www.wilkesliberty.com` | Required by the form but never used — `client_credentials` grant has no redirect |
| **Scopes** | *(leave empty / unchecked)* | `next-drupal` doesn't request scopes unless you explicitly configure them in code |
| **Is Confidential** | ✅ Yes | Server-to-server; the secret is kept on the VPS, never exposed to a browser |
| **Third Party** | ☐ No | Not a third-party integration |
| **User** | `nextjs-service` | The Drupal user whose permissions are used when Next.js fetches content |

Click **Save**. The generated secret is shown **only once** on the confirmation page — copy it before navigating away.

### Step 3 — Configure the Next.js module

Go to: `https://api.wilkesliberty.com/admin/config/services/next`

Add a site entry:
- **Base URL**: `https://www.wilkesliberty.com`
- **Preview URL**: `https://www.wilkesliberty.com/api/draft`
- **Revalidate URL**: `https://www.wilkesliberty.com/api/revalidate`
- **Revalidation secret**: paste the value of `drupal_revalidate_secret` from `app_secrets.yml`
  ```bash
  sops -d ansible/inventory/group_vars/app_secrets.yml | grep drupal_revalidate_secret
  ```

### Step 4 — Save credentials to sops and redeploy

```bash
sops ansible/inventory/group_vars/app_secrets.yml
```

Set these keys (replace the empty strings):
```yaml
drupal_client_id: "drupal-client"
drupal_client_secret: "<paste the secret Drupal generated>"
drupal_preview_secret: "<generate a random string, e.g. openssl rand -base64 32>"
```

`drupal_revalidate_secret` is already encrypted in the file — leave it.

Save and close sops (it re-encrypts on exit), then redeploy:

```bash
make onprem   # rewrites ~/nas_docker/.env with the new credentials
make vps      # pushes the updated wl-ui.env to the VPS and restarts Next.js
```

After `make vps` completes, `https://www.wilkesliberty.com` should be fetching live Drupal content.

---

## 2. Keycloak (SSO — set up when you're ready to add user login)

Keycloak is running but has no realms or clients configured yet. The site works without it — it's only needed when you want to add authenticated user flows.

**Reveal the admin password:**
```bash
sops -d ansible/inventory/group_vars/sso_secrets.yml | grep keycloak_admin_password
```

**Login URLs:**
- Over Tailscale (preferred): `https://auth.int.wilkesliberty.com/admin/`
- Public: `https://auth.wilkesliberty.com/admin/`

**Admin username**: `admin` (set via `KEYCLOAK_ADMIN=admin` in `docker-compose.yml`)

### First-run setup

1. **Log in** and immediately change the bootstrap admin password via the account menu → Manage Account → Password.

2. **Create the `wilkesliberty` realm**
   - Top-left dropdown → **Create realm**
   - Realm name: `wilkesliberty`
   - Display name: `Wilkes & Liberty`
   - Save.
   - This name matters — the Grafana OAuth URLs in `docker/.env` and `docker-compose.yml` reference `realms/wilkesliberty`.

3. **Realm settings to configure**
   - **General tab** → Display name: `Wilkes & Liberty`
   - **Login tab** → disable "User registration" (you don't want self-signup)
   - **Email tab** → configure SMTP (use Postmark: host `smtp.postmarkapp.com`, port 587, from `inquiry@wilkesliberty.com`, auth username/password from Postmark)
   - **Password policy** → add at minimum: length 12, not username

4. **Create a realm admin user** (separate from the bootstrap `admin`)
   - Users → Add user: username `jmcerda` (or your name), email `3@wilkesliberty.com`
   - Set a password on the Credentials tab (turn off "Temporary")
   - Assign the `realm-admin` role from the `realm-management` client (Role Mappings tab → Client Roles → realm-management → realm-admin)
   - After verifying you can log in as this user, you can demote or delete the bootstrap `admin`.

5. **No clients needed yet** — Keycloak is not wired to Drupal, Next.js, or Grafana in the current config. See the Grafana section below for when you're ready to add SSO.

---

## 3. Grafana

**Reveal the admin password:**
```bash
sops -d ansible/inventory/group_vars/sso_secrets.yml | grep grafana_admin_password
```

**Login URL:** `https://monitor.int.wilkesliberty.com` (Tailscale required)

**Admin username**: `admin`

### First-run setup

1. **Log in** and change the password via Profile → Change Password (or leave it — the password is already in sops).

2. **Add Prometheus as a data source**
   - Connections → Data Sources → Add → Prometheus
   - URL: `http://prometheus:9090` (Docker internal name — Grafana is on the same network)
   - Leave everything else default
   - Click **Save & test** — should return "Data source is working"

3. **Import dashboards** — no dashboards are auto-provisioned; import from grafana.com:
   - Dashboards → New → Import
   - Recommended dashboard IDs (paste into the ID field):
     - `1860` — Node Exporter Full (host metrics)
     - `893` — Docker and System Monitoring (container metrics via cAdvisor)
     - `9628` — PostgreSQL Database
     - `763` — Redis Dashboard

4. **Keycloak SSO (optional — do this after Keycloak is set up)**
   The env vars are already commented in `docker/docker-compose.yml` and `docker/.env`. When ready:
   - Create a `grafana` client in Keycloak (realm `wilkesliberty`):
     - Client type: OpenID Connect
     - Client ID: `grafana`
     - Client authentication: ON (confidential)
     - Valid redirect URIs: `https://monitor.int.wilkesliberty.com/login/generic_oauth`
     - Web origins: `https://monitor.int.wilkesliberty.com`
   - Copy the client secret from the Credentials tab
   - Uncomment the `GF_AUTH_GENERIC_OAUTH_*` block in `~/nas_docker/.env` and fill in the client secret
   - `docker compose restart grafana`

---

## 4. Prometheus

No manual setup required. Prometheus scrapes are configured in `docker/prometheus/prometheus.yml` and deployed by Ansible.

**URL:** `https://metrics.int.wilkesliberty.com` (Tailscale + admin CIDR restricted)

**Verify scrapes are healthy:**
- Go to the URL → Status → Targets
- All targets should be `UP`. Common reasons for `DOWN`: the container health check hasn't passed yet (wait ~2 min after deploy), or a port changed.

**Alert rules** are in `docker/prometheus/alerts.yml` — 16 rules are configured. No changes needed.

**To reload config** (after any file change): `docker compose restart prometheus` — the `--web.enable-lifecycle` flag is intentionally disabled so there's no unauthenticated reload endpoint.

---

## 5. Alertmanager

No manual setup required. The config is rendered from `docker/alertmanager/config.yml.j2` by Ansible during `make onprem`.

**URL:** `https://alerts.int.wilkesliberty.com` (Tailscale + admin CIDR restricted)

**Alert destinations already configured:**
- Email to `3@wilkesliberty.com` via Proton Mail SMTP (credentials in `sso_secrets.yml`)

**To add Slack alerts:** edit `sso_secrets.yml` and add your Slack incoming webhook URL:
```bash
sops ansible/inventory/group_vars/sso_secrets.yml
# add: alert_slack_webhook_url: "https://hooks.slack.com/services/..."
```
Then `make onprem` to re-render the config.

**Verify alerts are routing:** Alertmanager UI → Status — should show the rendered config. Prometheus UI → Alerts — shows which rules are firing.

---

## 6. Uptime Kuma

Uptime Kuma is self-provisioning on first boot — no credentials in sops.

**URL:** `https://uptime.int.wilkesliberty.com` (Tailscale required)

**First-run:**
1. Navigate to the URL — Kuma shows a one-time setup form.
2. Create your admin account (username + password). **Save the password in your password manager** — there's no sops backup for this.
3. Add monitors for public-facing URLs. Recommended initial set:
   - `https://www.wilkesliberty.com` — type: HTTP(s)
   - `https://api.wilkesliberty.com/jsonapi` — type: HTTP(s)
   - `https://auth.wilkesliberty.com/health/ready` — type: HTTP(s)
4. Optionally configure notification channels (email/Slack) under Settings → Notifications.

---

## 7. Solr

Solr runs **without authentication** — it relies entirely on the Caddy CIDR restriction at `search.int.wilkesliberty.com` (only admin CIDRs from `all.yml` can reach it). There is no Solr-level username/password.

**Admin UI:** `https://search.int.wilkesliberty.com/solr/#/` (Tailscale + admin CIDR required)

**Solr core setup:**

Drupal's Search API Solr module creates and manages the core automatically when you configure it in Drupal. You shouldn't need to manually create anything in the Solr UI — but here's the process if you need to bootstrap it manually:

1. In Drupal: `/admin/config/search/search-api` → add a server → type "Solr" → configure with:
   - **Host**: `solr` (Docker internal hostname)
   - **Port**: `8983`
   - **Core**: `drupal` (or whatever name you choose — Drupal will create it)
2. Drupal's Search API Solr module will POST the schema config to Solr automatically on save.
3. Add an index to the server, select content types, and trigger a full reindex.

To check core health from the command line:
```bash
docker exec wl_solr curl -sf http://localhost:8983/solr/admin/cores?action=STATUS
```

---

## 8. PostgreSQL / Redis (no web UI)

**Connect to Drupal's PostgreSQL database:**
```bash
# Reveal the password
sops -d ansible/inventory/group_vars/sso_secrets.yml | grep drupal_db_password

# Connect
docker exec -it wl_postgres psql -U drupal -d drupal
```

**Run Drush commands inside the Drupal container:**
```bash
docker exec -it wl_drupal drush status
docker exec -it wl_drupal drush cim  # import config
docker exec -it wl_drupal drush cr   # clear caches
```

**Redis** is password-authenticated. To verify it's working:
```bash
# Reveal the password
sops -d ansible/inventory/group_vars/sso_secrets.yml | grep redis_password

# Connect
docker exec -it wl_redis redis-cli -a "<password>" ping
# Returns: PONG
```

---

## Quick-reference: sops commands

```bash
# Reveal all app secrets (OAuth, Postmark, revalidation)
sops -d ansible/inventory/group_vars/app_secrets.yml

# Reveal all service passwords (Keycloak, Grafana, DB, Redis)
sops -d ansible/inventory/group_vars/sso_secrets.yml

# Edit a secrets file (decrypts in $EDITOR, re-encrypts on save)
sops ansible/inventory/group_vars/app_secrets.yml
sops ansible/inventory/group_vars/sso_secrets.yml
```
