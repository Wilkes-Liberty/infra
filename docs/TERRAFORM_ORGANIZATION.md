# Terraform Organization

## Current Structure

This project uses **root-level Terraform files** rather than a separate `terraform/` directory. This is a common and recommended pattern for single-environment infrastructure.

## File Organization

```
infra/
├── main.tf              # Core Terraform configuration
├── provider.tf          # Provider configuration (Njalla)
├── variables.tf         # Variable definitions
├── outputs.tf           # Output definitions
├── records.tf           # DNS record definitions
├── mail_proton.tf       # Proton Mail DKIM configuration
├── terraform.tfvars     # Variable values (not committed)
├── .terraform/          # Terraform working directory (gitignored)
└── terraform.tfstate*   # State files (gitignored)
```

## Why Root-Level Organization?

### ✅ Advantages
1. **Single Environment**: Perfect for single production environment
2. **Simplicity**: No nested directory navigation required
3. **Standard Pattern**: Common in Terraform tutorials and examples
4. **Tool Compatibility**: Works seamlessly with all Terraform tooling
5. **CI/CD Friendly**: Simpler paths in automation pipelines

### ❌ When NOT to Use This Pattern
- **Multiple environments** (dev/staging/prod) - would need subdirectories
- **Multiple regions** - might benefit from separate directories
- **Different state backends** per environment

## Alternative Patterns (Not Used Here)

### Environment-Based Structure
```
terraform/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── modules/
```

### Service-Based Structure  
```
terraform/
├── dns/
├── compute/
├── networking/
└── security/
```

## Current Setup Benefits

For the Wilkes Liberty infrastructure, the root-level pattern provides:

- **DNS Management**: All DNS records in `records.tf` and `mail_proton.tf`
- **Single State**: One `terraform.tfstate` for all resources
- **Simple Commands**: `terraform plan/apply` from project root
- **Clear Ownership**: All infrastructure defined in one place

## Working with This Structure

### Daily Operations
```bash
# All commands run from project root (/Users/jcerda/Sites/WilkesLiberty/www/infra)
terraform init     # Initialize (first time only)
terraform plan     # Review changes
terraform apply    # Apply changes
terraform show     # View current state
```

### State Management
- State stored locally in `terraform.tfstate` (gitignored)
- Consider remote state backend for team collaboration
- Backup state files regularly

### Adding Resources
- Add resource definitions to appropriate `.tf` files
- Keep related resources together (DNS in `records.tf`, mail in `mail_proton.tf`)
- Use consistent naming conventions

## Future Expansion: Development Environment

### Current Plan
Once production infrastructure is stable, a development environment will be added. The migration strategy:

### Phase 1: Current (Production Only)
```
infra/
├── *.tf files (production)
└── terraform.tfstate (production)
```

### Phase 2: Multi-Environment Structure
```
infra/
├── environments/
│   ├── prod/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── terraform.tfstate
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── terraform.tfstate
│   └── dev/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── terraform.tfstate
├── modules/
│   ├── dns/
│   ├── mail/
│   └── infrastructure/
└── shared/
    └── variables.tf
```

### Migration Steps (When Ready)
1. **Create environment directories**
   ```bash
   mkdir -p environments/prod environments/dev modules
   ```

2. **Move current files to prod/**
   ```bash
   mv *.tf environments/prod/
   mv terraform.tfvars environments/prod/
   mv .terraform/ environments/prod/
   ```

3. **Create shared modules**
   - Extract common DNS patterns into `modules/dns/`
   - Extract mail configuration into `modules/mail/`

4. **Create staging and dev environments**
   - Copy prod structure to `environments/staging/` and `environments/dev/`
   - Adjust variables for environment-specific settings
   - Use different domain names:
     - staging.wilkesliberty.com (staging)
     - dev.wilkesliberty.com (development)

### Benefits of Delayed Migration
- **Focus on production first** - get core infrastructure stable
- **Learn requirements** - understand what should be shared vs environment-specific
- **Proven patterns** - migration based on working production setup
- **Cost control** - avoid dev server costs until prod is validated

### Environment-Specific Considerations

#### Production (Current)
- Full infrastructure stack
- Production DNS records (wilkesliberty.com)
- High-availability configuration
- Production security settings
- Full monitoring and alerting
- Automated backups with long retention

#### Staging (Future - Phase 2a)
- Production-like configuration for realistic testing
- Staging DNS subdomain (staging.wilkesliberty.com)
- Similar instance sizes to production
- Production security model (but isolated)
- Full monitoring for deployment validation
- Shorter backup retention
- Blue/green deployment testing

#### Development (Future - Phase 2b)
- Smaller instance sizes for cost optimization
- Development DNS subdomain (dev.wilkesliberty.com)
- Relaxed security for rapid development
- Shared services where appropriate
- Basic monitoring
- Minimal backup requirements

### Current Approach: Optimal
The root-level organization is perfect for:
- Single environment focus
- Rapid iteration on production setup
- Simple state management
- Learning infrastructure patterns

Once production is stable and development servers are available, the migration to multi-environment structure will be straightforward.
