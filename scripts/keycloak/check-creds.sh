#!/usr/bin/env bash
# Verify that the SOPS-stored keycloak_admin_password matches the live Keycloak instance.
# Exits 0 if credentials match, 1 if they don't (drift detected).
set -euo pipefail

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8081}"
REALM="master"

if [[ -z "${SOPS_AGE_KEY_FILE:-}" ]]; then
  echo "ERROR: SOPS_AGE_KEY_FILE is not set. Add it to ~/.zshrc:" >&2
  echo "  export SOPS_AGE_KEY_FILE=\"\$HOME/.config/sops/age/keys.txt\"" >&2
  exit 1
fi

SOPS_PASS=$(sops -d --extract '["keycloak_admin_password"]' \
  ansible/inventory/group_vars/sso_secrets.yml 2>/dev/null) || {
  echo "ERROR: Could not decrypt keycloak_admin_password from sso_secrets.yml" >&2
  exit 1
}

echo "Checking Keycloak credentials against ${KEYCLOAK_URL}..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  --data-urlencode "password=${SOPS_PASS}" \
  -d "grant_type=password")

if [[ "${HTTP_STATUS}" == "200" ]]; then
  echo "OK: SOPS password matches live Keycloak."
  exit 0
elif [[ "${HTTP_STATUS}" == "401" ]]; then
  echo "DRIFT DETECTED: SOPS password does not match live Keycloak (HTTP 401)." >&2
  echo "Run scripts/keycloak/rotate-admin-password.sh to resync." >&2
  exit 1
else
  echo "ERROR: Unexpected HTTP status ${HTTP_STATUS} from Keycloak." >&2
  echo "Is Keycloak running? Check: docker compose ps keycloak" >&2
  exit 1
fi
