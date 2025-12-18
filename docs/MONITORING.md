# Prometheus + Grafana Monitoring Guide

A comprehensive guide to monitoring Kubernetes with Prometheus and Grafana.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prometheus Architecture](#prometheus-architecture)
3. [Grafana Overview](#grafana-overview)
4. [Installation](#installation)
5. [Metrics Collection](#metrics-collection)
6. [PromQL Basics](#promql-basics)
7. [Alerting](#alerting)
8. [Dashboards](#dashboards)
9. [Best Practices](#best-practices)

---

## Overview

Prometheus collects metrics, Grafana visualizes them.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Monitoring Stack                                  │
│                                                                      │
│   ┌───────────────────────────────────────────────────────────────┐ │
│   │                      Kubernetes Cluster                        │ │
│   │                                                                │ │
│   │   ┌─────────┐  ┌─────────┐  ┌─────────┐                       │ │
│   │   │  App 1  │  │  App 2  │  │  App 3  │  ◄── /metrics         │ │
│   │   └────┬────┘  └────┬────┘  └────┬────┘                       │ │
│   │        │            │            │                             │ │
│   │        └────────────┼────────────┘                             │ │
│   │                     ▼                                          │ │
│   │              ┌─────────────┐                                   │ │
│   │              │ Prometheus  │ ◄── Scrapes metrics               │ │
│   │              │             │                                   │ │
│   │              │  Time-series│                                   │ │
│   │              │  database   │                                   │ │
│   │              └──────┬──────┘                                   │ │
│   │                     │                                          │ │
│   │                     ▼                                          │ │
│   │              ┌─────────────┐                                   │ │
│   │              │   Grafana   │ ◄── Visualizes                    │ │
│   │              │             │                                   │ │
│   │              │  Dashboards │                                   │ │
│   │              └─────────────┘                                   │ │
│   └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Prometheus Architecture

### Components

| Component | Purpose |
|-----------|---------|
| **Prometheus Server** | Scrapes and stores metrics |
| **Alertmanager** | Handles alerts |
| **Exporters** | Expose metrics (node, kube-state) |
| **Pushgateway** | Short-lived job metrics |

### How It Works

1. **Scraping**: Prometheus pulls metrics from targets via HTTP
2. **Storage**: Time-series data stored on disk
3. **Querying**: PromQL for data analysis
4. **Alerting**: Rules trigger alerts to Alertmanager

---

## Grafana Overview

Grafana is a visualization platform for metrics, logs, and traces.

### Features

- Interactive dashboards
- Multiple data sources (Prometheus, Loki, etc.)
- Alerting
- User management

---

## Installation

### Using Helm (kube-prometheus-stack)

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin123
```

### Access UIs

```bash
# Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090

# Grafana
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
# Login: admin / admin123

# Alertmanager
kubectl port-forward svc/prometheus-kube-prometheus-alertmanager -n monitoring 9093:9093
```

---

## Metrics Collection

### ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: my-app
  namespaceSelector:
    matchNames:
      - production
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

### PodMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: my-app-pods
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: my-app
  podMetricsEndpoints:
    - port: http
      path: /metrics
```

### Application Metrics (Python/FastAPI)

```python
from prometheus_client import Counter, Histogram, make_asgi_app
from fastapi import FastAPI

app = FastAPI()

# Metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total requests', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'Request latency')

@app.middleware("http")
async def metrics_middleware(request, call_next):
    with REQUEST_LATENCY.time():
        response = await call_next(request)
    REQUEST_COUNT.labels(request.method, request.url.path).inc()
    return response

# Mount metrics endpoint
app.mount("/metrics", make_asgi_app())
```

---

## PromQL Basics

### Query Types

```promql
# Instant vector - current values
http_requests_total

# Range vector - values over time
http_requests_total[5m]

# Scalar - single numeric value
count(up)
```

### Common Queries

```promql
# Request rate (per second)
rate(http_requests_total[5m])

# Error rate
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))

# 95th percentile latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# CPU usage
100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
container_memory_usage_bytes / container_spec_memory_limit_bytes * 100

# Pod restarts
increase(kube_pod_container_status_restarts_total[1h])
```

### Aggregation

```promql
# Sum by label
sum by (app) (rate(http_requests_total[5m]))

# Average across instances
avg(rate(http_requests_total[5m]))

# Top 5 by request rate
topk(5, sum by (app) (rate(http_requests_total[5m])))
```

---

## Alerting

### PrometheusRule

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: app-alerts
  namespace: monitoring
spec:
  groups:
    - name: app.rules
      rules:
        - alert: HighErrorRate
          expr: |
            sum(rate(http_requests_total{status=~"5.."}[5m])) 
            / sum(rate(http_requests_total[5m])) > 0.05
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: High 5xx error rate
            description: Error rate is {{ $value | humanizePercentage }}
        
        - alert: PodCrashLooping
          expr: increase(kube_pod_container_status_restarts_total[1h]) > 3
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: Pod {{ $labels.pod }} is crash looping
```

### Alertmanager Config

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: slack-alerts
  namespace: monitoring
spec:
  route:
    receiver: slack
    groupBy: [alertname, severity]
    groupWait: 30s
    groupInterval: 5m
    repeatInterval: 4h
  receivers:
    - name: slack
      slackConfigs:
        - channel: '#alerts'
          apiURL:
            key: webhook-url
            name: slack-webhook
```

---

## Dashboards

### Pre-built Dashboards

Import from [Grafana.com](https://grafana.com/grafana/dashboards/):

| Dashboard ID | Name |
|--------------|------|
| 315 | Kubernetes Cluster |
| 6417 | Kubernetes Pods |
| 1860 | Node Exporter |
| 7249 | Kubernetes Capacity |

### Custom Dashboard JSON

```json
{
  "dashboard": {
    "title": "FastAPI Metrics",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total[5m]))"
          }
        ]
      }
    ]
  }
}
```

---

## Best Practices

### 1. Resource Limits

```yaml
prometheus:
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
```

### 2. Retention Settings

```yaml
prometheus:
  retention: 15d
  retentionSize: 50GB
```

### 3. Label Cardinality

- Avoid high-cardinality labels (user IDs, request IDs)
- Use aggregations at source

### 4. Recording Rules

Pre-compute expensive queries:

```yaml
groups:
  - name: recording.rules
    rules:
      - record: job:http_requests:rate5m
        expr: sum by (job) (rate(http_requests_total[5m]))
```

---

## Key Metrics

### Application

| Metric | Description |
|--------|-------------|
| Request rate | Requests per second |
| Error rate | % of failed requests |
| Latency | Response time (p50, p95, p99) |
| Throughput | Data transferred |

### Kubernetes

| Metric | Description |
|--------|-------------|
| CPU usage | Pod/node CPU |
| Memory usage | Pod/node memory |
| Pod restarts | Container restarts |
| Node readiness | Node availability |

---

## Further Reading

- [Prometheus Docs](https://prometheus.io/docs/)
- [Grafana Docs](https://grafana.com/docs/)
- [PromQL Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Awesome Prometheus Alerts](https://awesome-prometheus-alerts.grep.to/)

---

## Next Steps

You've completed the DevOps learning roadmap! Review the [Learning Roadmap →](LEARNING_ROADMAP.md) for advanced topics.
