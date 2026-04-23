# First-Run Admin Setup

Post-deploy manual configuration required for each service. Start with Drupal + Next.js wiring since that's the content-delivery blocker; Keycloak and Grafana can follow at your own pace.

All credentials are SOPS-encrypted. Reveal any secret with:
```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
sops -d ansible/inventory/group_vars/sso_secrets.yml
sops -d ansible/inventory/group_vars/app_secrets.yml
```

**Related docs:**
- [STAGING_REFRESH.md](STAGING_REFRESH.md) — how to clone prod → staging

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

## 2. Postmark Webhook

The `wl_postmark_webhook` module receives bounce, spam-complaint, and delivery events from Postmark and auto-suppresses bad addresses.

`make onprem` sets the webhook secret automatically from `app_secrets.yml`. The only manual step is registering the URL in Postmark's dashboard.

### Register the webhook in Postmark

1. In Postmark → **Servers → wilkesliberty-production → Message Streams → Default Transactional Stream → Webhooks**
2. Add a webhook:
   - **URL**: `https://api.wilkesliberty.com/api/webhooks/postmark/<secret>`
   - Replace `<secret>` with the value of `postmark_webhook_secret` from `app_secrets.yml`:
     ```bash
     sops -d ansible/inventory/group_vars/app_secrets.yml | grep postmark_webhook_secret
     ```
   - **Events to send**: Delivery, Bounce, SpamComplaint (at minimum)
3. Click **Check** to send a test payload — you should see a `200` response.

### Admin UI

- **View events + suppressed addresses**: `https://api.wilkesliberty.com/admin/reports/postmark-events`
- **Settings + test dispatch**: `https://api.wilkesliberty.com/admin/config/services/postmark-webhook`
- **Drush**: `drush wl-postmark:suppressions` — list all current suppressions

### Staging webhook

Staging uses a separate Postmark **sandbox server** (`wilkesliberty-staging`) with its own token stored in `staging_secrets.yml`. The sandbox only delivers to pre-approved recipient addresses — no risk of mailing real users. See [STAGING_REFRESH.md](STAGING_REFRESH.md) for setup.

---

## 3. Keycloak — First-run setup and SSO

Keycloak is running. Perform this section once to create the realm, your user, and the OIDC clients that wire SSO to Grafana and (optionally) Drupal.

> **What's wired vs what needs work:**
> - **Keycloak admin access** — just log in; no infra changes needed.
> - **Grafana SSO** — the config block exists in `docker/docker-compose.yml` as a comment. To activate: uncomment it, add `grafana_oauth_client_secret` to sops, add the var to `docker/.env.j2`, run `make onprem`. Flagged below.
> - **Drupal SSO (openid_connect)** — module is installed via composer but not enabled or wired in Ansible. Flagged below; follow the manual steps.
> - **Uptime Kuma** — no SSO support; skip.

---

### Step A — Log in to the Keycloak admin console

**Login URLs:**
- Over Tailscale (preferred): `https://auth.int.wilkesliberty.com/admin/`
- Public (from outside Tailscale): `https://auth.wilkesliberty.com/admin/`

**Username**: `admin`

**Password** (reveal from sops):
```bash
sops -d ansible/inventory/group_vars/sso_secrets.yml | grep keycloak_admin_password
```

---

### Step B — Create the `wilkesliberty` realm

The bootstrap `admin` user lands in the `master` realm. All work below happens in a dedicated realm.

1. Top-left realm dropdown → **Create realm**
2. **Realm name**: `wilkesliberty` (exact — this slug appears in every OIDC URL)
3. **Display name**: `Wilkes & Liberty`
4. **Enabled**: ON
5. Click **Create**
6. Verify the top-left dropdown now reads `wilkesliberty`

---

### Step C — Recommended realm settings

**Realm settings → Login tab:**
| Setting | Value |
|---------|-------|
| User registration | OFF |
| Edit username | OFF |
| Forgot password | ON (requires SMTP — configure Email tab first) |
| Remember me | ON |
| Verify email | ON (sends verification via Postmark SMTP) |

**Realm settings → Email tab** (configure SMTP so Keycloak can send verification + reset emails):
| Field | Value |
|-------|-------|
| From | `inquiry@wilkesliberty.com` |
| From display name | `Wilkes & Liberty` |
| Host | `smtp.postmarkapp.com` |
| Port | `587` |
| Enable SSL | OFF |
| Enable StartTLS | ON |
| Authentication → Username | Postmark server token (same as `postmark_server_token` in `app_secrets.yml`) |
| Authentication → Password | same token |

Click **Save**, then **Test connection** to confirm.

**Realm settings → Authentication → Password policy** (add these policies):
- Minimum length: `12`
- Not username
- Not email

**Realm settings → Sessions → Tokens tab:**
- Access token lifespan: `15 minutes` (default is fine)
- SSO session idle: `30 minutes`
- SSO session max: `10 hours`

---

### Step D — Create realm roles

Realm roles → **Create role** (create each of these):

| Role name | Used for |
|-----------|----------|
| `admin` | Keycloak admin console access |
| `drupal-admin` | Drupal administrator mapping |
| `grafana-admin` | Grafana Admin role mapping |
| `user` | Basic login — can authenticate but no app admin privileges |

---

### Step E — Create your first user (yourself)

**Users → Add user:**

| Field | Value |
|-------|-------|
| Username | `jmcerda` |
| Email | `3@wilkesliberty.com` |
| Email verified | ON (skip the verification flow for bootstrap user) |
| First name | *(your name)* |
| Last name | *(your name)* |
| Enabled | ON |

Click **Create**. Then:

**Credentials tab → Set password:**
- Enter a strong password
- **Temporary**: OFF (don't force reset on first login for yourself)
- Click **Save password**

**Role mapping tab → Assign role:**
- Click **Assign role**
- Filter by "realm roles"
- Select: `admin`, `drupal-admin`, `grafana-admin`, `user`
- Click **Assign**

After this step you have a named personal account. Day-to-day use this account, not the bootstrap `admin`.

---

### Step F — Create OIDC clients (enables SSO per app)

#### Grafana

> **Status: requires 3 infra changes before this works.** See "Wire Grafana OAuth in Ansible" below.

**In Keycloak → Clients → Create client:**

| Field | Value |
|-------|-------|
| Client type | OpenID Connect |
| Client ID | `grafana` |
| Name | `Grafana (monitor.int)` |

Click **Next**.

| Field | Value |
|-------|-------|
| Client authentication | ON (confidential) |
| Standard flow | ON |
| Direct access grants | OFF |
| Service accounts roles | OFF |

Click **Next → Save**.

**Settings tab:**
| Field | Value |
|-------|-------|
| Valid redirect URIs | `https://monitor.int.wilkesliberty.com/login/generic_oauth` |
| Web origins | `https://monitor.int.wilkesliberty.com` |

Click **Save**.

**Credentials tab** → Copy the **Client secret** (you'll need it below).

**Wire Grafana OAuth in Ansible** (3 changes, then `make onprem`):

1. **Add the secret to sops:**
   ```bash
   sops ansible/inventory/group_vars/sso_secrets.yml
   # add: grafana_oauth_client_secret: "<paste client secret>"
   ```

2. **Add the env var to `docker/.env.j2`** (after the `GRAFANA_ADMIN_PASSWORD` line):
   ```
   GRAFANA_OAUTH_CLIENT_SECRET={{ grafana_oauth_client_secret | default('') }}
   ```

3. **Uncomment the OAuth block in `docker/docker-compose.yml`** (lines ~342–353 in the Grafana service env section). The block to uncomment:
   ```yaml
   - GF_AUTH_GENERIC_OAUTH_ENABLED=true
   - GF_AUTH_GENERIC_OAUTH_NAME=Keycloak
   - GF_AUTH_GENERIC_OAUTH_ALLOW_SIGN_UP=true
   - GF_AUTH_GENERIC_OAUTH_CLIENT_ID=grafana
   - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_CLIENT_SECRET}
   - GF_AUTH_GENERIC_OAUTH_SCOPES=openid profile email
   - GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://auth.int.wilkesliberty.com/realms/wilkesliberty/protocol/openid-connect/auth
   - GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://auth.int.wilkesliberty.com/realms/wilkesliberty/protocol/openid-connect/token
   - GF_AUTH_GENERIC_OAUTH_API_URL=https://auth.int.wilkesliberty.com/realms/wilkesliberty/protocol/openid-connect/userinfo
   - GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(realm_access.roles[*], 'grafana-admin') && 'Admin' || 'Viewer'
   - GF_AUTH_DISABLE_LOGIN_FORM=true
   - GF_AUTH_SIGNOUT_REDIRECT_URL=https://auth.int.wilkesliberty.com/realms/wilkesliberty/protocol/openid-connect/logout
   ```
   > **Note:** The existing comment uses `auth.wilkesliberty.com` (public) and `groups[*]` for the role path — use `auth.int.wilkesliberty.com` and `realm_access.roles[*]` as shown above.

4. Run `make onprem` to re-deploy.

After deploy, `https://monitor.int.wilkesliberty.com` shows a "Sign in with Keycloak" button. Users with the `grafana-admin` realm role become Grafana Admins; all others become Viewers.

---

#### Drupal (`openid_connect` module)

> **Status: module is installed via composer but not enabled or configured in Ansible. Enable it manually, then configure in the Drupal UI.**

**In Keycloak → Clients → Create client:**

| Field | Value |
|-------|-------|
| Client type | OpenID Connect |
| Client ID | `drupal` |
| Name | `Drupal (api.int)` |

Click **Next**.

| Field | Value |
|-------|-------|
| Client authentication | ON (confidential) |
| Standard flow | ON |
| Direct access grants | OFF |

Click **Next → Save**.

**Settings tab:**
| Field | Value |
|-------|-------|
| Valid redirect URIs | `https://api.int.wilkesliberty.com/*`, `https://api.wilkesliberty.com/*` |
| Web origins | `https://api.int.wilkesliberty.com`, `https://api.wilkesliberty.com` |

Click **Save**. Copy the **Client secret** from the Credentials tab.

**Enable and configure in Drupal:**

```bash
# Enable the module
docker exec wl_drupal drush pm:enable openid_connect -y
docker exec wl_drupal drush cr
```

Then in the Drupal admin UI at `https://api.wilkesliberty.com/admin/config/services/openid-connect`:

1. **Add OpenID Connect client** → select **Generic**
2. Fill in:
   | Field | Value |
   |-------|-------|
   | Name | `Keycloak` |
   | Client ID | `drupal` |
   | Client secret | *(paste from Keycloak Credentials tab)* |
   | Issuer URL | `https://auth.int.wilkesliberty.com/realms/wilkesliberty` |
3. **Settings tab** → Login with Keycloak button: ON
4. Save.

After this, Drupal's `/user/login` shows a "Log in with Keycloak" button. Keycloak users are provisioned as Drupal users on first SSO login (role mapping is manual via Drupal's user admin).

---

#### Uptime Kuma

No SSO available. Use the admin credentials from the first-run setup wizard and store them in your password manager.

---

### Step G — Add a second user

**Users → Add user** — same flow as Step E, with these differences:
- **Temporary** password: ON (they reset on first login)
- Assign only the roles they need (`user` for basic login, `drupal-admin`/`grafana-admin` as appropriate)

After creating, the user receives a verification email at their address (via Postmark SMTP). They complete setup at `https://auth.int.wilkesliberty.com/realms/wilkesliberty/account`.

---

### Step H — Test the full SSO flow

Once Grafana OAuth is wired and deployed:

1. In a private browser window, go to `https://monitor.int.wilkesliberty.com`
2. Click **Sign in with Keycloak**
3. Log in with your `jmcerda` account credentials
4. You should land back in Grafana authenticated as Admin (because of `grafana-admin` role)
5. Log out from Grafana → should redirect to Keycloak logout → clears the SSO session

For Drupal, go to `https://api.wilkesliberty.com/user/login` → click **Log in with Keycloak** → same flow.

---

### Step I — Optional hardening (after SSO is working)

**Enforce 2FA for admin accounts:**
1. Realm settings → Authentication → Flows → copy **Browser** flow
2. In the copy, set **OTP Form** → **Required**
3. Bind it: Realm settings → Authentication → Required actions → set as default for users with `admin` role
4. Alternatively: Users → select a user → Credentials tab → Credential reset → OTP

**Brute-force detection:**
- Realm settings → Security defenses → **Brute force detection**: ON
- Max login failures: `5`, Wait increment: `30 seconds`, Max wait: `15 minutes`

---

### Step J — Sops keys added during this flow

After Step F, add these to sops:
```bash
sops ansible/inventory/group_vars/sso_secrets.yml
```
```yaml
grafana_oauth_client_secret: "<Keycloak grafana client secret>"
```

The Drupal client secret is a one-time paste into the Drupal UI (not stored in sops or Ansible, since `openid_connect` is not yet Ansible-managed). If you want it in sops for reference, add:
```yaml
drupal_oidc_client_secret: "<Keycloak drupal client secret>"
```

---

## 4. Grafana

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

4. **Keycloak SSO** — see Section 3, Step F (Grafana). Full wiring instructions are there.

---

## 5. Prometheus

No manual setup required. Prometheus scrapes are configured in `docker/prometheus/prometheus.yml` and deployed by Ansible.

**URL:** `https://metrics.int.wilkesliberty.com` (Tailscale + admin CIDR restricted)

**Verify scrapes are healthy:**
- Go to the URL → Status → Targets
- All targets should be `UP`. Common reasons for `DOWN`: the container health check hasn't passed yet (wait ~2 min after deploy), or a port changed.

**Alert rules** are in `docker/prometheus/alerts.yml` — 16 rules are configured. No changes needed.

**To reload config** (after any file change): `docker compose restart prometheus` — the `--web.enable-lifecycle` flag is intentionally disabled so there's no unauthenticated reload endpoint.

---

## 6. Alertmanager

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

## 7. Uptime Kuma

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

## 8. Solr

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

## 9. PostgreSQL / Redis (no web UI)

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

## 10. Nightly config snapshots

`make onprem` deploys two launchd agents that run at 3:00 AM (prod) and 3:05 AM (staging):

- Export `drush config:export` from the running container
- Push a `auto/config-TIMESTAMP` branch to the `webcms` repo (branched off `origin/master` or `origin/staging`)
- Log a watchdog entry and rotate logs older than 30 days

**Scripts:** `~/Scripts/config-snapshot-prod.sh` and `~/Scripts/config-snapshot-staging.sh`

**Logs:** `~/Backups/wilkesliberty/logs/config-snapshot.log`

`smtp.settings` and `wl_postmark_webhook.settings` are in `config_ignore.settings.yml` — they are intentionally excluded from exports because Ansible is the sole source of truth for those values.

If you need to export config manually:
```bash
docker exec wl_drupal drush config:export -y
cd ~/Repositories/webcms && git status  # review changes
```

---

## Quick-reference: sops commands

```bash
# App secrets (OAuth credentials, Postmark token, revalidation/preview secrets, webhook secrets)
sops -d ansible/inventory/group_vars/app_secrets.yml

# Service passwords (Keycloak, Grafana, DB, Redis, Proton Mail SMTP)
sops -d ansible/inventory/group_vars/sso_secrets.yml

# Staging secrets (staging DB password, staging admin password, staging Postmark token + webhook secret)
sops -d ansible/inventory/group_vars/staging_secrets.yml

# Edit a secrets file (decrypts in $EDITOR, re-encrypts on save)
sops ansible/inventory/group_vars/app_secrets.yml
sops ansible/inventory/group_vars/sso_secrets.yml
sops ansible/inventory/group_vars/staging_secrets.yml
```

### Key inventory by file

| Key | File | Used for |
|-----|------|----------|
| `drupal_client_id` / `drupal_client_secret` | `app_secrets.yml` | Next.js → Drupal OAuth2 |
| `drupal_revalidate_secret` / `drupal_preview_secret` | `app_secrets.yml` | Next.js ISR + preview |
| `postmark_server_token` | `app_secrets.yml` | Production Drupal SMTP |
| `postmark_webhook_secret` | `app_secrets.yml` | Postmark → Drupal webhook URL |
| `keycloak_admin_password` | `sso_secrets.yml` | Keycloak bootstrap admin |
| `grafana_admin_password` | `sso_secrets.yml` | Grafana admin |
| `drupal_db_password` | `sso_secrets.yml` | Production PostgreSQL |
| `redis_password` | `sso_secrets.yml` | Redis auth |
| `stg_drupal_db_password` | `staging_secrets.yml` | Staging PostgreSQL |
| `stg_drupal_admin_password` | `staging_secrets.yml` | Staging Drupal admin (uid=1) |
| `stg_postmark_server_token` | `staging_secrets.yml` | Staging sandbox SMTP (Postmark sandbox server) |
| `stg_postmark_webhook_secret` | `staging_secrets.yml` | Staging webhook URL secret |
