# GitHub Actions CI/CD Guide

A comprehensive guide to CI/CD automation with GitHub Actions for Kubernetes deployments.

---

## 📋 Table of Contents

1. [What is GitHub Actions?](#what-is-github-actions)
2. [Core Concepts](#core-concepts)
3. [Workflow Syntax](#workflow-syntax)
4. [Triggers](#triggers)
5. [Jobs and Steps](#jobs-and-steps)
6. [Secrets and Variables](#secrets-and-variables)
7. [Building Docker Images](#building-docker-images)
8. [Deploying to EKS](#deploying-to-eks)
9. [Best Practices](#best-practices)

---

## What is GitHub Actions?

GitHub Actions is a CI/CD platform integrated into GitHub that automates build, test, and deployment workflows.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    GitHub Actions Workflow                           │
│                                                                      │
│   Git Push ───► Build Job ───► Test Job ───► Deploy Job ───► EKS   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Benefits

| Benefit | Description |
|---------|-------------|
| **Integrated** | Native GitHub integration |
| **Free tier** | 2,000 minutes/month for public repos |
| **Marketplace** | Thousands of pre-built actions |
| **Matrix builds** | Test across multiple versions |

---

## Core Concepts

| Term | Definition |
|------|------------|
| **Workflow** | Automated process defined in YAML file |
| **Event** | Trigger that starts a workflow |
| **Job** | Set of steps running on the same runner |
| **Step** | Individual task in a job |
| **Action** | Reusable unit of code |
| **Runner** | Server that executes workflows |

### File Location

```
.github/workflows/
├── ci.yml
├── deploy.yml
└── release.yml
```

---

## Workflow Syntax

```yaml
name: CI Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  AWS_REGION: ap-south-1

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: npm test
```

---

## Triggers

### Push Trigger
```yaml
on:
  push:
    branches: [main, 'release/**']
    paths: ['src/**']
```

### Pull Request
```yaml
on:
  pull_request:
    types: [opened, synchronize]
    branches: [main]
```

### Manual Trigger
```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options: [dev, staging, prod]
```

### Schedule
```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
```

---

## Jobs and Steps

### Job Configuration
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v4
```

### Step Types
```yaml
steps:
  - name: Use action
    uses: actions/checkout@v4
  
  - name: Run command
    run: npm build
  
  - name: Conditional
    if: github.ref == 'refs/heads/main'
    run: echo "On main"
```

### Job Dependencies
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps: [...]
  
  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps: [...]
```

### Matrix Strategy
```yaml
jobs:
  test:
    strategy:
      matrix:
        node: [16, 18, 20]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
```

---

## Secrets and Variables

### Using Secrets
```yaml
- name: Configure AWS
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ vars.AWS_REGION }}
```

### Setting Outputs
```yaml
jobs:
  build:
    outputs:
      version: ${{ steps.ver.outputs.value }}
    steps:
      - id: ver
        run: echo "value=1.2.3" >> $GITHUB_OUTPUT
```

---

## Building Docker Images

```yaml
name: Build and Push

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-south-1
      
      - id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build and push
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        run: |
          docker build -t $ECR_REGISTRY/my-app:${{ github.sha }} .
          docker push $ECR_REGISTRY/my-app:${{ github.sha }}
```

---

## Deploying to EKS

```yaml
name: Deploy to EKS

on:
  workflow_dispatch:
    inputs:
      environment:
        required: true
        type: choice
        options: [dev, staging, prod]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-south-1
      
      - name: Update kubeconfig
        run: aws eks update-kubeconfig --name my-cluster-${{ inputs.environment }}
      
      - name: Deploy
        run: kubectl apply -k k8s/overlays/${{ inputs.environment }}
      
      - name: Wait for rollout
        run: kubectl rollout status deployment/my-app -n my-namespace --timeout=5m
```

---

## Best Practices

1. **Pin action versions**: `uses: actions/checkout@v4`
2. **Use environments**: Scope secrets to environments
3. **Set timeouts**: `timeout-minutes: 15`
4. **Add status checks**: Use `$GITHUB_STEP_SUMMARY`
5. **Protect main branch**: Require status checks

---

## Project Workflows

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| `docker-build.yml` | Build & push Docker | Manual |
| `terraform-plan.yml` | Preview infrastructure | Manual |
| `terraform-apply.yml` | Apply infrastructure | Manual |
| `deploy.yml` | Deploy to EKS | Manual |

---

## Further Reading

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Workflow Syntax](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)
- [Actions Marketplace](https://github.com/marketplace?type=actions)

---

## Next Steps

Learn GitOps with Argo CD: [Argo CD Guide →](ARGOCD.md)
