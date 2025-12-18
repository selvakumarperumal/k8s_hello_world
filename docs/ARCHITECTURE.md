# Architecture Overview

This document describes the complete architecture of the FastAPI Hello World deployment on AWS EKS.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                  INTERNET                                        │
└─────────────────────────────────────────┬───────────────────────────────────────┘
                                          │
┌─────────────────────────────────────────▼───────────────────────────────────────┐
│                              AWS CLOUD (ap-south-1)                              │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                                   VPC                                      │  │
│  │  ┌─────────────────────────┐    ┌─────────────────────────┐               │  │
│  │  │     Public Subnets      │    │     Private Subnets     │               │  │
│  │  │  ┌──────────────────┐   │    │  ┌──────────────────┐   │               │  │
│  │  │  │   ALB / NLB      │   │    │  │   EKS Nodes      │   │               │  │
│  │  │  │   (Ingress)      │◄──┼────┼──┼─►│ Pod │ Pod │   │   │               │  │
│  │  │  └──────────────────┘   │    │  │  │ Pod │ Pod │   │   │               │  │
│  │  │  ┌──────────────────┐   │    │  │  └──────────────────┘   │            │  │
│  │  │  │   NAT Gateway    │◄──┼────┼──┤                      │   │            │  │
│  │  │  └──────────────────┘   │    │  └──────────────────────┘   │            │  │
│  │  └─────────────────────────┘    └─────────────────────────────┘            │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │     ECR     │  │  Secrets    │  │     S3      │  │  CloudWatch │            │
│  │  (Images)   │  │  Manager    │  │  (State)    │  │   (Logs)    │            │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘            │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## EKS Cluster Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              EKS CLUSTER                                         │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                            CONTROL PLANE (AWS Managed)                     │  │
│  │   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │  │
│  │   │ API      │  │ etcd     │  │Scheduler │  │Controller│                  │  │
│  │   │ Server   │  │          │  │          │  │ Manager  │                  │  │
│  │   └──────────┘  └──────────┘  └──────────┘  └──────────┘                  │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                           DATA PLANE (Node Groups)                         │  │
│  │  ┌─────────────────────────────┐  ┌─────────────────────────────┐         │  │
│  │  │         Node 1 (AZ-a)       │  │         Node 2 (AZ-b)       │         │  │
│  │  │  ┌───────┐ ┌───────┐        │  │  ┌───────┐ ┌───────┐        │         │  │
│  │  │  │ Pod   │ │ Pod   │        │  │  │ Pod   │ │ Pod   │        │         │  │
│  │  │  │┌─────┐│ │┌─────┐│        │  │  │┌─────┐│ │┌─────┐│        │         │  │
│  │  │  ││Proxy││ ││Proxy││        │  │  ││Proxy││ ││Proxy││        │         │  │
│  │  │  │└─────┘│ │└─────┘│        │  │  │└─────┘│ │└─────┘│        │         │  │
│  │  │  └───────┘ └───────┘        │  │  └───────┘ └───────┘        │         │  │
│  │  │  kubelet | kube-proxy       │  │  kubelet | kube-proxy       │         │  │
│  │  └─────────────────────────────┘  └─────────────────────────────┘         │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Namespace Organization

| Namespace | Purpose | Components |
|-----------|---------|------------|
| `default` | Default namespace | Not used |
| `kube-system` | Kubernetes system | CoreDNS, VPC CNI, kube-proxy |
| `ingress-nginx` | Ingress Controller | NGINX Ingress |
| `argocd` | GitOps | Argo CD |
| `monitoring` | Observability | Prometheus, Grafana, AlertManager |
| `linkerd` | Service Mesh | Linkerd control plane |
| `external-secrets` | Secrets Management | External Secrets Operator |
| `development` | Dev environment | FastAPI app (dev) |
| `staging` | Staging environment | FastAPI app (staging) |
| `production` | Production environment | FastAPI app (prod) |

## Request Flow

```
User Request
     │
     ▼
┌─────────────────┐
│  AWS ALB/NLB    │  Layer 4/7 Load Balancer
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ NGINX Ingress   │  Path-based routing, TLS termination
│ Controller      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Linkerd Proxy   │  mTLS, load balancing, retries
│ (sidecar)       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ FastAPI App     │  Application logic
│ Container       │
└─────────────────┘
```

## CI/CD Pipeline

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   GitHub    │────►│   GitHub    │────►│    ECR      │────►│  Argo CD    │
│   Push      │     │   Actions   │     │  (Image)    │     │  (Deploy)   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │   Trivy     │
                    │   Checkov   │
                    │  (Security) │
                    └─────────────┘
```

### Pipeline Stages

1. **Code Push** → Triggers GitHub Actions
2. **Build** → Docker build with multi-stage
3. **Scan** → Trivy (container), Checkov (IaC)
4. **Push** → Push to Amazon ECR
5. **Update** → Update Helm values with new image tag
6. **Sync** → Argo CD detects changes and syncs

## Monitoring Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              MONITORING STACK                                    │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                              Grafana                                       │  │
│  │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                    │  │
│  │   │ Dashboards   │  │ Alerts       │  │ Exploration  │                    │  │
│  │   └──────────────┘  └──────────────┘  └──────────────┘                    │  │
│  └─────────────────────────────────────────────────────────────────────────── │  │
│                                      │                                        │  │
│  ┌───────────────────────────────────▼───────────────────────────────────────┐  │
│  │                            Prometheus                                      │  │
│  │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                    │  │
│  │   │ Metrics DB   │  │ PromQL       │  │ AlertManager │                    │  │
│  │   └──────────────┘  └──────────────┘  └──────────────┘                    │  │
│  └─────────────────────────────────────────────────────────────────────────── │  │
│                       ▲              ▲              ▲                          │  │
│  ┌────────────────────┼──────────────┼──────────────┼────────────────────────┐  │
│  │                    │              │              │                         │  │
│  │    ┌───────────────┴──┐  ┌────────┴───────┐  ┌───┴─────────────┐          │  │
│  │    │ ServiceMonitor   │  │ PodMonitor     │  │ Node Exporter   │          │  │
│  │    │ (FastAPI app)    │  │ (Custom pods)  │  │ (Node metrics)  │          │  │
│  │    └──────────────────┘  └────────────────┘  └─────────────────┘          │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Service Mesh (Linkerd)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              LINKERD SERVICE MESH                                │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                         Control Plane                                      │  │
│  │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                    │  │
│  │   │ Destination  │  │ Identity     │  │ Policy       │                    │  │
│  │   │ Controller   │  │ (mTLS certs) │  │ Controller   │                    │  │
│  │   └──────────────┘  └──────────────┘  └──────────────┘                    │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                          Data Plane (Proxies)                              │  │
│  │  ┌─────────────────────────────┐  ┌─────────────────────────────┐         │  │
│  │  │         Pod A               │  │         Pod B               │         │  │
│  │  │  ┌───────────┐              │  │  ┌───────────┐              │         │  │
│  │  │  │ linkerd   │◄────mTLS────►│  │  │ linkerd   │              │         │  │
│  │  │  │ proxy     │              │  │  │ proxy     │              │         │  │
│  │  │  └─────┬─────┘              │  │  └─────┬─────┘              │         │  │
│  │  │        │                    │  │        │                    │         │  │
│  │  │  ┌─────▼─────┐              │  │  ┌─────▼─────┐              │         │  │
│  │  │  │ Container │              │  │  │ Container │              │         │  │
│  │  │  └───────────┘              │  │  └───────────┘              │         │  │
│  │  └─────────────────────────────┘  └─────────────────────────────┘         │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Linkerd Features Used

- **mTLS**: Automatic encryption between services
- **Retries**: Automatic retry on failed requests
- **Load Balancing**: L7 load balancing with latency-aware routing
- **Traffic Split**: Canary deployments
- **Authorization Policies**: Fine-grained access control

## Security Layers

| Layer | Implementation | Purpose |
|-------|----------------|---------|
| **Network** | VPC, Security Groups | Perimeter security |
| **Ingress** | NGINX with TLS | External access control |
| **Pod Network** | Network Policies | Pod-to-pod isolation |
| **Service Mesh** | Linkerd mTLS | Encrypted service communication |
| **Pod Security** | PSS (Restricted) | Container security |
| **Secrets** | External Secrets + AWS SM | Secret management |
| **RBAC** | Kubernetes RBAC | API access control |
| **Scanning** | Trivy, Checkov | Vulnerability detection |

## Multi-Cluster Patterns

For scaling beyond a single cluster:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           MULTI-CLUSTER ARCHITECTURE                             │
│                                                                                  │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐     │
│  │   Development       │  │   Staging           │  │   Production        │     │
│  │   Cluster           │  │   Cluster           │  │   Cluster (HA)      │     │
│  │   (ap-south-1)      │  │   (ap-south-1)      │  │   (Multi-AZ)        │     │
│  └──────────┬──────────┘  └──────────┬──────────┘  └──────────┬──────────┘     │
│             │                        │                        │                 │
│             └────────────────────────┼────────────────────────┘                 │
│                                      │                                          │
│                              ┌───────▼───────┐                                  │
│                              │   Argo CD     │                                  │
│                              │   (Central)   │                                  │
│                              └───────────────┘                                  │
│                                      │                                          │
│                              ┌───────▼───────┐                                  │
│                              │   GitHub      │                                  │
│                              │   (GitOps)    │                                  │
│                              └───────────────┘                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Multi-Cluster Features

1. **Argo CD ApplicationSets**: Deploy to multiple clusters from single config
2. **Linkerd Multi-Cluster**: Service discovery across clusters
3. **Federation**: Prometheus federation for centralized monitoring
4. **Route53**: DNS-based failover between regions
