# Multi-Environment Strategy

This document outlines the planned progression from single production environment to a comprehensive multi-environment infrastructure supporting development, staging, and production workflows.

## Environment Strategy Overview

### Current State: Production Focus
- **Status**: Single production environment using root-level Terraform files
- **Rationale**: Get production working and stable before adding complexity
- **Benefits**: Simple state management, rapid iteration, cost control

### Future State: Three-Environment Pipeline
```
Development → Staging → Production
     ↓           ↓         ↓
   Feature    Full Stack  Blue/Green
   Testing    Validation   Deployment
```

## Environment Definitions

### 🚀 **Production Environment**
**Purpose**: Live production infrastructure serving real users

**Characteristics**:
- Full infrastructure stack with all services
- Production DNS records (*.wilkesliberty.com)
- High-availability configuration
- Production security settings
- Full monitoring and alerting
- Automated backups with long retention (30+ days)
- Blue/green deployment capability

**Infrastructure**:
- Full-sized instances for performance
- Redundant services where applicable
- Production-grade security hardening
- Comprehensive monitoring and alerting
- Automated failover capabilities

### 🔍 **Staging Environment**
**Purpose**: Production-like testing environment for deployment validation

**Characteristics**:
- Production-like configuration for realistic testing
- Staging DNS subdomain (*.staging.wilkesliberty.com)
- Similar instance sizes to production
- Production security model (but network-isolated)
- Full monitoring for deployment validation
- Shorter backup retention (7-14 days)
- Blue/green deployment testing

**Infrastructure**:
- Production-scale instances (slightly smaller acceptable)
- Full service stack deployment
- Production security configuration
- Comprehensive monitoring
- Database migration testing
- Load and performance testing

**Testing Focus**:
- Full stack integration testing
- Database migration validation
- Performance and load testing
- Security scanning in prod-like environment
- Automated deployment pipeline testing
- Rollback procedure validation

### 💻 **Development Environment**
**Purpose**: Rapid development and feature testing

**Characteristics**:
- Development DNS subdomain (*.dev.wilkesliberty.com)
- Smaller instance sizes for cost optimization
- Relaxed security settings for debugging
- Shared services where appropriate
- Basic monitoring
- Minimal backup requirements (1-3 days)

**Infrastructure**:
- Cost-optimized instance sizes
- Shared services (single DB for multiple features)
- Development-friendly security settings
- Basic monitoring and logging
- Quick deployment and teardown

**Development Focus**:
- Individual developer environments
- Feature branch deployments
- Integration testing
- Database migration testing
- API development and testing
- Frontend integration testing

## Migration Timeline

### Phase 1: Production Stabilization (Current)
**Timeline**: Ongoing until production is stable
**Focus**: Complete production infrastructure roles and deployment

**Activities**:
1. ✅ Complete infrastructure audit (completed)
2. 🔄 Implement app role (Drupal 11)
3. 🔄 Implement database role (MySQL/MariaDB)
4. 🔄 Implement search role (Apache Solr)
5. 🔄 Implement monitoring role (analytics_obs)
6. 🔄 Finalize SSO role (Authentik)

**Success Criteria**:
- Production deployment working end-to-end
- All services operational and monitored
- Backup and recovery procedures tested
- Documentation complete and accurate

### Phase 2a: Staging Environment (Next Priority)
**Timeline**: After production is stable
**Prerequisites**: Staging servers provisioned

**Activities**:
1. Run migration script: `./scripts/migrate-to-multi-env.sh`
2. Configure staging-specific variables
3. Deploy staging environment
4. Set up CI/CD pipeline: main branch → staging
5. Validate deployment procedures
6. Test rollback procedures

**Success Criteria**:
- Staging environment mirrors production functionality
- Automated deployment from main branch working
- Performance testing pipeline established
- Security validation procedures in place

### Phase 2b: Development Environment (Final Phase)
**Timeline**: After staging is operational
**Prerequisites**: Development servers provisioned

**Activities**:
1. Configure development-specific variables
2. Deploy development environment
3. Set up feature branch deployments
4. Configure developer access and workflows
5. Implement cost controls and resource limits

**Success Criteria**:
- Individual developer environments functional
- Feature branch deployment automation
- Development workflow documentation
- Cost monitoring and controls in place

## Infrastructure Considerations

### Network Architecture
```
Production:  10.10.0.0/24  (current)
Staging:     10.10.0.0/24  (isolated network, same IPs)
Development: 10.20.0.0/24  (different network range)
```

### DNS Strategy
```
Production:  *.wilkesliberty.com
Staging:     *.staging.wilkesliberty.com  
Development: *.dev.wilkesliberty.com
```

### Security Model
- **Production**: Full security hardening, strict access controls
- **Staging**: Production security model, network-isolated
- **Development**: Relaxed security for debugging, developer access

### Monitoring Strategy
- **Production**: Full monitoring, alerting, and observability
- **Staging**: Full monitoring for validation, shorter retention
- **Development**: Basic monitoring, minimal alerting

### Backup Strategy
- **Production**: Daily backups, 30+ day retention, offsite storage
- **Staging**: Daily backups, 7-14 day retention
- **Development**: Minimal backups, 1-3 day retention

## Cost Management

### Resource Optimization
- **Development**: Smaller instances, shared services, scheduled shutdowns
- **Staging**: Right-sized for testing, shutdown during off-hours
- **Production**: Appropriately sized for performance requirements

### Monitoring and Alerts
- Set up cost monitoring across all environments
- Alert on unexpected resource usage
- Regular cost review and optimization

## Deployment Pipeline

### Git Workflow and CI/CD Pipeline

#### Branch Strategy
```
Feature Branches → development → staging → master (main)
        ↓              ↓          ↓         ↓
   Pull Request    Auto Deploy  Auto Deploy Manual Deploy
   Unit Tests     to Dev Env   to Staging   to Production
```

#### GitHub Actions Triggers
- **Development Environment**: Push to `development` branch
- **Staging Environment**: Merge `development` → `staging` branch  
- **Production Environment**: Merge `staging` → `master` branch (with manual approval)

### Deployment Pipeline (GitHub Actions)

#### Development Pipeline
**Trigger**: `push` to `development` branch
```yaml
on:
  push:
    branches: [development]
```
**Actions**:
1. Run unit tests and linting
2. Deploy to development environment
3. Run basic smoke tests
4. Notify team of deployment status

#### Staging Pipeline  
**Trigger**: `push` to `staging` branch (from dev merge)
```yaml
on:
  push:
    branches: [staging]
```
**Actions**:
1. Run full test suite
2. Deploy to staging environment
3. Run integration tests
4. Performance testing
5. Security scanning
6. Generate deployment report

#### Production Pipeline
**Trigger**: `push` to `master` branch (from staging merge) + manual approval
```yaml
on:
  push:
    branches: [master]
environment:
  name: production
  approval_required: true
```
**Actions**:
1. Manual approval gate
2. Blue/green deployment to production
3. Health checks and monitoring
4. Rollback capability
5. Success/failure notifications

### Quality Gates
- **Feature → Development**: Pull request review, unit tests pass
- **Development → Staging**: Integration tests pass, code review approved
- **Staging → Production**: Security scan clean, performance validation, manual approval

## Risk Management

### Deployment Risks
- **Mitigation**: Comprehensive staging environment testing
- **Rollback**: Automated rollback procedures tested in staging
- **Monitoring**: Real-time monitoring with automated alerting

### Cost Risks  
- **Mitigation**: Resource limits, cost monitoring, scheduled shutdowns
- **Monitoring**: Daily cost reports, budget alerts

### Security Risks
- **Mitigation**: Environment isolation, security scanning, access controls
- **Monitoring**: Security event monitoring, regular vulnerability assessment

## Success Metrics

### Performance Metrics
- Deployment frequency and success rate
- Mean time to recovery (MTTR)
- Lead time from development to production

### Quality Metrics
- Defect escape rate from staging to production
- Test coverage across environments
- Security vulnerability detection rate

### Cost Metrics
- Cost per environment
- Resource utilization efficiency
- Cost trend analysis

## Migration Execution

### When Ready to Migrate
1. **Validate prerequisites**: Ensure production is stable and staging/dev servers are available
2. **Run dry-run**: `./scripts/migrate-to-multi-env.sh --dry-run`
3. **Execute migration**: `./scripts/migrate-to-multi-env.sh`
4. **Configure environments**: Update variables for staging and development
5. **Test deployments**: Validate each environment independently
6. **Set up pipelines**: Implement CI/CD automation
7. **Document procedures**: Update operational documentation

### Rollback Plan
- Complete backup created by migration script
- Restore from `backup-[timestamp]/` directory if needed
- Production environment unaffected during migration

---

**Document Status**: Planning Phase  
**Next Review**: After production stabilization  
**Owner**: Infrastructure Team