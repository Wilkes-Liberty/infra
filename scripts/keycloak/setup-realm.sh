#!/usr/bin/env bash
# Idempotent Keycloak realm configuration for wilkesliberty.com.
#
# Run this after standing up a fresh Keycloak container, or to reconcile
# drift. All operations are PUT/POST with existence checks — safe to re-run.
#
# Prerequisites:
#   - Keycloak running at $KEYCLOAK_URL (default: https://auth.int.wilkesliberty.com)
#   - SOPS-decryptable keycloak_admin_password in sso_secrets.yml
#   - SOPS_AGE_KEY_FILE set in environment
#
# What this script configures:
#   Realm:   wilkesliberty — display name, registration, TOTP policy
#   Groups:  operators, business-continuity
#   Roles:   wl-operator, wl-business-continuity (realm roles)
#   Scope:   groups client scope + protocol mapper (sends /groupname in token)
#   Clients: drupal, grafana, tailscale
#   Auth:    custom browser flow for 'drupal' client — denies non-operators
#   Users:   jeremy (operators, TOTP required), aleksandra (business-continuity)
#
# After running:
#   1. Copy the 'grafana' client secret and add to app_secrets.yml via SOPS
#   2. Copy the 'drupal' client secret and add to app_secrets.yml via SOPS
#   3. Run: make onprem   (to apply the secret to .env)
set -euo pipefail

KEYCLOAK_URL="${KEYCLOAK_URL:-https://auth.int.wilkesliberty.com}"
REALM="wilkesliberty"
ADMIN_USER="admin"

# ── Auth helpers ──────────────────────────────────────────────────────────────

get_admin_token() {
  local pass="$1"
  curl -s -f \
    -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=admin-cli&username=${ADMIN_USER}&grant_type=password" \
    --data-urlencode "password=${pass}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])"
}

kc_get() {
  curl -s -f "${KEYCLOAK_URL}/admin/realms/${REALM}/$1" \
    -H "Authorization: Bearer ${TOKEN}"
}

kc_get_master() {
  curl -s -f "${KEYCLOAK_URL}/admin/realms/master/$1" \
    -H "Authorization: Bearer ${TOKEN}"
}

kc_put() {
  curl -s -f -o /dev/null \
    -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/$1" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$2"
}

kc_post() {
  curl -s -f \
    -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/$1" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$2"
}

kc_post_raw() {
  curl -s \
    -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/$1" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -w "\n%{http_code}" \
    -d "$2"
}

json_field() {
  python3 -c "import sys,json; print(json.loads(sys.argv[1]).get('$2',''))" "$1"
}

json_array_id_by_name() {
  python3 -c "
import sys,json
data=json.loads(sys.argv[1])
name=sys.argv[2]
for item in data:
    if item.get('name')==name or item.get('clientId')==name:
        print(item['id']); sys.exit(0)
" "$1" "$2" 2>/dev/null || true
}

# ── Bootstrap ─────────────────────────────────────────────────────────────────

if [[ -z "${SOPS_AGE_KEY_FILE:-}" ]]; then
  echo "ERROR: SOPS_AGE_KEY_FILE is not set." >&2
  exit 1
fi

ADMIN_PASS=$(sops -d --extract '["keycloak_admin_password"]' \
  ansible/inventory/group_vars/sso_secrets.yml 2>/dev/null) || {
  echo "ERROR: Could not decrypt keycloak_admin_password." >&2
  exit 1
}

echo "Authenticating to Keycloak at ${KEYCLOAK_URL}..."
TOKEN=$(get_admin_token "${ADMIN_PASS}") || {
  echo "ERROR: Authentication failed. Run 'make check-keycloak-creds' to diagnose." >&2
  exit 1
}
echo "Authenticated."

# ── Realm ─────────────────────────────────────────────────────────────────────
echo "Configuring realm '${REALM}'..."

REALM_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
  "${KEYCLOAK_URL}/admin/realms/${REALM}" \
  -H "Authorization: Bearer ${TOKEN}")

if [[ "${REALM_EXISTS}" == "404" ]]; then
  echo "  Creating realm..."
  curl -s -f -o /dev/null \
    -X POST "${KEYCLOAK_URL}/admin/realms" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "realm": "'"${REALM}"'",
      "displayName": "Wilkes \u0026 Liberty",
      "enabled": true,
      "registrationAllowed": false,
      "registrationEmailAsUsername": true,
      "loginWithEmailAllowed": true,
      "duplicateEmailsAllowed": false,
      "resetPasswordAllowed": false,
      "editUsernameAllowed": false,
      "bruteForceProtected": true,
      "permanentLockout": false,
      "maxFailureWaitSeconds": 900,
      "failureFactor": 10,
      "sslRequired": "external",
      "otpPolicyType": "totp",
      "otpPolicyAlgorithm": "HmacSHA1",
      "otpPolicyInitialCounter": 0,
      "otpPolicyDigits": 6,
      "otpPolicyLookAheadWindow": 1,
      "otpPolicyPeriod": 30
    }'
  echo "  Realm created."
else
  echo "  Realm exists, updating settings..."
  kc_put "" '{
    "sslRequired": "external",
    "registrationAllowed": false,
    "bruteForceProtected": true,
    "permanentLockout": false,
    "maxFailureWaitSeconds": 900,
    "failureFactor": 10
  }'
fi

# Refresh token after realm creation
TOKEN=$(get_admin_token "${ADMIN_PASS}")

# ── Groups ────────────────────────────────────────────────────────────────────
echo "Configuring groups..."
GROUPS_JSON=$(kc_get "groups")

upsert_group() {
  local name="$1"
  local id
  id=$(json_array_id_by_name "${GROUPS_JSON}" "${name}")
  if [[ -z "${id}" ]]; then
    echo "  Creating group: ${name}"
    kc_post "groups" "{\"name\":\"${name}\"}" > /dev/null
  else
    echo "  Group exists: ${name} (${id})"
  fi
}

upsert_group "operators"
upsert_group "business-continuity"

# ── Realm roles ───────────────────────────────────────────────────────────────
echo "Configuring realm roles..."
ROLES_JSON=$(kc_get "roles")

upsert_role() {
  local name="$1"
  local desc="$2"
  local id
  id=$(json_array_id_by_name "${ROLES_JSON}" "${name}")
  if [[ -z "${id}" ]]; then
    echo "  Creating role: ${name}"
    kc_post "roles" "{\"name\":\"${name}\",\"description\":\"${desc}\"}" > /dev/null
  else
    echo "  Role exists: ${name}"
  fi
}

upsert_role "wl-operator" "Full operator access — Grafana Admin, Drupal login, Tailscale"
upsert_role "wl-business-continuity" "Business continuity read-only access (Aleksandra)"

# ── 'groups' client scope ─────────────────────────────────────────────────────
echo "Configuring 'groups' client scope..."
SCOPES_JSON=$(curl -s -f "${KEYCLOAK_URL}/admin/realms/${REALM}/client-scopes" \
  -H "Authorization: Bearer ${TOKEN}")
SCOPE_ID=$(json_array_id_by_name "${SCOPES_JSON}" "groups")

if [[ -z "${SCOPE_ID}" ]]; then
  echo "  Creating 'groups' client scope..."
  SCOPE_RESP=$(curl -s -D - -o /dev/null \
    -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/client-scopes" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "groups",
      "description": "Group membership claims",
      "protocol": "openid-connect",
      "attributes": {
        "include.in.token.scope": "true",
        "display.on.consent.screen": "false"
      }
    }')
  SCOPE_ID=$(echo "${SCOPE_RESP}" | grep -i "^location:" | sed 's|.*/||' | tr -d '\r\n')
  echo "  Scope ID: ${SCOPE_ID}"
else
  echo "  Scope exists: ${SCOPE_ID}"
fi

# Add groups mapper to the scope
MAPPERS_JSON=$(curl -s -f \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/client-scopes/${SCOPE_ID}/protocol-mappers/models" \
  -H "Authorization: Bearer ${TOKEN}")
MAPPER_EXISTS=$(echo "${MAPPERS_JSON}" | python3 -c "
import sys,json
data=json.load(sys.stdin)
print('yes' if any(m.get('name')=='groups' for m in data) else 'no')
")

if [[ "${MAPPER_EXISTS}" == "no" ]]; then
  echo "  Adding groups protocol mapper..."
  curl -s -f -o /dev/null \
    -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/client-scopes/${SCOPE_ID}/protocol-mappers/models" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "groups",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-group-membership-mapper",
      "consentRequired": false,
      "config": {
        "full.path": "false",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "groups",
        "userinfo.token.claim": "true"
      }
    }'
else
  echo "  Groups mapper already exists."
fi

# ── Clients ───────────────────────────────────────────────────────────────────
echo "Configuring clients..."
CLIENTS_JSON=$(kc_get "clients")

upsert_client() {
  local client_id="$1"
  local payload="$2"
  local id
  id=$(json_array_id_by_name "${CLIENTS_JSON}" "${client_id}")
  if [[ -z "${id}" ]]; then
    echo "  Creating client: ${client_id}"
    RESP=$(curl -s -D - -o /dev/null \
      -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/clients" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "${payload}")
    id=$(echo "${RESP}" | grep -i "^location:" | sed 's|.*/||' | tr -d '\r\n')
  else
    echo "  Updating client: ${client_id} (${id})"
    curl -s -f -o /dev/null \
      -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${id}" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "${payload}"
  fi
  echo "${id}"
}

# drupal client — confidential, PKCE, browser auth flow blocks non-operators
DRUPAL_ID=$(upsert_client "drupal" '{
  "clientId": "drupal",
  "name": "Drupal CMS",
  "enabled": true,
  "publicClient": false,
  "standardFlowEnabled": true,
  "directAccessGrantsEnabled": false,
  "serviceAccountsEnabled": false,
  "authorizationServicesEnabled": false,
  "redirectUris": [
    "https://api.wilkesliberty.com/oauth/*",
    "https://api.int.wilkesliberty.com/oauth/*"
  ],
  "webOrigins": [
    "https://api.wilkesliberty.com",
    "https://api.int.wilkesliberty.com"
  ],
  "attributes": {
    "pkce.code.challenge.method": "S256"
  },
  "defaultClientScopes": ["openid", "profile", "email", "groups"],
  "optionalClientScopes": []
}')

# grafana client — confidential, PKCE, groups scope for role mapping
GRAFANA_ID=$(upsert_client "grafana" '{
  "clientId": "grafana",
  "name": "Grafana",
  "enabled": true,
  "publicClient": false,
  "standardFlowEnabled": true,
  "directAccessGrantsEnabled": false,
  "serviceAccountsEnabled": false,
  "redirectUris": [
    "https://monitor.int.wilkesliberty.com/login/generic_oauth"
  ],
  "webOrigins": [
    "https://monitor.int.wilkesliberty.com"
  ],
  "attributes": {
    "pkce.code.challenge.method": "S256"
  },
  "defaultClientScopes": ["openid", "profile", "email", "groups"],
  "optionalClientScopes": []
}')

# tailscale client — public PKCE (no client secret), for Phase B
upsert_client "tailscale" '{
  "clientId": "tailscale",
  "name": "Tailscale OIDC",
  "enabled": true,
  "publicClient": true,
  "standardFlowEnabled": true,
  "directAccessGrantsEnabled": false,
  "redirectUris": [
    "https://login.tailscale.com/a/oidc/callback"
  ],
  "webOrigins": [],
  "attributes": {
    "pkce.code.challenge.method": "S256"
  },
  "defaultClientScopes": ["openid", "profile", "email", "groups"],
  "optionalClientScopes": []
}' > /dev/null

# ── Custom browser flow for Drupal — deny non-operators ───────────────────────
echo "Configuring Drupal browser auth flow (deny non-operators)..."

FLOWS_JSON=$(curl -s -f "${KEYCLOAK_URL}/admin/realms/${REALM}/authentication/flows" \
  -H "Authorization: Bearer ${TOKEN}")
DENY_FLOW_ID=$(echo "${FLOWS_JSON}" | python3 -c "
import sys,json
for f in json.load(sys.stdin):
    if f.get('alias')=='browser-deny-non-operators': print(f['id']); break
" 2>/dev/null || true)

if [[ -z "${DENY_FLOW_ID}" ]]; then
  echo "  Creating browser-deny-non-operators auth flow..."

  # Copy built-in browser flow
  COPY_RESP=$(curl -s -D - -o /dev/null \
    -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/authentication/flows/browser/copy" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"newName":"browser-deny-non-operators"}')
  DENY_FLOW_ID=$(curl -s -f "${KEYCLOAK_URL}/admin/realms/${REALM}/authentication/flows" \
    -H "Authorization: Bearer ${TOKEN}" | python3 -c "
import sys,json
for f in json.load(sys.stdin):
    if f.get('alias')=='browser-deny-non-operators': print(f['id']); break
")

  # Get executions for the new flow
  EXECUTIONS=$(curl -s -f \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/authentication/flows/browser-deny-non-operators/executions" \
    -H "Authorization: Bearer ${TOKEN}")

  # Add a sub-flow after all existing steps: "Deny non-operators"
  curl -s -f -o /dev/null \
    -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/authentication/flows/browser-deny-non-operators/executions/flow" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"alias":"deny-non-operators","type":"basic-flow","provider":"registration-page-form","description":"Block users without wl-operator role"}'

  # Get the sub-flow ID
  EXECUTIONS=$(curl -s -f \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/authentication/flows/browser-deny-non-operators/executions" \
    -H "Authorization: Bearer ${TOKEN}")
  SUB_FLOW_ID=$(echo "${EXECUTIONS}" | python3 -c "
import sys,json
for e in json.load(sys.stdin):
    if e.get('displayName')=='deny-non-operators': print(e['id']); break
" 2>/dev/null || true)

  if [[ -n "${SUB_FLOW_ID}" ]]; then
    # Add Condition - User Role (negate: must NOT have wl-operator → deny)
    curl -s -f -o /dev/null \
      -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/authentication/flows/deny-non-operators/executions/execution" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"provider":"conditional-user-role"}'

    # Add Deny Access authenticator
    curl -s -f -o /dev/null \
      -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/authentication/flows/deny-non-operators/executions/execution" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"provider":"deny-access-authenticator"}'

    echo "  Auth flow created (manual step required — see note below)."
  fi
  echo ""
  echo "  NOTE: The deny-non-operators sub-flow requires manual configuration in the"
  echo "  Keycloak Admin UI to set the condition authenticator config:"
  echo "    Authentication → Flows → browser-deny-non-operators"
  echo "    → deny-non-operators → Condition - User Role"
  echo "    → Config: Role = wl-operator, Negate = true"
  echo "    → Set sub-flow to REQUIRED, Deny Access to REQUIRED"
  echo ""
else
  echo "  Auth flow already exists: ${DENY_FLOW_ID}"
fi

# Bind the custom flow to the drupal client
if [[ -n "${DRUPAL_ID}" ]]; then
  echo "  Binding browser-deny-non-operators flow to drupal client..."
  curl -s -f -o /dev/null \
    -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${DRUPAL_ID}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"authenticationFlowBindingOverrides\":{\"browser\":\"${DENY_FLOW_ID}\"}}"
fi

# ── Users ─────────────────────────────────────────────────────────────────────
echo "Configuring users..."

upsert_user() {
  local username="$1"
  local email="$2"
  local first="$3"
  local last="$4"
  local totp_required="$5"
  local payload="$6"

  USERS=$(curl -s -f "${KEYCLOAK_URL}/admin/realms/${REALM}/users?username=${username}&exact=true" \
    -H "Authorization: Bearer ${TOKEN}")
  USER_ID=$(echo "${USERS}" | python3 -c "
import sys,json
users=json.load(sys.stdin)
print(users[0]['id'] if users else '')
" 2>/dev/null || true)

  if [[ -z "${USER_ID}" ]]; then
    echo "  Creating user: ${username}"
    RESP=$(curl -s -D - -o /dev/null \
      -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/users" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "${payload}")
    USER_ID=$(echo "${RESP}" | grep -i "^location:" | sed 's|.*/||' | tr -d '\r\n')
  else
    echo "  User exists: ${username} (${USER_ID})"
    curl -s -f -o /dev/null \
      -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${USER_ID}" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "${payload}"
  fi

  echo "${USER_ID}"
}

# jeremy — operators group, TOTP required
JEREMY_ID=$(upsert_user "jeremy" "3@wilkesliberty.com" "Jeremy" "Cerda" "true" '{
  "username": "jeremy",
  "email": "3@wilkesliberty.com",
  "firstName": "Jeremy",
  "lastName": "Cerda",
  "enabled": true,
  "emailVerified": true,
  "requiredActions": ["CONFIGURE_TOTP"],
  "attributes": {
    "locale": ["en"]
  }
}')

# aleksandra — business-continuity group, TOTP optional (not enforced)
ALEKSANDRA_ID=$(upsert_user "aleksandra" "acerda@wilkesliberty.com" "Aleksandra" "Cerda" "false" '{
  "username": "aleksandra",
  "email": "acerda@wilkesliberty.com",
  "firstName": "Aleksandra",
  "lastName": "Cerda",
  "enabled": true,
  "emailVerified": true,
  "requiredActions": [],
  "attributes": {
    "locale": ["en"]
  }
}')

# Assign users to groups
GROUPS_JSON=$(kc_get "groups")

assign_group() {
  local user_id="$1"
  local group_name="$2"
  local group_id
  group_id=$(json_array_id_by_name "${GROUPS_JSON}" "${group_name}")
  if [[ -n "${group_id}" && -n "${user_id}" ]]; then
    curl -s -f -o /dev/null \
      -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${user_id}/groups/${group_id}" \
      -H "Authorization: Bearer ${TOKEN}" || true
    echo "  Assigned ${user_id} → ${group_name}"
  fi
}

[[ -n "${JEREMY_ID}" ]] && assign_group "${JEREMY_ID}" "operators"
[[ -n "${ALEKSANDRA_ID}" ]] && assign_group "${ALEKSANDRA_ID}" "business-continuity"

# Assign realm roles
assign_role() {
  local user_id="$1"
  local role_name="$2"
  local role_json
  role_json=$(curl -s -f "${KEYCLOAK_URL}/admin/realms/${REALM}/roles/${role_name}" \
    -H "Authorization: Bearer ${TOKEN}" 2>/dev/null || true)
  if [[ -n "${role_json}" && "${role_json}" != *"error"* ]]; then
    curl -s -f -o /dev/null \
      -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${user_id}/role-mappings/realm" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "[${role_json}]" || true
    echo "  Assigned role ${role_name} → ${user_id}"
  fi
}

[[ -n "${JEREMY_ID}" ]] && assign_role "${JEREMY_ID}" "wl-operator"
[[ -n "${ALEKSANDRA_ID}" ]] && assign_role "${ALEKSANDRA_ID}" "wl-business-continuity"

# ── Print client secrets ───────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
echo " NEXT STEPS"
echo "════════════════════════════════════════════════════════════"
echo ""

if [[ -n "${GRAFANA_ID}" ]]; then
  GRAFANA_SECRET=$(curl -s -f \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${GRAFANA_ID}/client-secret" \
    -H "Authorization: Bearer ${TOKEN}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('value',''))" 2>/dev/null || echo "(fetch failed)")
  echo " Grafana client secret: ${GRAFANA_SECRET}"
  echo " → Add to app_secrets.yml:"
  echo "     sops ansible/inventory/group_vars/app_secrets.yml"
  echo "     grafana_oauth_client_secret: \"${GRAFANA_SECRET}\""
  echo ""
fi

if [[ -n "${DRUPAL_ID}" ]]; then
  DRUPAL_SECRET=$(curl -s -f \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${DRUPAL_ID}/client-secret" \
    -H "Authorization: Bearer ${TOKEN}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('value',''))" 2>/dev/null || echo "(fetch failed)")
  echo " Drupal client secret: ${DRUPAL_SECRET}"
  echo " → Add to app_secrets.yml:"
  echo "     drupal_client_secret: \"${DRUPAL_SECRET}\""
  echo ""
fi

echo " Auth flow note: if this was a fresh run, manually configure the"
echo " deny-non-operators condition in Keycloak Admin UI (see note above)."
echo ""
echo " When secrets are in SOPS, run: make onprem"
echo "════════════════════════════════════════════════════════════"
