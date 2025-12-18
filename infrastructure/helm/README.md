# Helm Charts

This directory is a placeholder for Helm chart implementations.

## Future Content

When ready, this directory will contain:

```
helm/
├── fastapi-app/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-dev.yaml
│   ├── values-prod.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       └── _helpers.tpl
└── README.md
```

## Getting Started with Helm

See the [Helm Guide](../../docs/HELM.md) for comprehensive documentation.

## Quick Commands

```bash
# Create a new chart
helm create fastapi-app

# Install locally
helm install my-release ./fastapi-app -f values-dev.yaml

# Upgrade
helm upgrade my-release ./fastapi-app -f values-prod.yaml
```
