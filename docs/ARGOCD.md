# Argo CD GitOps Guide

A comprehensive guide to GitOps continuous delivery with Argo CD.

---

## 📋 Table of Contents

1. [What is GitOps?](#what-is-gitops)
2. [Argo CD Overview](#argo-cd-overview)
3. [Installation](#installation)
4. [Core Concepts](#core-concepts)
5. [Applications](#applications)
6. [Sync Strategies](#sync-strategies)
7. [Projects and RBAC](#projects-and-rbac)
8. [Best Practices](#best-practices)

---

## What is GitOps?

GitOps uses Git as the single source of truth for declarative infrastructure and applications.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    GitOps Workflow                                   │
│                                                                      │
│   Developer ───► Git Push ───► Argo CD ───► Kubernetes Cluster      │
│       ▲                            │                                 │
│       │                            │                                 │
│       └──────── Feedback ◄─────────┘                                │
│                                                                      │
│   Principles:                                                        │
│   ✓ Declarative configuration                                        │
│   ✓ Version controlled                                               │
│   ✓ Automatically applied                                            │
│   ✓ Continuously reconciled                                          │
└─────────────────────────────────────────────────────────────────────┘
```

### Push vs Pull Deployment

| Approach | Description |
|----------|-------------|
| **Push (CI/CD)** | CI pipeline pushes to cluster |
| **Pull (GitOps)** | Cluster pulls from Git repo |

---

## Argo CD Overview

Argo CD is a declarative GitOps continuous delivery tool for Kubernetes.

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Argo CD Components                                │
│                                                                      │
│   ┌───────────────┐                                                  │
│   │   Git Repo    │ ◄── Source of truth                             │
│   └───────┬───────┘                                                  │
│           │                                                          │
│           ▼                                                          │
│   ┌───────────────────────────────────────────────────────────────┐ │
│   │                     Argo CD                                    │ │
│   │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │ │
│   │   │  API Server │  │ Repo Server │  │ Application │          │ │
│   │   │             │  │             │  │ Controller  │          │ │
│   │   └─────────────┘  └─────────────┘  └─────────────┘          │ │
│   └───────────────────────────────────────────────────────────────┘ │
│           │                                                          │
│           ▼                                                          │
│   ┌───────────────┐                                                  │
│   │  Kubernetes   │ ◄── Target cluster                              │
│   └───────────────┘                                                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Installation

### Using kubectl

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Using Helm

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd --create-namespace
```

### Access UI

```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Login: admin / <password>
```

### Install CLI

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd && sudo mv argocd /usr/local/bin/
```

---

## Core Concepts

### Application

An Application defines the source (Git) and destination (Kubernetes).

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo
    targetRevision: main
    path: k8s/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Sync Status

| Status | Meaning |
|--------|---------|
| **Synced** | Live state matches Git |
| **OutOfSync** | Difference detected |
| **Unknown** | Cannot determine |

### Health Status

| Status | Meaning |
|--------|---------|
| **Healthy** | All resources healthy |
| **Progressing** | Resources updating |
| **Degraded** | Failures detected |
| **Suspended** | Paused |

---

## Applications

### Kustomize Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fastapi-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/k8s_hello_world
    targetRevision: main
    path: k8s/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: fastapi-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Helm Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-ingress
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://kubernetes.github.io/ingress-nginx
    chart: ingress-nginx
    targetRevision: 4.8.3
    helm:
      values: |
        controller:
          replicaCount: 2
  destination:
    server: https://kubernetes.default.svc
    namespace: ingress-nginx
```

### ApplicationSet

Deploy to multiple clusters/environments:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-app
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - cluster: dev
            url: https://dev-cluster.example.com
          - cluster: prod
            url: https://prod-cluster.example.com
  template:
    metadata:
      name: 'my-app-{{cluster}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/repo
        path: 'k8s/overlays/{{cluster}}'
      destination:
        server: '{{url}}'
        namespace: my-app
```

---

## Sync Strategies

### Manual Sync

```bash
argocd app sync my-app
```

### Automated Sync

```yaml
syncPolicy:
  automated:
    prune: true       # Delete resources removed from Git
    selfHeal: true    # Revert manual changes
    allowEmpty: false # Don't sync empty resources
```

### Sync Options

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    - ApplyOutOfSyncOnly=true
```

### Sync Waves

Control deployment order:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Lower = first
```

---

## Projects and RBAC

### Project Definition

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  description: Production applications
  sourceRepos:
    - 'https://github.com/org/*'
  destinations:
    - namespace: 'prod-*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
```

---

## CLI Commands

```bash
# Login
argocd login localhost:8080

# List apps
argocd app list

# Create app
argocd app create my-app \
  --repo https://github.com/org/repo \
  --path k8s/overlays/prod \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace production

# Sync app
argocd app sync my-app

# Get app status
argocd app get my-app

# Rollback
argocd app rollback my-app <revision>

# Delete app
argocd app delete my-app
```

---

## Best Practices

1. **Use App of Apps pattern** for managing multiple apps
2. **Separate repos** for app code and deployment configs
3. **Use Sealed Secrets** for sensitive data
4. **Implement sync waves** for dependencies
5. **Enable notifications** for sync status

---

## Further Reading

- [Argo CD Docs](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://opengitops.dev/)
- [ApplicationSet Docs](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)

---

## Next Steps

Learn monitoring with Prometheus + Grafana: [Monitoring Guide →](MONITORING.md)
