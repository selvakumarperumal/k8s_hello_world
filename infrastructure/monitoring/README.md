# Monitoring Stack

This directory is a placeholder for Prometheus + Grafana monitoring configuration.

## Future Content

When ready, this directory will contain:

```
monitoring/
├── prometheus/
│   ├── prometheus-values.yaml
│   └── alerting-rules.yaml
├── grafana/
│   ├── grafana-values.yaml
│   └── dashboards/
│       └── fastapi-dashboard.json
├── servicemonitors/
│   └── fastapi-servicemonitor.yaml
└── README.md
```

## Getting Started with Monitoring

See the [Monitoring Guide](../../docs/MONITORING.md) for comprehensive documentation.

## Quick Install

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Access Grafana
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
```
