# Re-enabling Auto-Deployments

Auto-deployment triggers are currently disabled while infrastructure and Ansible playbooks are being built out. When you're ready to enable automatic deployments, follow these steps:

## Steps to Re-enable Auto-Deployments

### 1. Development Environment Auto-Deploy

Edit `.github/workflows/deploy-development.yml`:

```yaml
# Change this:
# on:
#   push:
#     branches: [development]

# Manual trigger only for now
on:
  workflow_dispatch:
    inputs:
      confirm_deployment:
        description: 'Type "deploy" to confirm manual deployment'
        required: true
        default: ''
        type: string

# To this:
on:
  push:
    branches: [development]
  workflow_dispatch:
    inputs:
      confirm_deployment:
        description: 'Type "deploy" to confirm manual deployment'
        required: true
        default: ''
        type: string
```

### 2. Staging Environment Auto-Deploy

Edit `.github/workflows/deploy-staging.yml`:

```yaml
# Change this:
# on:
#   push:
#     branches: [staging]

# Manual trigger only for now
on:
  workflow_dispatch:
    inputs:
      confirm_deployment:
        description: 'Type "deploy" to confirm manual deployment'
        required: true
        default: ''
        type: string

# To this:
on:
  push:
    branches: [staging]
  workflow_dispatch:
    inputs:
      confirm_deployment:
        description: 'Type "deploy" to confirm manual deployment'
        required: true
        default: ''
        type: string
```

### 3. Production Environment Auto-Deploy

Edit `.github/workflows/deploy-production.yml`:

```yaml
# Change this:
# on:
#   push:
#     branches: [master, main]

# Manual trigger only for now
on:
  workflow_dispatch:
    inputs:
      confirm_deployment:
        description: 'Type "deploy" to confirm manual deployment to PRODUCTION'
        required: true
        default: ''
        type: string
      emergency_deployment:
        description: 'Check this box for emergency deployments (skips some checks)'
        required: false
        default: false
        type: boolean

# To this:
on:
  push:
    branches: [master, main]
  workflow_dispatch:
    inputs:
      confirm_deployment:
        description: 'Type "deploy" to confirm manual deployment to PRODUCTION'
        required: true
        default: ''
        type: string
      emergency_deployment:
        description: 'Check this box for emergency deployments (skips some checks)'
        required: false
        default: false
        type: boolean
```

## Remove Manual Confirmation Steps

Once auto-deploy is enabled, you can remove the manual confirmation validation steps:

### Remove from all workflow files:

```yaml
# Remove this step from each workflow:
- name: Validate deployment confirmation
  if: github.event.inputs.confirm_deployment != 'deploy'
  run: |
    echo "❌ Deployment not confirmed. Please type 'deploy' in the confirmation field."
    exit 1
```

## Update Documentation

### Update WARP.md

1. Remove the "Manual Only - Building Phase" notes
2. Update deployment flow diagram to show auto-deployments
3. Update trigger descriptions
4. Remove or update the "Manual Deployment (Current Phase)" section

### Recommended Order

1. **Start with Development**: Enable auto-deploy for development first and test
2. **Then Staging**: After development auto-deploy works well, enable staging
3. **Finally Production**: Enable production auto-deploy last, and consider keeping manual approval

## Safety Considerations

- **Test thoroughly** in development and staging before enabling production auto-deploy
- **Consider keeping** manual approval for production deployments even when auto-enabled
- **Monitor closely** for the first few auto-deployments
- **Have rollback procedures** ready and tested

## Verification

After re-enabling, verify that:
- [ ] Auto-deployments trigger correctly on branch pushes
- [ ] Manual workflow_dispatch still works as backup
- [ ] All tests and checks still run properly
- [ ] Notifications work (Slack, etc.)
- [ ] Rollback procedures are functional

---

**Remember**: Auto-deployments are powerful but require stable, well-tested infrastructure. Only re-enable when you're confident in your Ansible playbooks and infrastructure configuration.