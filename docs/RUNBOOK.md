# Operational Runbook

This runbook provides procedures for common operational tasks and incident response.

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Deployment Procedures](#deployment-procedures)
3. [Scaling Operations](#scaling-operations)
4. [Troubleshooting](#troubleshooting)
5. [Incident Response](#incident-response)
6. [Disaster Recovery](#disaster-recovery)

---

## Daily Operations

### Health Check Commands

```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running

# Check application health
kubectl get pods -n production -l app.kubernetes.io/name=fastapi-app
kubectl logs -n production -l app.kubernetes.io/name=fastapi-app --tail=100

# Check ingress
kubectl get ingress -A
kubectl -n ingress-nginx get svc ingress-nginx-controller

# Check Argo CD sync status
argocd app list
argocd app get fastapi-app-prod

# Check Prometheus alerts
kubectl port-forward svc/prometheus-alertmanager -n monitoring 9093:9093
# Visit http://localhost:9093

# Check Linkerd health
linkerd check
linkerd viz stat deploy -n production
```

### Log Collection

```bash
# Application logs
kubectl logs -n production -l app.kubernetes.io/name=fastapi-app --all-containers -f

# Ingress logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=200

# Argo CD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=100

# Export logs to file
kubectl logs -n production deploy/fastapi-app > /tmp/fastapi-logs-$(date +%Y%m%d).log
```

---

## Deployment Procedures

### Manual Helm Deployment

```bash
# Dry run first
helm upgrade --install fastapi-app ./helm/fastapi-app \
  --namespace production \
  --dry-run \
  --debug

# Actual deployment
helm upgrade --install fastapi-app ./helm/fastapi-app \
  --namespace production \
  --set image.repository=$ECR_URL \
  --set image.tag=$NEW_TAG \
  --wait \
  --timeout 5m

# Rollback if needed
helm rollback fastapi-app 1 -n production
```

### GitOps Deployment (Argo CD)

```bash
# Trigger manual sync
argocd app sync fastapi-app-prod

# Force sync (ignore cached manifests)
argocd app sync fastapi-app-prod --force

# Sync with prune
argocd app sync fastapi-app-prod --prune

# View diff before sync
argocd app diff fastapi-app-prod

# View sync history
argocd app history fastapi-app-prod
```

### Canary Deployment

```bash
# Deploy canary with 10% traffic
kubectl apply -f service-mesh/policies/traffic-split.yaml

# Monitor canary metrics
linkerd viz stat deploy/fastapi-app-canary -n production

# If successful, update traffic split to 50%
kubectl patch trafficsplit fastapi-app-canary -n production \
  --type=json -p='[{"op": "replace", "path": "/spec/backends/1/weight", "value": 500}]'

# Complete rollout (100% to canary, then promote)
kubectl patch trafficsplit fastapi-app-canary -n production \
  --type=json -p='[{"op": "replace", "path": "/spec/backends/1/weight", "value": 1000}]'

# Rollback canary (0% to canary)
kubectl patch trafficsplit fastapi-app-canary -n production \
  --type=json -p='[{"op": "replace", "path": "/spec/backends/1/weight", "value": 0}]'
```

---

## Scaling Operations

### Manual Scaling

```bash
# Scale deployment replicas
kubectl scale deployment fastapi-app -n production --replicas=5

# Scale node group (via Terraform)
cd infrastructure
terraform apply -var="node_group_desired_size=4"
```

### HPA Management

```bash
# Check HPA status
kubectl get hpa -n production

# Describe HPA
kubectl describe hpa fastapi-app -n production

# Temporarily disable HPA
kubectl patch hpa fastapi-app -n production -p '{"spec":{"minReplicas":3,"maxReplicas":3}}'

# Re-enable HPA
kubectl patch hpa fastapi-app -n production -p '{"spec":{"minReplicas":2,"maxReplicas":10}}'
```

---

## Troubleshooting

### Pod Issues

#### Pod CrashLoopBackOff

```bash
# Check pod events
kubectl describe pod <pod-name> -n production

# Check previous container logs
kubectl logs <pod-name> -n production --previous

# Check container exit code
kubectl get pod <pod-name> -n production -o jsonpath='{.status.containerStatuses[*].state.waiting.reason}'

# Common causes:
# - Missing environment variables
# - Invalid configuration
# - Resource limits too low
# - Application bugs
```

#### Pod Stuck in Pending

```bash
# Check pod events
kubectl describe pod <pod-name> -n production

# Check node resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check if PVC is bound
kubectl get pvc -n production

# Common causes:
# - Insufficient node resources
# - Node selector mismatch
# - PVC not bound
# - Taints without tolerations
```

### Networking Issues

#### Ingress Not Working

```bash
# Check ingress status
kubectl describe ingress fastapi-app -n production

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Test from inside cluster
kubectl run debug --rm -it --image=curlimages/curl -- curl http://fastapi-app.production.svc.cluster.local/health

# Check network policies
kubectl get networkpolicies -n production
```

#### Service Mesh Issues

```bash
# Check Linkerd proxy status
linkerd viz tap deploy/fastapi-app -n production

# Check proxy logs
kubectl logs <pod-name> -n production -c linkerd-proxy

# Verify mTLS
linkerd viz edges deploy -n production

# Check authorization policies
kubectl get authorizationpolicies -n production
```

### Storage Issues

#### PVC Issues

```bash
# Check PVC status
kubectl get pvc -n production

# Describe PVC
kubectl describe pvc <pvc-name> -n production

# Check storage class
kubectl get sc

# Check EBS CSI driver
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
```

---

## Incident Response

### Severity Levels

| Level | Impact | Response Time | Examples |
|-------|--------|---------------|----------|
| P1 | Production down | 15 min | All pods crashed, no traffic |
| P2 | Major degradation | 30 min | High error rate, severe latency |
| P3 | Minor degradation | 2 hours | Some failures, slightly elevated errors |
| P4 | Low impact | 24 hours | Non-critical feature issues |

### P1 Response: Production Down

```bash
# 1. Verify outage
curl -s -o /dev/null -w "%{http_code}" https://hello.example.com/health

# 2. Check pods
kubectl get pods -n production -l app.kubernetes.io/name=fastapi-app

# 3. Check recent deployments
argocd app history fastapi-app-prod

# 4. Rollback if recent deployment
argocd app rollback fastapi-app-prod 1

# OR rollback Helm
helm rollback fastapi-app 1 -n production

# 5. If rollback doesn't help, scale up replicas
kubectl scale deployment fastapi-app -n production --replicas=10

# 6. Check node health
kubectl get nodes
kubectl describe node <problematic-node>

# 7. Check AWS health
aws eks describe-cluster --name hello-world-dev-eks --query 'cluster.status'
```

### P2 Response: High Error Rate

```bash
# 1. Check current error rate
kubectl logs -n production -l app.kubernetes.io/name=fastapi-app --tail=100 | grep -i error

# 2. Check Prometheus for error metrics
# Query: sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))

# 3. Check recent changes
git log --oneline -10

# 4. Check resource usage
kubectl top pods -n production

# 5. Scale up if resource constrained
kubectl scale deployment fastapi-app -n production --replicas=5

# 6. Enable debug logging temporarily
kubectl set env deployment/fastapi-app -n production LOG_LEVEL=DEBUG

# 7. After investigation, revert logging
kubectl set env deployment/fastapi-app -n production LOG_LEVEL=INFO
```

---

## Disaster Recovery

### Backup Procedures

```bash
# Backup Kubernetes resources
kubectl get all -A -o yaml > k8s-backup-$(date +%Y%m%d).yaml

# Backup Helm releases
helm list -A -o json > helm-releases-$(date +%Y%m%d).json

# Backup Argo CD applications
kubectl get applications -n argocd -o yaml > argocd-apps-$(date +%Y%m%d).yaml

# Backup Terraform state (if not using remote backend)
cp terraform.tfstate terraform.tfstate.backup
```

### Recovery Procedures

#### Complete Cluster Recovery

```bash
# 1. Recreate infrastructure
cd infrastructure
terraform apply -auto-approve

# 2. Configure kubectl
aws eks update-kubeconfig --region ap-south-1 --name hello-world-dev-eks

# 3. Install core components
helm install ingress-nginx ingress-nginx/ingress-nginx ...
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 4. Restore Argo CD applications
kubectl apply -f argocd-apps-backup.yaml

# 5. Sync all applications
argocd app sync --all
```

#### Single Application Recovery

```bash
# From Helm
helm upgrade --install fastapi-app ./helm/fastapi-app \
  --namespace production \
  --create-namespace \
  -f helm/fastapi-app/values-prod.yaml

# From Argo CD
argocd app sync fastapi-app-prod --force
```

### Contact Information

For escalations, contact:

| Role | Contact |
|------|---------|
| On-call Engineer | (via PagerDuty) |
| Platform Team Lead | platform-lead@example.com |
| AWS Support | AWS Console > Support |
