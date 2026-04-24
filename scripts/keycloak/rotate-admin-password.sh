#!/usr/bin/env bash
# Rotate the Keycloak master-realm admin password to match the current SOPS value.
#
# Use when SOPS and the live Keycloak password have drifted (e.g. password changed
# in the Keycloak UI without updating SOPS, or vice versa).
#
# Usage:
#   ./scripts/keycloak/rotate-admin-password.sh --current-password <live-password>
#
# After running, verify sync with: make check-keycloak-creds
set -euo pipefail

# KC 26 requires HTTPS even for Docker-natted localhost connections.
KEYCLOAK_URL="${KEYCLOAK_URL:-https://auth.int.wilkesliberty.com}"

usage() {
  echo "Usage: $0 --current-password <live-keycloak-admin-password>" >&2
  echo "" >&2
  echo "Rotates the live Keycloak admin password to the value stored in sso_secrets.yml." >&2
  echo "The --current-password is the password that currently works in Keycloak (not SOPS)." >&2
  exit 1
}

CURRENT_PASSWORD=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --current-password) CURRENT_PASSWORD="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -z "${CURRENT_PASSWORD}" ]] && usage

if [[ -z "${SOPS_AGE_KEY_FILE:-}" ]]; then
  echo "ERROR: SOPS_AGE_KEY_FILE is not set." >&2
  exit 1
fi

NEW_PASSWORD=$(sops -d --extract '["keycloak_admin_password"]' \
  ansible/inventory/group_vars/sso_secrets.yml 2>/dev/null) || {
  echo "ERROR: Could not decrypt keycloak_admin_password from sso_secrets.yml" >&2
  exit 1
}

echo "Obtaining admin token with current password..."
TOKEN=$(curl -s -f \
  -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  --data-urlencode "password=${CURRENT_PASSWORD}" \
  -d "grant_type=password" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])") || {
  echo "ERROR: Failed to authenticate with current password. Is it correct?" >&2
  exit 1
}

echo "Fetching admin user ID..."
ADMIN_ID=$(curl -s -f \
  "${KEYCLOAK_URL}/admin/realms/master/users?username=admin&exact=true" \
  -H "Authorization: Bearer ${TOKEN}" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])") || {
  echo "ERROR: Failed to fetch admin user ID." >&2
  exit 1
}

echo "Setting new password..."
curl -s -f -o /dev/null \
  -X PUT "${KEYCLOAK_URL}/admin/realms/master/users/${ADMIN_ID}/reset-password" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"password\",\"temporary\":false,\"value\":$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "${NEW_PASSWORD}")}" || {
  echo "ERROR: Failed to set new password." >&2
  exit 1
}

echo "Password rotated. Verifying..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  --data-urlencode "password=${NEW_PASSWORD}" \
  -d "grant_type=password")

if [[ "${HTTP_STATUS}" == "200" ]]; then
  echo "OK: Keycloak admin password now matches sso_secrets.yml."
else
  echo "ERROR: Verification failed (HTTP ${HTTP_STATUS}). Check Keycloak logs." >&2
  exit 1
fi
