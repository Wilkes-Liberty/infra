# New Employee / Contractor Onboarding

**Organization:** Wilkes & Liberty  
**Maintained by:** Jeremy (`3@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23

---

## Before Day 1 (Manager checklist)

- [ ] Confirm role and system access scope (see [ROLES.md](ROLES.md) and [ACCESS_CONTROL.md](../compliance/ACCESS_CONTROL.md))
- [ ] Order or confirm hardware (if applicable)
- [ ] Create GitHub account invite for `Wilkes-Liberty` org
- [ ] Prepare Tailscale invite (decide which device tag applies — see [TAILSCALE_ACL_DESIGN.md](../TAILSCALE_ACL_DESIGN.md))
- [ ] Create Keycloak account in `wilkesliberty` realm (set temporary password)
- [ ] For Admin/Owner role only: schedule secure transfer of SOPS age key via 1Password Secure Share

---

## Day 1 — Access provisioning

Work through these steps in order. Each step depends on the previous.

### Step 1 — Workstation setup

Install required tools:
```bash
# macOS (Homebrew)
brew install sops age ansible git gh

# Verify
sops --version
age --version
ansible --version
```

Clone the repos:
```bash
git clone git@github.com:Wilkes-Liberty/infra.git ~/Repositories/infra
git clone git@github.com:Wilkes-Liberty/webcms.git ~/Repositories/webcms
# If access to the UI repo is in scope:
git clone git@github.com:Wilkes-Liberty/ui.git ~/Repositories/ui
```

### Step 2 — Tailscale

1. Accept the Tailscale invite (email or SMS).
2. Install Tailscale: `brew install --cask tailscale`
3. Authenticate: `tailscale up`
4. Verify connectivity to the on-prem server: `tailscale ping <on-prem-ip>`

### Step 3 — SOPS setup (Admin/Owner role only)

Set up the age key received from your manager:
```bash
mkdir -p ~/.config/sops/age
# Paste the key content from 1Password into:
nano ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# Add to shell profile
echo 'export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"' >> ~/.zshrc
source ~/.zshrc

# Verify you can decrypt
sops -d ~/Repositories/infra/ansible/inventory/group_vars/sso_secrets.yml | head -3
```

### Step 4 — Keycloak account activation

1. Go to `https://auth.int.wilkesliberty.com/realms/wilkesliberty/account` (Tailscale required)
2. Log in with your temporary password.
3. Change your password (minimum 12 characters, not your username or email).
4. Set up TOTP (OTP app): scan the QR code and verify.

### Step 5 — Verify access

```bash
# Can you reach the on-prem services?
curl -s -o /dev/null -w "%{http_code}" https://api.int.wilkesliberty.com/  # should return 302 or 200

# For Admin role — can you run a deployment?
cd ~/Repositories/infra
make check   # validates local environment
```

---

## Required Reading (complete within first week)

All staff must read and confirm they understand the following documents:

| Document | Location | Why |
|----------|----------|-----|
| This onboarding doc | docs/team/ONBOARDING.md | You're reading it |
| Architecture overview | AGENTS.md / CLAUDE.md | Understand the stack |
| Secrets management | docs/SECRETS_MANAGEMENT.md | How we handle credentials |
| Security checklist | docs/SECURITY_CHECKLIST.md | What we protect and why |
| Incident response | docs/compliance/INCIDENT_RESPONSE.md | What to do if something goes wrong |
| Access control policy | docs/compliance/ACCESS_CONTROL.md | Who can access what |
| Data classification | docs/compliance/DATA_CLASSIFICATION.md | How to handle sensitive data |

**Acknowledgment:** After completing the reading, send an email to `3@wilkesliberty.com` with subject line "Onboarding acknowledgment — [Your Name] — [Date]" confirming you have read and understood all documents.

---

## Role-specific access (fill in at hire time)

| Access point | [EMPLOYEE_NAME]'s level | Notes |
|-------------|------------------------|-------|
| GitHub | [ ] Read / [ ] Write / [ ] Admin | Which repos? |
| Tailscale | [ ] user-device / [ ] dev / [ ] admin | Tag assigned |
| Keycloak | [ ] user / [ ] drupal-admin / [ ] grafana-admin | |
| SOPS age key | [ ] Yes / [ ] No | Admin role only |
| Production deploy (`make onprem`) | [ ] Yes / [ ] No | Owner/Admin only |

---

## Security training

Complete the initial security training within 30 days. See [SECURITY_TRAINING.md](SECURITY_TRAINING.md) for the training plan and required completion acknowledgment.

---

## Contact

Questions? Reach Jeremy at `3@wilkesliberty.com` or via Tailscale SSH (`ssh jeremy@<onprem-ip>`).
