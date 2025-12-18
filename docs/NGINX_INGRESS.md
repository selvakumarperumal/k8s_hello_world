# NGINX Ingress Controller Guide

A comprehensive guide to NGINX Ingress Controller for Kubernetes traffic management.

---

## 📋 Table of Contents

1. [What is Ingress?](#what-is-ingress)
2. [NGINX Ingress Controller](#nginx-ingress-controller)
3. [Installation on EKS](#installation-on-eks)
4. [Ingress Resources](#ingress-resources)
5. [Routing Configuration](#routing-configuration)
6. [TLS/SSL Termination](#tlsssl-termination)
7. [Annotations](#annotations)
8. [Advanced Configuration](#advanced-configuration)
9. [AWS Load Balancer Integration](#aws-load-balancer-integration)
10. [Troubleshooting](#troubleshooting)

---

## What is Ingress?

Ingress exposes HTTP/HTTPS routes from outside the cluster to services within the cluster.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Without Ingress vs With Ingress                   │
│                                                                      │
│   WITHOUT INGRESS:                                                   │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                                                             │   │
│   │  User ───► LoadBalancer:$$ ───► Service A                   │   │
│   │  User ───► LoadBalancer:$$ ───► Service B                   │   │
│   │  User ───► LoadBalancer:$$ ───► Service C                   │   │
│   │                                                             │   │
│   │  ❌ One LoadBalancer per service                             │   │
│   │  ❌ Expensive (AWS charges ~$20/month per LB)                │   │
│   │  ❌ No path-based routing                                    │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│   WITH INGRESS:                                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                                                             │   │
│   │  User ───► LoadBalancer ───► Ingress Controller             │   │
│   │                                    │                        │   │
│   │                     ┌──────────────┼──────────────┐         │   │
│   │                     ▼              ▼              ▼         │   │
│   │              /api ───► Svc A  /web ───► Svc B  / ───► Svc C │   │
│   │                                                             │   │
│   │  ✓ Single LoadBalancer for all services                     │   │
│   │  ✓ Path-based and host-based routing                        │   │
│   │  ✓ TLS termination                                          │   │
│   │  ✓ Cost effective                                           │   │
│   └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Ingress Components

| Component | Description |
|-----------|-------------|
| **Ingress Resource** | Kubernetes object defining routing rules |
| **Ingress Controller** | Pod(s) that implement the rules (NGINX, Traefik, etc.) |
| **Load Balancer** | Cloud load balancer fronting the controller |

---

## NGINX Ingress Controller

NGINX Ingress Controller uses NGINX as a reverse proxy and load balancer.

```
┌─────────────────────────────────────────────────────────────────────┐
│                 NGINX Ingress Controller Architecture                │
│                                                                      │
│   ┌─────────────┐                                                    │
│   │   Client    │                                                    │
│   └──────┬──────┘                                                    │
│          │                                                           │
│          ▼                                                           │
│   ┌─────────────────┐                                                │
│   │  AWS NLB/ALB    │  ◄── Cloud Load Balancer                      │
│   └────────┬────────┘                                                │
│            │                                                         │
│            ▼                                                         │
│   ┌─────────────────────────────────────────────────────────┐       │
│   │            NGINX Ingress Controller Pod                  │       │
│   │                                                          │       │
│   │   ┌────────────────────────────────────────────────┐    │       │
│   │   │                  NGINX                          │    │       │
│   │   │                                                 │    │       │
│   │   │   location /api {                               │    │       │
│   │   │     proxy_pass http://api-service;              │    │       │
│   │   │   }                                             │    │       │
│   │   │   location /web {                               │    │       │
│   │   │     proxy_pass http://web-service;              │    │       │
│   │   │   }                                             │    │       │
│   │   └────────────────────────────────────────────────┘    │       │
│   │                                                          │       │
│   │   Controller watches for:                                │       │
│   │   - Ingress resources                                    │       │
│   │   - Services                                             │       │
│   │   - Endpoints                                            │       │
│   │   - Secrets (TLS)                                        │       │
│   └─────────────────────────────────────────────────────────┘       │
│            │                                                         │
│            ├──────────────► Service A ──► Pod A                     │
│            ├──────────────► Service B ──► Pod B                     │
│            └──────────────► Service C ──► Pod C                     │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Installation on EKS

### Using Helm

```bash
# Add ingress-nginx repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=nlb \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing

# Verify installation
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### Using Manifest

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/aws/deploy.yaml
```

### Verify Installation

```bash
# Check controller pods
kubectl get pods -n ingress-nginx

# Check service (get LoadBalancer URL)
kubectl get svc -n ingress-nginx

# Check ingress class
kubectl get ingressclass
```

---

## Ingress Resources

### Basic Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: simple-ingress
  namespace: default
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

### Host-Based Routing

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: host-based-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 80
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: webapp-service
                port:
                  number: 80
```

### Path-Based Routing

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-based-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
    - host: example.com
      http:
        paths:
          - path: /api(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: api-service
                port:
                  number: 8000
          - path: /app(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: webapp-service
                port:
                  number: 3000
          - path: /
            pathType: Prefix
            backend:
              service:
                name: landing-service
                port:
                  number: 80
```

---

## Routing Configuration

### Path Types

| PathType | Behavior |
|----------|----------|
| **Exact** | URL path must match exactly |
| **Prefix** | Matches URL path prefix split by `/` |
| **ImplementationSpecific** | Matching is up to the IngressClass |

```yaml
paths:
  # Exact: matches only /api, not /api/ or /api/v1
  - path: /api
    pathType: Exact
    
  # Prefix: matches /api, /api/, /api/v1, /api/users
  - path: /api
    pathType: Prefix
    
  # ImplementationSpecific: regex with NGINX
  - path: /api(/|$)(.*)
    pathType: ImplementationSpecific
```

### URL Rewriting

```yaml
metadata:
  annotations:
    # Rewrite /api/users → /users
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
    - http:
        paths:
          - path: /api(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: api-service
                port:
                  number: 80
```

---

## TLS/SSL Termination

### Create TLS Secret

```bash
# Create self-signed certificate (for testing)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=example.com"

# Create Kubernetes secret
kubectl create secret tls example-tls \
  --cert=tls.crt \
  --key=tls.key
```

### Ingress with TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - example.com
        - api.example.com
      secretName: example-tls
  rules:
    - host: example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-service
                port:
                  number: 80
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 80
```

### Force HTTPS Redirect

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
```

### Using cert-manager

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Create ClusterIssuer for Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
EOF
```

```yaml
# Ingress with automatic TLS
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: auto-tls-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - example.com
      secretName: example-com-tls  # cert-manager creates this
  rules:
    - host: example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-service
                port:
                  number: 80
```

---

## Annotations

### Common Annotations

```yaml
metadata:
  annotations:
    # SSL/TLS
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    
    # Timeouts
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "300"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
    
    # Body size
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    
    # Rate limiting
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/limit-connections: "5"
    
    # CORS
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
    
    # Authentication
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
    
    # Rewrite
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/use-regex: "true"
    
    # Backend protocol
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    
    # Sticky sessions
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "INGRESSCOOKIE"
```

### Rate Limiting Example

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rate-limited-ingress
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/limit-connections: "5"
    nginx.ingress.kubernetes.io/limit-whitelist: "10.0.0.0/8"
spec:
  ingressClassName: nginx
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 80
```

---

## Advanced Configuration

### Custom NGINX Configuration

```yaml
# ConfigMap for global NGINX settings
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
data:
  proxy-body-size: "50m"
  proxy-read-timeout: "300"
  proxy-send-timeout: "300"
  use-forwarded-headers: "true"
  compute-full-forwarded-for: "true"
  use-proxy-protocol: "false"
  enable-real-ip: "true"
  log-format-upstream: '$remote_addr - $request_id [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"'
```

### Server Snippets

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/server-snippet: |
      set $agentflag 0;
      if ($http_user_agent ~* "(Mobile)" ){
        set $agentflag 1;
      }
      if ( $agentflag = 1 ) {
        return 301 https://m.example.com$request_uri;
      }
```

### Location Snippets

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Frame-Options: DENY";
      more_set_headers "X-Content-Type-Options: nosniff";
      more_set_headers "X-XSS-Protection: 1; mode=block";
```

---

## AWS Load Balancer Integration

### Network Load Balancer (NLB)

```yaml
# During Helm install
controller:
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
      service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
```

### Application Load Balancer (ALB)

For ALB, use AWS Load Balancer Controller instead:

```bash
# Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=my-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

```yaml
# ALB Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: alb-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-service
                port:
                  number: 80
```

### NLB vs ALB

| Feature | NLB | ALB |
|---------|-----|-----|
| **Layer** | 4 (TCP/UDP) | 7 (HTTP/HTTPS) |
| **Performance** | Higher | Lower |
| **Features** | Basic | Path routing, host routing |
| **Cost** | Lower | Higher |
| **Use Case** | TCP traffic, high performance | HTTP routing, SSL termination |

---

## Troubleshooting

### Common Issues

```bash
# Check ingress controller pods
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Check ingress resource
kubectl describe ingress <ingress-name>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check NGINX config
kubectl exec -n ingress-nginx <controller-pod> -- cat /etc/nginx/nginx.conf
kubectl exec -n ingress-nginx <controller-pod> -- nginx -T

# Test from inside cluster
kubectl run test --rm -it --image=curlimages/curl -- curl http://service-name

# Check endpoints
kubectl get endpoints <service-name>
```

### Debug Checklist

| Issue | Check |
|-------|-------|
| 404 Not Found | Path matching, service name, port |
| 502 Bad Gateway | Backend pods running, service endpoints |
| 503 Service Unavailable | Pod health, readiness probes |
| Connection refused | Service port, pod port, firewall |
| SSL errors | TLS secret, certificate validity |

### View NGINX Logs

```bash
# Access logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f

# Error logs
kubectl logs -n ingress-nginx <controller-pod> -c controller --tail=100
```

---

## Example: Complete Setup

```yaml
---
# Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: production
---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: my-api:latest
          ports:
            - containerPort: 8000
---
# Service
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: production
spec:
  selector:
    app: api
  ports:
    - port: 80
      targetPort: 8000
---
# Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - api.example.com
      secretName: api-tls
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 80
```

---

## Next Steps

Now that you understand NGINX Ingress:

1. **Install NGINX Ingress** on your EKS cluster
2. **Configure routing** for your services
3. **Add TLS** with cert-manager
4. **Learn CI/CD** with GitHub Actions: [GitHub Actions Guide →](GITHUB_ACTIONS.md)

---

## Further Reading

- [NGINX Ingress Controller Docs](https://kubernetes.github.io/ingress-nginx/)
- [Kubernetes Ingress Concepts](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
