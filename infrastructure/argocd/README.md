# Argo CD Configuration

This directory is a placeholder for Argo CD GitOps configuration.

## Future Content

When ready, this directory will contain:

```
argocd/
├── applications/
│   ├── fastapi-dev.yaml
│   ├── fastapi-staging.yaml
│   └── fastapi-prod.yaml
├── projects/
│   └── fastapi-project.yaml
├── applicationsets/
│   └── fastapi-appset.yaml
└── README.md
```

## Getting Started with Argo CD

See the [Argo CD Guide](../../docs/ARGOCD.md) for comprehensive documentation.

## Quick Install

```bash
# Create namespace
kubectl create namespace argocd

# Install Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
