---
name: Infrastructure Task
about: Track infrastructure maintenance, deployments, or operational tasks
title: '[INFRA] '
labels: ['infrastructure', 'task']
assignees: ''

---

## Task Description
A clear description of the infrastructure task to be completed.

## Category
- [ ] Deployment
- [ ] Maintenance
- [ ] Security update
- [ ] Configuration change
- [ ] Monitoring setup
- [ ] Backup/restore
- [ ] Performance optimization
- [ ] Documentation update
- [ ] Other: _______________

## Environment
- [ ] Development
- [ ] Staging  
- [ ] Production
- [ ] All environments

## Affected Services
- [ ] On-prem server (Drupal, PostgreSQL, Solr, Redis, Keycloak, monitoring)
- [ ] Njalla VPS (Caddy public ingress, Let's Encrypt)
- [ ] Tailscale mesh / VPN
- [ ] DNS (Terraform public records / CoreDNS internal)
- [ ] All services

## Prerequisites
List any prerequisites that must be completed before starting this task:
- [ ] Prerequisite 1
- [ ] Prerequisite 2

## Implementation Plan
### Steps to Complete
1. Step 1
2. Step 2
3. Step 3

### Commands to Run
```bash
# Add relevant commands here
```

### Configuration Changes
```yaml
# Add configuration snippets here
```

## Testing Plan
How will you verify this task was completed successfully?
- [ ] Test 1
- [ ] Test 2

## Rollback Plan
If something goes wrong, how do you roll back?
1. Rollback step 1
2. Rollback step 2

## Impact Assessment
- **Downtime Required**: [Yes/No] - [Duration]
- **User Impact**: [None/Low/Medium/High]
- **Risk Level**: [Low/Medium/High]

## Maintenance Window
- **Preferred Time**: [e.g., Saturday 2-4 AM UTC]
- **Duration**: [estimated time]
- **Notification Required**: [Yes/No]

## Success Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] All tests pass
- [ ] No errors in logs
- [ ] Services are healthy

## Documentation Updates
- [ ] Update runbooks
- [ ] Update CLAUDE.md
- [ ] Update README.md
- [ ] Update configuration documentation
- [ ] No documentation changes needed

## Related Issues/PRs
Link any related issues or pull requests.

## Additional Notes
Any additional context, concerns, or considerations.