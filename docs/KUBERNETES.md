# Kubernetes (K8s) Learning Guide

A comprehensive, in-depth guide to understanding Kubernetes concepts for beginners and intermediate users.

---

## Table of Contents

1. [What is Kubernetes?](#what-is-kubernetes)
2. [Kubernetes Architecture Deep Dive](#kubernetes-architecture-deep-dive)
3. [Core Concepts](#core-concepts)
4. [Workload Resources](#workload-resources)
5. [Service & Networking](#service--networking)
6. [Configuration Management](#configuration-management)
7. [Kustomize](#kustomize)
8. [The Kubernetes API](#the-kubernetes-api)
9. [Common kubectl Commands](#common-kubectl-commands)
10. [Project Manifests Explained](#project-manifests-explained)
11. [Best Practices](#best-practices)

---

## What is Kubernetes?

### The Problem Kubernetes Solves

Before Kubernetes, deploying applications was challenging:

```
Traditional Deployment Problems:
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  ❌ Manual scaling - Add servers by hand when traffic increases     │
│  ❌ Downtime during updates - Stop app, update, restart             │
│  ❌ No self-healing - If app crashes, someone must fix it manually  │
│  ❌ Inconsistent environments - "Works on my machine" syndrome      │
│  ❌ Complex load balancing - Managing traffic distribution          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

Kubernetes (K8s) is an open-source container orchestration platform that automates:

| Feature | Description | Example |
|---------|-------------|---------|
| **Deployment** | Rolling out containerized applications | Deploy new version without downtime |
| **Scaling** | Adjusting the number of running containers | Scale from 2 to 10 pods automatically |
| **Self-Healing** | Restarting failed containers | If a pod crashes, K8s creates a new one |
| **Load Balancing** | Distributing traffic across pods | Traffic evenly spread across 5 replicas |
| **Service Discovery** | Finding services by name | `curl http://my-service` instead of IP |
| **Configuration Management** | Centralizing app settings | ConfigMaps and Secrets |
| **Storage Orchestration** | Managing persistent data | Automatic volume provisioning |

### The Name "Kubernetes"

- **Origin**: Greek word "κυβερνήτης" meaning "helmsman" or "pilot"
- **K8s**: The "8" represents the 8 letters between "K" and "s" in "Kubernetes"
- **History**: Originally developed at Google, based on 15+ years of running production workloads

---

## Kubernetes Architecture Deep Dive

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              KUBERNETES CLUSTER                             │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                         CONTROL PLANE (Master)                         │ │
│  │                    "The Brain of the Cluster"                          │ │
│  │                                                                        │ │
│  │   ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────────┐ │ │
│  │   │              │  │              │  │                              │ │ │
│  │   │  API Server  │  │    etcd      │  │     Controller Manager       │ │ │
│  │   │              │  │              │  │                              │ │ │
│  │   │  Front door  │  │  Database    │  │  Maintains desired state     │ │ │
│  │   │  for all     │  │  for all     │  │  Runs control loops          │ │ │
│  │   │  requests    │  │  cluster     │  │                              │ │ │
│  │   │              │  │  data        │  │  Controllers:                │ │ │
│  │   └──────┬───────┘  └──────────────┘  │  - Deployment Controller     │ │ │
│  │          │                            │  - ReplicaSet Controller     │ │ │
│  │          │                            │  - Node Controller           │ │ │
│  │          ▼                            │  - Service Controller        │ │ │
│  │   ┌──────────────┐                    └──────────────────────────────┘ │ │
│  │   │              │                                                     │ │
│  │   │  Scheduler   │  ◄─── Decides which node runs each pod              │ │
│  │   │              │                                                     │ │
│  │   └──────────────┘                                                     │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                      │
│                                      │ kubectl commands, pod scheduling     │
│                                      ▼                                      │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                          WORKER NODES (Data Plane)                     │ │
│  │                      "Where your applications run"                     │ │
│  │                                                                        │ │
│  │   ┌──────────────────────────┐       ┌──────────────────────────┐      │ │
│  │   │        NODE 1            │       │        NODE 2            │      │ │
│  │   │                          │       │                          │      │ │
│  │   │  ┌────────────────────┐  │       │  ┌────────────────────┐  │      │ │
│  │   │  │      kubelet       │  │       │  │      kubelet       │  │      │ │
│  │   │  │  (Node Agent)      │  │       │  │  (Node Agent)      │  │      │ │
│  │   │  └────────────────────┘  │       │  └────────────────────┘  │      │ │
│  │   │                          │       │                          │      │ │
│  │   │  ┌────────────────────┐  │       │  ┌────────────────────┐  │      │ │
│  │   │  │    kube-proxy      │  │       │  │    kube-proxy      │  │      │ │
│  │   │  │  (Network Proxy)   │  │       │  │  (Network Proxy)   │  │      │ │
│  │   │  └────────────────────┘  │       │  └────────────────────┘  │      │ │
│  │   │                          │       │                          │      │ │
│  │   │  ┌────────────────────┐  │       │  ┌────────────────────┐  │      │ │
│  │   │  │  Container Runtime │  │       │  │  Container Runtime │  │      │ │
│  │   │  │  (containerd)      │  │       │  │  (containerd)      │  │      │ │
│  │   │  └────────────────────┘  │       │  └────────────────────┘  │      │ │
│  │   │                          │       │                          │      │ │
│  │   │  ┌─────┐ ┌─────┐ ┌─────┐ │       │  ┌─────┐ ┌─────┐         │      │ │
│  │   │  │Pod 1│ │Pod 2│ │Pod 3│ │       │  │Pod 4│ │Pod 5│         │      │ │
│  │   │  └─────┘ └─────┘ └─────┘ │       │  └─────┘ └─────┘         │      │ │
│  │   │                          │       │                          │      │ │
│  │   └──────────────────────────┘       └──────────────────────────┘      │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### Control Plane Components (In Detail)

The Control Plane is the "brain" of Kubernetes. It makes global decisions about the cluster and responds to cluster events.

#### 1. API Server (kube-apiserver)

**What it is:** The front door to Kubernetes. Every interaction with your cluster goes through the API Server.

**Responsibilities:**
- Validates and processes REST requests
- Updates the cluster state in etcd
- Serves as the hub for all cluster components
- Authenticates and authorizes all API requests

```
┌──────────────────────────────────────────────────────────────────┐
│                         API SERVER                               │
│                                                                  │
│   User/kubectl ─────┐                                            │
│                     │                                            │
│   CI/CD Pipeline ───┼──► Authentication ──► Authorization        │
│                     │         │                   │              │
│   Other Services ───┘         ▼                   ▼              │
│                        ┌─────────────┐    ┌─────────────┐        │
│                        │ Validate    │    │ Admission   │        │
│                        │ Request     │    │ Controllers │        │
│                        └──────┬──────┘    └──────┬──────┘        │
│                               │                   │              │
│                               ▼                   ▼              │
│                        ┌────────────────────────────────┐        │
│                        │    Write to etcd / Response    │        │
│                        └────────────────────────────────┘        │
└──────────────────────────────────────────────────────────────────┘
```

**Example Interaction:**
```bash
# When you run this command:
kubectl create deployment nginx --image=nginx

# Behind the scenes:
# 1. kubectl sends HTTPS request to API Server
# 2. API Server authenticates (who are you?)
# 3. API Server authorizes (can you do this?)
# 4. API Server validates the request
# 5. API Server stores the Deployment in etcd
# 6. API Server notifies relevant controllers
```

**Key Facts:**
- Runs on port 6443 (HTTPS)
- Stateless - can run multiple replicas for HA
- Only component that talks directly to etcd

---

#### 2. etcd

**What it is:** A distributed, consistent key-value store that stores ALL cluster data.

**Responsibilities:**
- Stores cluster state (deployments, pods, services, secrets, etc.)
- Provides strong consistency guarantees
- Maintains cluster configuration

```
┌─────────────────────────────────────────────────────────────────┐
│                            etcd                                 │
│                  "The Source of Truth"                          │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                    Key-Value Storage                     │  │
│   │                                                          │  │
│   │  /registry/deployments/default/nginx    → {Deployment}   │  │
│   │  /registry/pods/default/nginx-abc123    → {Pod spec}     │  │
│   │  /registry/services/default/nginx-svc   → {Service}      │  │
│   │  /registry/secrets/default/my-secret    → {encrypted}    │  │
│   │  /registry/configmaps/default/my-config → {data}         │  │
│   │  /registry/nodes/node-1                 → {Node info}    │  │
│   │                                                          │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Features:                                                     │
│   ✓ Raft consensus (distributed agreement)                      │
│   ✓ Watch capability (notify on changes)                        │
│   ✓ MVCC (multi-version concurrency control)                    │
│   ✓ Data encryption at rest                                     │
└─────────────────────────────────────────────────────────────────┘
```

**Why it matters:**
- If etcd fails, you lose your cluster state
- Backup etcd regularly in production!
- etcd performance affects API Server performance

**Example stored data:**
```
Key: /registry/pods/fastapi-dev/fastapi-pod-xyz
Value: {
  "apiVersion": "v1",
  "kind": "Pod",
  "metadata": {
    "name": "fastapi-pod-xyz",
    "namespace": "fastapi-dev"
  },
  "spec": {
    "containers": [...]
  },
  "status": {
    "phase": "Running"
  }
}
```

---

#### 3. Scheduler (kube-scheduler)

**What it is:** Decides which node should run each new pod.

**Responsibilities:**
- Watches for newly created pods with no assigned node
- Selects the best node based on constraints and resources
- Writes the scheduling decision back to the API Server

```
┌─────────────────────────────────────────────────────────────────┐
│                        SCHEDULER                                │
│              "Where should this pod run?"                       │
│                                                                 │
│   New Pod Created ─────────────────────────────────────┐        │
│   (no node assigned)                                   │        │
│                                                        ▼        │
│                              ┌──────────────────────────────┐   │
│                              │     FILTERING (Predicates)   │   │
│                              │                              │   │
│                              │  Remove nodes that CAN'T run │   │
│                              │  the pod:                    │   │
│                              │                              │   │
│                              │  ✗ Not enough CPU/Memory     │   │
│                              │  ✗ Node is cordoned          │   │
│                              │  ✗ Taints don't match        │   │
│                              │  ✗ NodeSelector doesn't match│   │
│                              │  ✗ PodAffinity violated      │   │
│                              └───────────────┬──────────────┘   │
│                                              │                  │
│                                              ▼                  │
│                              ┌──────────────────────────────┐   │
│                              │      SCORING (Priorities)    │   │
│                              │                              │   │
│                              │  Rank remaining nodes:       │   │
│                              │                              │   │
│                              │  Node 1: 85 points           │   │
│                              │  Node 2: 92 points ◄── Winner│   │
│                              │  Node 3: 78 points           │   │
│                              │                              │   │
│                              │  Factors:                    │   │
│                              │  - Resource balance          │   │
│                              │  - Pod spreading             │   │
│                              │  - Affinity preferences      │   │
│                              └───────────────┬──────────────┘   │
│                                              │                  │
│                                              ▼                  │
│                              ┌──────────────────────────────┐   │
│                              │    BINDING (Schedule Pod)    │   │
│                              │                              │   │
│                              │  Update pod.spec.nodeName    │   │
│                              │  to "node-2"                 │   │
│                              └──────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Scheduling Factors:**
| Factor | Description |
|--------|-------------|
| **Resources** | Does the node have enough CPU/memory? |
| **Node Selector** | Does the pod require specific node labels? |
| **Taints/Tolerations** | Is the node tainted? Does the pod tolerate it? |
| **Affinity/Anti-affinity** | Should the pod be near/far from other pods? |
| **Pod Topology Spread** | Spread pods across zones/nodes |

---

#### 4. Controller Manager (kube-controller-manager)

**What it is:** Runs controller processes that regulate the cluster state.

**The Control Loop Pattern:**
Controllers continuously compare the *desired state* with the *actual state* and take action to reconcile them.

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONTROL LOOP PATTERN                         │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                                                         │   │
│   │     ┌──────────────┐                                    │   │
│   │     │              │                                    │   │
│   │     │  OBSERVE     │ ◄─── Watch cluster state (via API) │   │
│   │     │              │                                    │   │
│   │     └──────┬───────┘                                    │   │
│   │            │                                            │   │
│   │            ▼                                            │   │
│   │     ┌──────────────┐                                    │   │
│   │     │              │                                    │   │
│   │     │  ANALYZE     │ ◄─── Compare desired vs actual     │   │
│   │     │              │                                    │   │
│   │     └──────┬───────┘                                    │   │
│   │            │                                            │   │
│   │            ▼  Different?                                │   │
│   │     ┌──────────────┐                                    │   │
│   │     │              │                                    │   │
│   │     │    ACT       │ ◄─── Take corrective action        │   │
│   │     │              │                                    │   │
│   │     └──────┬───────┘                                    │   │
│   │            │                                            │   │
│   │            └──────────────────────────────────────────► │   │
│   │                         Loop forever                    │   │
│   └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Key Controllers:**

| Controller | What it Does |
|------------|--------------|
| **Deployment Controller** | Manages ReplicaSets based on Deployment specs. If you want 3 replicas, it ensures 3 exist. |
| **ReplicaSet Controller** | Ensures the correct number of pod replicas are running. Creates/deletes pods as needed. |
| **Node Controller** | Monitors node health. Marks nodes as unhealthy, evicts pods from failed nodes. |
| **Service Account Controller** | Creates default service accounts in new namespaces. |
| **Endpoint Controller** | Populates Endpoint objects (links Services to Pods). |
| **Namespace Controller** | Handles namespace deletion cleanup. |

**Example: Deployment Controller in Action**

```
SCENARIO: You have replicas: 3, but one pod crashes

Time 0:00 - Desired: 3 pods, Actual: 3 pods ✓
           Controller: "All good, nothing to do"

Time 0:01 - Pod crashes!
           Desired: 3 pods, Actual: 2 pods ✗

Time 0:02 - Controller notices the difference
           Action: "Create 1 new pod to reach desired state"

Time 0:03 - New pod is scheduled and starting
           Desired: 3 pods, Actual: 2 running + 1 pending

Time 0:05 - New pod is now running
           Desired: 3 pods, Actual: 3 pods ✓
           Controller: "All good again!"
```

---

### Worker Node Components (In Detail)

Worker nodes are where your application containers actually run.

#### 1. kubelet

**What it is:** The primary node agent that runs on every worker node.

**Responsibilities:**
- Registers the node with the cluster
- Watches for pod assignments from the API Server
- Ensures containers are running as specified
- Reports node and pod status back to control plane
- Executes liveness/readiness probes

```
┌─────────────────────────────────────────────────────────────────┐
│                          kubelet                                │
│                    "The Node Agent"                             │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                                                         │   │
│   │   1. WATCH API Server for pods assigned to this node    │   │
│   │                           │                             │   │
│   │                           ▼                             │   │
│   │   2. TRANSLATE pod spec to container runtime commands   │   │
│   │                           │                             │   │
│   │                           ▼                             │   │
│   │   3. MANAGE containers via Container Runtime Interface  │   │
│   │      (CRI) - create, start, stop, delete containers     │   │
│   │                           │                             │   │
│   │                           ▼                             │   │
│   │   4. MONITOR containers - run probes, check health      │   │
│   │                           │                             │   │
│   │                           ▼                             │   │
│   │   5. REPORT status back to API Server                   │   │
│   │                                                         │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   kubelet ◄──► Container Runtime (containerd/CRI-O)             │
│              │                                                  │
│              └──► Actual containers on the node                 │
└─────────────────────────────────────────────────────────────────┘
```

**What happens when a pod is scheduled to a node:**
```
1. API Server notifies kubelet: "Run this pod"
2. kubelet reads pod spec
3. kubelet pulls container images
4. kubelet tells container runtime to create containers
5. kubelet starts containers
6. kubelet runs probes (liveness/readiness)
7. kubelet reports "Pod Running" to API Server
```

---

#### 2. kube-proxy

**What it is:** Network proxy that runs on each node, implementing Kubernetes Service concepts.

**Responsibilities:**
- Maintains network rules on nodes
- Enables network communication to pods from inside/outside
- Implements service abstraction (stable IP for dynamic pods)

```
┌─────────────────────────────────────────────────────────────────┐
│                        kube-proxy                               │
│              "The Network Rules Manager"                        │
│                                                                 │
│   SERVICE: fastapi-service (ClusterIP: 10.96.45.67)             │
│            ↓ routes to ↓                                        │
│   PODS: 10.244.1.5, 10.244.2.8, 10.244.1.9                      │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                                                         │   │
│   │   Traffic to 10.96.45.67:80 (Service IP)                │   │
│   │                   │                                     │   │
│   │                   ▼                                     │   │
│   │   kube-proxy intercepts (via iptables/IPVS)             │   │
│   │                   │                                     │   │
│   │                   ▼                                     │   │
│   │   Load balance to one of:                               │   │
│   │     ├── 10.244.1.5:8000 (Pod 1)                         │   │
│   │     ├── 10.244.2.8:8000 (Pod 2)                         │   │
│   │     └── 10.244.1.9:8000 (Pod 3)                         │   │
│   │                                                         │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   Modes:                                                        │
│   • iptables (default) - Linux netfilter rules                  │
│   • IPVS - Linux IP Virtual Server (better performance)         │
│   • userspace (legacy) - proxy in user space                    │
└─────────────────────────────────────────────────────────────────┘
```

**Why kube-proxy matters:**
- Pods are ephemeral - their IPs change
- Services provide stable IPs
- kube-proxy makes this magic happen by updating network rules

---

#### 3. Container Runtime

**What it is:** Software responsible for running containers.

**Common Container Runtimes:**
| Runtime | Description |
|---------|-------------|
| **containerd** | Industry-standard, used by EKS, GKE, most clouds |
| **CRI-O** | Lightweight, designed specifically for Kubernetes |
| **Docker** | Deprecated in K8s 1.24+ (but Docker images still work!) |

```
┌─────────────────────────────────────────────────────────────────┐
│                  Container Runtime Interface (CRI)              │
│                                                                 │
│   kubelet ────► CRI ────► containerd ────► Containers           │
│                                                                 │
│   Operations:                                                   │
│   • PullImage     - Download container image                    │
│   • CreateContainer - Set up container                          │
│   • StartContainer  - Run the container                         │
│   • StopContainer   - Gracefully stop                           │
│   • RemoveContainer - Delete container                          │
│   • ContainerStatus - Check if running                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Concepts

### 1. Pod (In Detail)

The **smallest deployable unit** in Kubernetes. A pod represents a single instance of a running process.

```
┌─────────────────────────────────────────────────────────────────┐
│                            POD                                  │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                   Pod Specification                     │   │
│   │                                                         │   │
│   │   • Name: fastapi-pod-abc123                            │   │
│   │   • Namespace: fastapi-dev                              │   │
│   │   • IP Address: 10.244.1.5 (assigned by cluster)        │   │
│   │                                                         │   │
│   │   ┌──────────────┐  ┌──────────────┐                    │   │
│   │   │ Container 1  │  │ Container 2  │  (sidecar)         │   │
│   │   │              │  │              │                    │   │
│   │   │ fastapi:v1   │  │ fluentd:v1   │  (optional)        │   │
│   │   │ Port: 8000   │  │              │                    │   │
│   │   └──────────────┘  └──────────────┘                    │   │
│   │          │                  │                           │   │
│   │          └────────┬─────────┘                           │   │
│   │                   │                                     │   │
│   │   ┌───────────────▼────────────────┐                    │   │
│   │   │       Shared Resources         │                    │   │
│   │   │                                │                    │   │
│   │   │  • Network namespace (same IP) │                    │   │
│   │   │  • Storage volumes             │                    │   │
│   │   │  • IPC namespace               │                    │   │
│   │   └────────────────────────────────┘                    │   │
│   │                                                         │   │
│   └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Pod YAML Example with Explanations:**

```yaml
apiVersion: v1              # API version to use
kind: Pod                   # Type of resource
metadata:
  name: my-pod              # Pod name (must be unique in namespace)
  namespace: default        # Which namespace
  labels:                   # Key-value pairs for organization
    app: fastapi
    version: v1
spec:
  containers:               # List of containers in this pod
    - name: fastapi         # Container name
      image: nginx:1.21     # Docker image to use
      ports:
        - containerPort: 80 # Port the container listens on
      env:                  # Environment variables
        - name: DB_HOST
          value: "postgres"
      resources:            # Resource management
        requests:           # Guaranteed resources
          cpu: "100m"
          memory: "128Mi"
        limits:             # Maximum resources
          cpu: "500m"
          memory: "256Mi"
  restartPolicy: Always     # What to do if container exits
```

**Pod Lifecycle:**

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌───────────┐
│ Pending │ ──►│ Running │ ──►│Succeeded│ OR │  Failed   │
└─────────┘    └─────────┘    └─────────┘    └───────────┘
     │              │
     │              └── Container crashes → Restart (if Always)
     │
     └── Waiting for scheduling or image pull
```

| Phase | Description |
|-------|-------------|
| **Pending** | Pod accepted, but containers not running yet |
| **Running** | At least one container is running |
| **Succeeded** | All containers terminated successfully |
| **Failed** | At least one container failed |
| **Unknown** | Pod state cannot be determined |

**Multi-Container Pod Patterns:**

| Pattern | Use Case | Example |
|---------|----------|---------|
| **Sidecar** | Add functionality to main container | Log collector, monitoring agent |
| **Ambassador** | Proxy to external services | Database proxy |
| **Adapter** | Transform output of main container | Log format converter |

---

### 2. Namespace (In Detail)

Namespaces provide **logical isolation** within a cluster.

```
┌─────────────────────────────────────────────────────────────────┐
│                      KUBERNETES CLUSTER                         │
│                                                                 │
│   ┌────────────────────┐  ┌────────────────────┐                │
│   │   Namespace: dev   │  │  Namespace: prod   │                │
│   │                    │  │                    │                │
│   │  ┌─────────────┐   │  │  ┌─────────────┐   │                │
│   │  │ Deployment  │   │  │  │ Deployment  │   │                │
│   │  │ fastapi     │   │  │  │ fastapi     │   │                │
│   │  │ replicas: 1 │   │  │  │ replicas: 5 │   │                │
│   │  └─────────────┘   │  │  └─────────────┘   │                │
│   │                    │  │                    │                │
│   │  ┌─────────────┐   │  │  ┌─────────────┐   │                │
│   │  │  Service    │   │  │  │  Service    │   │                │
│   │  │  fastapi    │   │  │  │  fastapi    │   │                │
│   │  └─────────────┘   │  │  └─────────────┘   │                │
│   │                    │  │                    │                │
│   │  ResourceQuota:    │  │  ResourceQuota:    │                │
│   │   CPU: 2 cores     │  │   CPU: 20 cores    │                │
│   │   Mem: 4Gi         │  │   Mem: 64Gi        │                │
│   │                    │  │                    │                │
│   └────────────────────┘  └────────────────────┘                │
│                                                                 │
│   ┌────────────────────────────────────────────────────────┐    │
│   │                  Namespace: kube-system                │    │
│   │           (System components - DO NOT MODIFY)          │    │
│   │                                                        │    │
│   │  coredns, kube-proxy, aws-node, metrics-server, etc.   │    │
│   └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

**Default Namespaces Explained:**

| Namespace | Purpose | Can You Use It? |
|-----------|---------|-----------------|
| `default` | Where resources go if you don't specify a namespace | Yes, but not recommended for production |
| `kube-system` | Kubernetes system components (DNS, proxy, etc.) | Don't modify! |
| `kube-public` | Publicly readable resources (rarely used) | Generally leave alone |
| `kube-node-lease` | Node heartbeat data | Don't modify! |

**What Namespaces Provide:**
- Resource isolation
- Access control (RBAC per namespace)
- Resource quotas (limit CPU/memory per namespace)
- Network policies (control traffic between namespaces)

**What Namespaces DON'T Provide:**
- Node isolation (pods still share nodes)
- Security isolation (use Pod Security Policies for that)

---

### 3. Labels and Selectors (In Detail)

Labels are the **primary grouping mechanism** in Kubernetes.

```yaml
# Adding labels to a resource
metadata:
  labels:
    app: fastapi            # Application name
    environment: production # Environment
    version: v2.1.0         # Version
    team: backend           # Owning team
    tier: api               # Application tier
```

**Selector Types:**

```yaml
# Equality-based (exact match)
selector:
  matchLabels:
    app: fastapi
    environment: prod

# Set-based (more flexible)
selector:
  matchExpressions:
    - key: environment
      operator: In
      values: [prod, staging]
    - key: version
      operator: NotIn
      values: [v1.0.0]
    - key: feature-flag
      operator: Exists
```

**How Selectors Work:**

```
┌─────────────────────────────────────────────────────────────────┐
│                         SERVICE                                 │
│   selector:                                                     │
│     app: fastapi                                                │
│     environment: prod                                           │
│                            │                                    │
│                            │ "Find all pods with these labels"  │
│                            ▼                                    │
│   ┌─────────┬─────────┬─────────┬─────────┬─────────┐           │
│   │ Pod A   │ Pod B   │ Pod C   │ Pod D   │ Pod E   │           │
│   │app:     │app:     │app:     │app:     │app:     │           │
│   │fastapi  │fastapi  │nginx    │fastapi  │fastapi  │           │
│   │env:     │env:     │env:     │env:     │env:     │           │
│   │prod     │dev      │prod     │prod     │prod     │           │
│   │         │         │         │         │         │           │
│   │   ✓     │   ✗     │   ✗     │   ✓     │   ✓     │           │
│   │ MATCH   │NO MATCH │NO MATCH │ MATCH   │ MATCH   │           │
│   └─────────┴─────────┴─────────┴─────────┴─────────┘           │
│                                                                 │
│   Service routes traffic only to: Pod A, Pod D, Pod E           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Workload Resources

### Deployment (In Detail)

A Deployment provides **declarative updates** for Pods and ReplicaSets.

**Hierarchy:**
```
Deployment
    │
    │ manages
    ▼
ReplicaSet (current)
    │
    │ maintains
    ▼
Pods (actual running instances)
    
        +
    
ReplicaSet (previous) ◄── Kept for rollback
```

**Rolling Update Process:**

```
STEP 1: Initial State
┌────────────────────────────────────────────┐
│ ReplicaSet v1 (desired: 3, current: 3)     │
│ ┌─────┐ ┌─────┐ ┌─────┐                    │
│ │Pod 1│ │Pod 2│ │Pod 3│     Image: v1.0    │
│ └─────┘ └─────┘ └─────┘                    │
└────────────────────────────────────────────┘

STEP 2: Update triggered (new image: v2.0)
┌────────────────────────────────────────────┐
│ ReplicaSet v1 (desired: 2, current: 3)     │
│ ┌─────┐ ┌─────┐ ┌─────┐                    │
│ │Pod 1│ │Pod 2│ │Pod 3│     Scaling down   │
│ └─────┘ └─────┘ └TERM─┘                    │
│                                            │
│ ReplicaSet v2 (desired: 1, current: 0)     │
│ ┌─────┐                                    │
│ │ NEW │              Creating...           │
│ └─────┘                                    │
└────────────────────────────────────────────┘

STEP 3: Gradual transition
┌────────────────────────────────────────────┐
│ ReplicaSet v1 (desired: 1, current: 2)     │
│ ┌─────┐ ┌─────┐                            │
│ │Pod 1│ │Pod 2│             Scaling down   │
│ └─────┘ └TERM─┘                            │
│                                            │
│ ReplicaSet v2 (desired: 2, current: 1)     │
│ ┌─────┐ ┌─────┐                            │
│ │Pod 4│ │ NEW │             Scaling up     │
│ └─────┘ └─────┘                            │
└────────────────────────────────────────────┘

STEP 4: Complete
┌────────────────────────────────────────────┐
│ ReplicaSet v1 (desired: 0, current: 0)     │
│ (Kept for rollback, no pods)               │
│                                            │
│ ReplicaSet v2 (desired: 3, current: 3)     │
│ ┌─────┐ ┌─────┐ ┌─────┐                    │
│ │Pod 4│ │Pod 5│ │Pod 6│    All v2.0 now!   │
│ └─────┘ └─────┘ └─────┘                    │
└────────────────────────────────────────────┘
```

**Deployment Strategy Options:**

```yaml
spec:
  strategy:
    type: RollingUpdate       # or "Recreate"
    rollingUpdate:
      maxUnavailable: 1       # Max pods that can be unavailable
      maxSurge: 1             # Max extra pods during update
```

| Strategy | Description | Use Case |
|----------|-------------|----------|
| **RollingUpdate** | Gradually replace pods | Zero-downtime updates (default) |
| **Recreate** | Kill all, then create new | When you can't run mixed versions |

---

### Health Checks (Probes) - Deep Dive

```
┌─────────────────────────────────────────────────────────────────┐
│                      PROBE TYPES                                │
│                                                                 │
│   ┌───────────────┐   ┌───────────────┐   ┌───────────────┐     │
│   │   LIVENESS    │   │  READINESS    │   │   STARTUP     │     │
│   │               │   │               │   │               │     │
│   │ "Is it alive?"│   │"Is it ready?" │   │"Has it started│     │
│   │               │   │               │   │ successfully?"│     │
│   │ If NO:        │   │ If NO:        │   │               │     │
│   │ RESTART       │   │ Remove from   │   │ If NO:        │     │
│   │ CONTAINER     │   │ service       │   │ RESTART       │     │
│   │               │   │ endpoints     │   │               │     │
│   └───────────────┘   └───────────────┘   └───────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

**Probe Configuration Explained:**

```yaml
livenessProbe:
  httpGet:
    path: /health           # Endpoint to check
    port: 8000              # Port to check on
    httpHeaders:            # Optional headers
      - name: Custom-Header
        value: Awesome
  initialDelaySeconds: 10   # Wait 10s before first probe
  periodSeconds: 10         # Probe every 10 seconds
  timeoutSeconds: 5         # Probe times out after 5s
  failureThreshold: 3       # Fail after 3 consecutive failures
  successThreshold: 1       # Succeed after 1 success
```

**Timeline Example:**

```
0s    Container starts
      |
10s   First liveness probe (initialDelaySeconds: 10)
      |
      ▼
      Probe 1: HTTP GET /health → 200 OK ✓
      |
20s   Probe 2: HTTP GET /health → 200 OK ✓
      |
30s   Probe 3: HTTP GET /health → 500 Error ✗ (failure 1)
      |
40s   Probe 4: HTTP GET /health → 500 Error ✗ (failure 2)
      |
50s   Probe 5: HTTP GET /health → 500 Error ✗ (failure 3)
      |
      ▼
      CONTAINER RESTARTED! (failureThreshold: 3 reached)
```

---

## Service & Networking

### Service Types (Deep Dive)

```
┌─────────────────────────────────────────────────────────────────┐
│                     SERVICE TYPES COMPARISON                    │
│                                                                 │
│   CLUSTERIP (Default)                                           │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ • Only accessible within the cluster                    │   │
│   │ • Gets a stable internal IP (e.g., 10.96.45.67)         │   │
│   │ • No external access                                    │   │
│   │ • Use: Internal microservices communication             │   │
│   │                                                         │   │
│   │   [Pod A] ──► ClusterIP:80 ──► [Pod B, Pod C, Pod D]    │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   NODEPORT                                                      │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ • Exposes service on each node's IP at a static port    │   │
│   │ • Port range: 30000-32767                               │   │
│   │ • Access: <NodeIP>:<NodePort>                           │   │
│   │ • Use: Development, debugging                           │   │
│   │                                                         │   │
│   │   Internet ──► Node1:30080 ──► Service ──► Pods         │   │
│   │             ──► Node2:30080 ──►                         │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   LOADBALANCER                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ • Creates external load balancer (cloud-specific)       │   │
│   │ • Gets public IP from cloud provider                    │   │
│   │ • Use: Production traffic                               │   │
│   │                                                         │   │
│   │   Internet ──► AWS ALB/NLB ──► Service ──► Pods         │   │
│   │                (Public IP)                              │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   EXTERNALNAME                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ • Maps service to external DNS name                     │   │
│   │ • No proxying, just DNS CNAME record                    │   │
│   │ • Use: Reference external services                      │   │
│   │                                                         │   │
│   │   [Pod] ──► my-db-service ──► external-db.example.com   │   │
│   └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Port Forward (Development Access):**

```bash
# Forward local port 8000 to service port 80
kubectl port-forward service/fastapi-service 8000:80 -n fastapi-dev

# What happens:
# localhost:8000 ──► kubectl tunnel ──► Service:80 ──► Pod:8000
```

---

## Configuration Management

### ConfigMap vs Secret

```
┌─────────────────────────────────────────────────────────────────┐
│               CONFIGMAP vs SECRET                               │
│                                                                 │
│   ┌─────────────────────────┐   ┌─────────────────────────┐     │
│   │       CONFIGMAP         │   │         SECRET          │     │
│   │                         │   │                         │     │
│   │  • Non-sensitive data   │   │  • Sensitive data       │     │
│   │  • Plain text           │   │  • Base64 encoded       │     │
│   │  • No encryption        │   │  • Optional encryption  │     │
│   │                         │   │    (EncryptionConfig)   │     │
│   │  Examples:              │   │                         │     │
│   │  - Feature flags        │   │  Examples:              │     │
│   │  - Config files         │   │  - Passwords            │     │
│   │  - Environment URLs     │   │  - API keys             │     │
│   │  - Log levels           │   │  - TLS certificates     │     │
│   │                         │   │  - SSH keys             │     │
│   └─────────────────────────┘   └─────────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

**Ways to Use ConfigMaps/Secrets:**

```yaml
# Method 1: As environment variables
env:
  - name: DATABASE_URL
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: DATABASE_URL

# Method 2: As volume mount (files)
volumes:
  - name: config-volume
    configMap:
      name: app-config
volumeMounts:
  - name: config-volume
    mountPath: /etc/config

# Method 3: All keys as environment variables
envFrom:
  - configMapRef:
      name: app-config
```

---

## Kustomize

### Why Kustomize?

```
WITHOUT Kustomize:
┌───────────────────────────────────────────────────────────┐
│                                                           │
│   deployment-dev.yaml   ◄── Copy of deployment            │
│   deployment-test.yaml  ◄── Copy with small changes       │
│   deployment-prod.yaml  ◄── Copy with different changes   │
│                                                           │
│   Problems:                                               │
│   • Duplicate code                                        │
│   • Easy to miss updates                                  │
│   • Hard to maintain                                      │
└───────────────────────────────────────────────────────────┘

WITH Kustomize:
┌───────────────────────────────────────────────────────────┐
│                                                           │
│   base/                                                   │
│   └── deployment.yaml   ◄── Single source of truth        │
│                                                           │
│   overlays/                                               │
│   ├── dev/              ◄── Only the differences          │
│   ├── test/             ◄── Only the differences          │
│   └── prod/             ◄── Only the differences          │
│                                                           │
│   Benefits:                                               │
│   • DRY (Don't Repeat Yourself)                           │
│   • Easy to maintain                                      │
│   • Git-friendly                                          │
└───────────────────────────────────────────────────────────┘
```

---

## The Kubernetes API

### Manifest Structure

Every Kubernetes manifest follows this structure:

```yaml
apiVersion: <group>/<version>   # Which API to use
kind: <resource-type>           # What to create
metadata:                       # Identification
  name: <name>
  namespace: <namespace>
  labels: <labels>
  annotations: <annotations>
spec:                           # Desired state
  <resource-specific-fields>
status:                         # Actual state (read-only)
  <managed-by-kubernetes>
```

**Common API Groups:**

| API Version | Resources |
|-------------|-----------|
| `v1` | Pod, Service, ConfigMap, Secret, Namespace |
| `apps/v1` | Deployment, ReplicaSet, StatefulSet, DaemonSet |
| `batch/v1` | Job, CronJob |
| `networking.k8s.io/v1` | Ingress, NetworkPolicy |
| `rbac.authorization.k8s.io/v1` | Role, ClusterRole, RoleBinding |

---

## Common kubectl Commands

### Quick Reference

```bash
# ─────────────────────────────────────────────────────────────────
# CLUSTER & NODES
# ─────────────────────────────────────────────────────────────────
kubectl cluster-info                    # Cluster info
kubectl get nodes                       # List nodes
kubectl describe node <name>            # Node details
kubectl top nodes                       # Node resource usage

# ─────────────────────────────────────────────────────────────────
# PODS
# ─────────────────────────────────────────────────────────────────
kubectl get pods                        # List pods (default ns)
kubectl get pods -n <namespace>         # List pods in namespace
kubectl get pods -A                     # All namespaces
kubectl get pods -o wide                # More details (node, IP)
kubectl get pods -w                     # Watch for changes

kubectl describe pod <name>             # Full details
kubectl logs <pod>                      # View logs
kubectl logs <pod> -f                   # Follow logs
kubectl logs <pod> -c <container>       # Specific container
kubectl logs <pod> --previous           # Previous container logs

kubectl exec -it <pod> -- /bin/sh       # Shell into pod
kubectl exec <pod> -- <command>         # Run command

kubectl delete pod <name>               # Delete pod
kubectl delete pod <name> --force       # Force delete

# ─────────────────────────────────────────────────────────────────
# DEPLOYMENTS
# ─────────────────────────────────────────────────────────────────
kubectl get deployments                 # List deployments
kubectl describe deployment <name>     # Deployment details

kubectl scale deployment <name> --replicas=5    # Scale
kubectl set image deployment/<name> <container>=<image>  # Update image

kubectl rollout status deployment/<name>       # Watch rollout
kubectl rollout history deployment/<name>      # Rollout history
kubectl rollout undo deployment/<name>         # Rollback
kubectl rollout undo deployment/<name> --to-revision=2  # Specific

kubectl rollout restart deployment/<name>      # Restart all pods

# ─────────────────────────────────────────────────────────────────
# SERVICES
# ─────────────────────────────────────────────────────────────────
kubectl get services                    # List services
kubectl describe service <name>         # Service details
kubectl port-forward service/<name> 8000:80  # Local access

# ─────────────────────────────────────────────────────────────────
# DEBUGGING
# ─────────────────────────────────────────────────────────────────
kubectl get events --sort-by=.lastTimestamp  # Recent events
kubectl top pods                        # Pod resource usage
kubectl run debug --rm -it --image=busybox -- /bin/sh  # Debug pod

# ─────────────────────────────────────────────────────────────────
# APPLY & DELETE
# ─────────────────────────────────────────────────────────────────
kubectl apply -f <file.yaml>            # Apply manifest
kubectl apply -k <kustomization-dir>    # Apply Kustomization
kubectl delete -f <file.yaml>           # Delete from manifest
kubectl delete -k <kustomization-dir>   # Delete Kustomization
kubectl diff -f <file.yaml>             # Preview changes
```

---

## Project Manifests Explained

See the actual manifest files in `k8s/` directory with detailed inline comments.

---

## Best Practices

### 1. Resource Management
```yaml
# ALWAYS set resource limits to prevent noisy neighbors
resources:
  requests:
    cpu: "100m"         # What you expect to use
    memory: "128Mi"
  limits:
    cpu: "500m"         # Maximum allowed
    memory: "256Mi"     # OOMKilled if exceeded
```

### 2. Health Probes
```yaml
# ALWAYS add probes for production
livenessProbe:          # Restart if unhealthy
  httpGet:
    path: /health
    port: 8000
readinessProbe:         # Don't send traffic if not ready
  httpGet:
    path: /health
    port: 8000
```

### 3. Labels
```yaml
# Use consistent, meaningful labels
labels:
  app.kubernetes.io/name: fastapi
  app.kubernetes.io/version: "1.0.0"
  app.kubernetes.io/component: api
  app.kubernetes.io/part-of: my-application
  app.kubernetes.io/managed-by: kustomize
```

### 4. Security
```yaml
# Run as non-root
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
```

### 5. Use Namespaces
```bash
# Separate environments
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace prod
```

---

## Further Reading

- [Kubernetes Official Documentation](https://kubernetes.io/docs/)
- [Kubernetes Patterns Book](https://k8spatterns.io/)
- [Kustomize Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [CKAD/CKA Certification](https://www.cncf.io/certification/cka/)
