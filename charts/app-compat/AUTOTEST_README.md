# AutoTest Feature for App-Compat Helm Chart

## Overview

The AutoTest feature enables automatic post-deployment testing using ArgoCD PostSync hooks. It supports multiple execution patterns: single script, sequential scripts, and parallel scripts.

## Quick Start

### Basic Configuration (Single Script)

```yaml
autoTest:
  enabled: true
  suite: "smoke"
  threads: 3
  environment: "staging"
  github:
    secretName: "github-pat-secret"
    secretKey: "token"
  secrets:
    gcsServiceAccountKey:
      secretName: "gcs-secrets"
      secretKey: "service-account-key"
    slackWebhookUrl:
      secretName: "slack-secrets"
      secretKey: "webhook-url"
```

This will:
1. Clone the sdet-live-livspace repository
2. Run `framework/k8s/run-post-deploy-tests.sh` script
3. Upload reports to GCS and send Slack notifications

## Execution Patterns

### 1. Single Script Execution (Default)

The simplest approach - runs one test script:

```yaml
autoTest:
  enabled: true
  suite: "smoke"
  scriptPath: "framework/k8s/run-post-deploy-tests.sh"  # Default path
```

### 2. Sequential Script Execution

Run multiple scripts one after another:

```yaml
autoTest:
  enabled: true
  scripts:
    - name: "Smoke Tests"
      command: |
        SUITE=smoke bash framework/k8s/run-post-deploy-tests.sh
      continueOnError: false
      
    - name: "Regression Tests"
      command: |
        SUITE=regression bash framework/k8s/run-post-deploy-tests.sh
      delay: 5  # Wait 5 seconds before starting
      
    - name: "Generate Report"
      command: |
        python3 scripts/generate-report.py
      workDir: "framework"
```

### 3. Parallel Script Execution

Run multiple scripts simultaneously:

```yaml
autoTest:
  enabled: true
  sharedVolume: true
  parallelScripts:
    - name: "smoke-tests"
      command: |
        SUITE=smoke bash framework/k8s/run-post-deploy-tests.sh
      resources:
        requests:
          memory: "1Gi"
          
    - name: "integration-tests"
      command: |
        SUITE=integration bash framework/k8s/run-post-deploy-tests.sh
      resources:
        requests:
          memory: "1Gi"
```

### 4. Hybrid Execution (Parallel + Sequential)

Run scripts in parallel first, then run sequential scripts after:

```yaml
autoTest:
  enabled: true
  sharedVolume: true  # Required for sharing results
  continueOnParallelError: false  # Stop if parallel scripts fail
  
  # Phase 1: These run simultaneously
  parallelScripts:
    - name: "smoke-tests"
      command: |
        SUITE=smoke bash framework/k8s/run-post-deploy-tests.sh
      saveOutput: true  # Save results for sequential phase
      
    - name: "api-validation"
      command: |
        SUITE=api bash framework/k8s/run-post-deploy-tests.sh
      saveOutput: true
  
  # Phase 2: These run sequentially after parallel phase
  scripts:
    - name: "Integration Tests"
      command: |
        # Can check parallel results from /shared directory
        echo "Running after parallel tests complete..."
        SUITE=integration bash framework/k8s/run-post-deploy-tests.sh
        
    - name: "Performance Tests"
      command: |
        SUITE=performance bash framework/k8s/run-post-deploy-tests.sh
```

#### How Hybrid Execution Works:

1. **Parallel Phase (Init Containers)**: All scripts in `parallelScripts` run simultaneously as Kubernetes init containers
2. **Result Collection**: Each parallel script saves its exit code to `/shared` volume
3. **Validation**: Main container checks if all parallel scripts passed (unless `continueOnParallelError: true`)
4. **Sequential Phase**: Scripts in `scripts` array run one after another
5. **Final Status**: Job succeeds only if all phases complete successfully

#### Benefits of Hybrid Approach:

- **Faster Execution**: Run independent tests in parallel to save time
- **Dependency Management**: Sequential tests can depend on parallel test results
- **Resource Optimization**: Control resources for each parallel script independently
- **Fail Fast**: Stop execution early if critical parallel tests fail
- **Result Sharing**: Sequential scripts can access parallel test outputs

## Advanced Features

### Using Different Container Images

```yaml
autoTest:
  parallelScripts:
    - name: "python-tests"
      image: "python:3.11-slim"
      command: |
        pip install pytest
        pytest tests/
        
    - name: "nodejs-tests"
      image: "node:18-alpine"
      command: |
        npm install && npm test
```

### Conditional Execution

```yaml
autoTest:
  scripts:
    - name: "Load Tests"
      command: |
        bash run-load-tests.sh
      condition: '[ "$TARGET_NAMESPACE" == "alpha" ]'
```

### Multiple Repositories

```yaml
autoTest:
  scripts:
    - name: "API Tests"
      repository: "https://github.com/livspaceeng/sdet-live-livspace.git"
      branch: "main"
      command: |
        bash framework/k8s/run-post-deploy-tests.sh
        
    - name: "UI Tests"
      repository: "https://github.com/livspaceeng/ui-automation.git"
      branch: "develop"
      command: |
        npm run test:staging
```

## Configuration Parameters

### Core Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `enabled` | Enable/disable autoTest | `false` | Yes |
| `suite` | Test suite to run | `"smoke"` | Yes |
| `threads` | Number of parallel threads | `3` | No |
| `environment` | Target environment | `"staging"` | No |
| `scriptPath` | Path to test script | `"framework/k8s/run-post-deploy-tests.sh"` | No |

### Repository Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `repository` | Git repository URL | `"https://github.com/livspaceeng/sdet-live-livspace.git"` |
| `branch` | Git branch to clone | `"main"` |

### Secrets Configuration

```yaml
autoTest:
  github:
    secretName: "github-pat-secret"  # Required for private repos
    secretKey: "token"
  secrets:
    authClientId:
      secretName: "auth-secrets"
      secretKey: "client-id"
    authClientSecret:
      secretName: "auth-secrets"
      secretKey: "client-secret"
    gcsServiceAccountKey:
      secretName: "gcs-secrets"
      secretKey: "service-account-key"
    slackWebhookUrl:
      secretName: "slack-secrets"
      secretKey: "webhook-url"
```

### Job Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ttlSecondsAfterFinished` | Auto-cleanup time | `3600` |
| `backoffLimit` | Retry attempts | `0` |
| `serviceAccountName` | K8s service account | `"argo-workflow"` |
| `image` | Container image | `"maven:3.8.6-openjdk-17"` |

### Resource Limits

```yaml
autoTest:
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
```

### Custom Environment Variables

```yaml
autoTest:
  extraEnvVars:
    TEST_TIMEOUT: "3600"
    LOG_LEVEL: "DEBUG"
    CUSTOM_PARAM: "value"
```

## Script Configuration Options

For `scripts` and `parallelScripts`:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `name` | Script name | Required |
| `command` | Bash commands to execute | Required |
| `image` | Container image | Inherits from autoTest.image |
| `requiresRepo` | Clone repository | `true` |
| `continueOnError` | Don't fail job if script fails | `false` |
| `delay` | Seconds to wait before execution | `0` |
| `workDir` | Working directory | Current directory |
| `env` | Script-specific env vars | `{}` |
| `condition` | Bash condition for execution | None |
| `resources` | Resource requirements | Default resources |
| `saveOutput` | Save output to shared volume | `false` |
| `repository` | Override repository URL | Inherits |
| `branch` | Override branch | Inherits |

## Templates

- **Basic Template**: `templates/postsync-test-job.yaml`
  - Supports single script and sequential execution
  - Backward compatible with existing configurations
  
- **Advanced Template**: `templates/postsync-test-job.yaml.advanced`
  - Full support for parallel execution
  - Advanced features like shared volumes
  - Use by renaming to `postsync-test-job.yaml`

## Examples

See `values-autotest-examples.yaml` for complete examples:
1. Single script execution
2. Sequential script execution
3. Parallel script execution
4. Conditional execution
5. Multi-repository testing
6. Custom images
7. Advanced configuration

## Migration Guide

### From Hardcoded Script to Configurable

**Before:**
```yaml
# Fixed script in template
command: |
  git clone repo
  ./post-deploy-tests.sh
```

**After:**
```yaml
autoTest:
  scriptPath: "framework/k8s/run-post-deploy-tests.sh"
  # Or use scripts for more control
  scripts:
    - name: "Run Tests"
      command: |
        bash framework/k8s/run-post-deploy-tests.sh
```

## Troubleshooting

### Script Not Found
- Verify `scriptPath` is correct
- Check if script exists in the repository
- Ensure script has execute permissions

### GitHub Authentication Failed
- Verify GitHub PAT secret exists
- Check secret has correct permissions
- Ensure secret is in the same namespace

### Parallel Scripts Not Running
- Use the advanced template
- Enable `sharedVolume` if needed
- Check init container logs

### Resource Limits
- Increase resources for large test suites
- Monitor pod memory/CPU usage
- Consider splitting into smaller suites

## Best Practices

1. **Start Simple**: Begin with single script execution
2. **Use Secrets**: Never hardcode credentials
3. **Set Resource Limits**: Prevent resource exhaustion
4. **Enable TTL**: Auto-cleanup completed jobs
5. **Use Specific Suites**: Run targeted tests
6. **Monitor Logs**: Check ArgoCD UI for execution logs
7. **Test Locally**: Validate scripts before deployment

## Security Considerations

1. Always use K8s secrets for sensitive data
2. Use GitHub PAT with minimal permissions
3. Rotate secrets regularly
4. Avoid logging sensitive information
5. Use service accounts with appropriate RBAC

## Support

For issues or questions:
1. Check job logs in ArgoCD UI
2. Verify secret configurations
3. Test scripts locally first
4. Review example configurations