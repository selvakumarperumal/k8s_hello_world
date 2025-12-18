# FastAPI Hello World Helm Chart

A Helm chart for deploying the FastAPI Hello World application on Kubernetes.

## Prerequisites

- Kubernetes 1.26+
- Helm 3.x
- (Optional) NGINX Ingress Controller
- (Optional) Prometheus Operator for ServiceMonitor

## Installing the Chart

```bash
# Add the image repository first
helm upgrade --install fastapi-app ./helm/fastapi-app \
  --namespace production \
  --create-namespace \
  --set image.repository=<ECR_REPOSITORY_URL> \
  --set image.tag=<IMAGE_TAG>
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| replicaCount | int | `2` | Number of replicas |
| image.repository | string | `""` | Image repository (ECR URL) |
| image.tag | string | `"latest"` | Image tag |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| service.type | string | `"ClusterIP"` | Service type |
| service.port | int | `80` | Service port |
| ingress.enabled | bool | `true` | Enable ingress |
| autoscaling.enabled | bool | `true` | Enable HPA |
| serviceMonitor.enabled | bool | `true` | Enable Prometheus ServiceMonitor |

## Environment-Specific Deployments

```bash
# Development
helm upgrade --install fastapi-app-dev ./helm/fastapi-app \
  -f ./helm/fastapi-app/values-dev.yaml \
  --namespace development

# Staging
helm upgrade --install fastapi-app-staging ./helm/fastapi-app \
  -f ./helm/fastapi-app/values-staging.yaml \
  --namespace staging

# Production
helm upgrade --install fastapi-app-prod ./helm/fastapi-app \
  -f ./helm/fastapi-app/values-prod.yaml \
  --namespace production
```
