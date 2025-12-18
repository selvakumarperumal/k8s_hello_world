# Helm Package Manager Guide

A comprehensive guide to Helm, the package manager for Kubernetes.

---

## 📋 Table of Contents

1. [What is Helm?](#what-is-helm)
2. [Helm Architecture](#helm-architecture)
3. [Charts Explained](#charts-explained)
4. [Installing Helm](#installing-helm)
5. [Working with Charts](#working-with-charts)
6. [Creating Custom Charts](#creating-custom-charts)
7. [Values and Templating](#values-and-templating)
8. [Release Management](#release-management)
9. [Helm Repositories](#helm-repositories)
10. [Best Practices](#best-practices)

---

## What is Helm?

Helm is the **package manager for Kubernetes**. It helps you define, install, and upgrade complex Kubernetes applications.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Why Use Helm?                                     │
│                                                                      │
│   WITHOUT Helm:                                                      │
│   ┌───────────────────────────────────────────────────────────────┐ │
│   │  deployment.yaml    service.yaml    configmap.yaml            │ │
│   │  ingress.yaml       secrets.yaml    hpa.yaml                  │ │
│   │  pdb.yaml           networkpolicy.yaml  serviceaccount.yaml   │ │
│   │                                                               │ │
│   │  kubectl apply -f deployment.yaml                             │ │
│   │  kubectl apply -f service.yaml                                │ │
│   │  kubectl apply -f configmap.yaml                              │ │
│   │  ... repeat for each environment ...                          │ │
│   │                                                               │ │
│   │  ❌ Manual management of many files                            │ │
│   │  ❌ No versioning or rollback                                  │ │
│   │  ❌ Duplicated configs per environment                         │ │
│   └───────────────────────────────────────────────────────────────┘ │
│                                                                      │
│   WITH Helm:                                                         │
│   ┌───────────────────────────────────────────────────────────────┐ │
│   │  helm install myapp ./mychart -f values-prod.yaml             │ │
│   │                                                               │ │
│   │  ✓ Single command deployment                                   │ │
│   │  ✓ Version history and rollback                                │ │
│   │  ✓ Environment-specific values                                 │ │
│   │  ✓ Dependency management                                       │ │
│   │  ✓ Templating for DRY configs                                  │ │
│   └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Chart** | A Helm package containing Kubernetes resource definitions |
| **Release** | An instance of a chart running in a cluster |
| **Repository** | A collection of charts (like npm registry) |
| **Values** | Configuration parameters for customizing charts |

---

## Helm Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Helm 3 Architecture                             │
│                                                                      │
│   ┌────────────────┐                                                 │
│   │   Helm CLI     │  ◄── You run: helm install, upgrade, etc.      │
│   └───────┬────────┘                                                 │
│           │                                                          │
│           │ Renders templates + values                               │
│           ▼                                                          │
│   ┌────────────────┐                                                 │
│   │   Chart +      │  ◄── Templates + Values = Kubernetes YAML      │
│   │   Values       │                                                 │
│   └───────┬────────┘                                                 │
│           │                                                          │
│           │ Applies manifests                                        │
│           ▼                                                          │
│   ┌────────────────┐                                                 │
│   │  Kubernetes    │  ◄── Stores release info as Secrets            │
│   │    Cluster     │                                                 │
│   └────────────────┘                                                 │
└─────────────────────────────────────────────────────────────────────┘
```

**Note**: Helm 3 removed Tiller (the server component). Helm now communicates directly with the Kubernetes API.

---

## Charts Explained

### Chart Structure

```
mychart/
├── Chart.yaml          # Chart metadata (name, version, description)
├── values.yaml         # Default configuration values
├── charts/             # Chart dependencies
├── templates/          # Kubernetes manifest templates
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── _helpers.tpl    # Template helpers (partials)
│   ├── NOTES.txt       # Post-install instructions
│   └── tests/          # Helm test hooks
│       └── test-connection.yaml
├── .helmignore         # Files to ignore when packaging
└── README.md           # Chart documentation
```

### Chart.yaml

```yaml
apiVersion: v2                    # Helm 3 uses v2
name: fastapi-app                 # Chart name
description: FastAPI Hello World application
type: application                 # application or library
version: 1.0.0                    # Chart version (SemVer)
appVersion: "1.0.0"              # Application version

# Dependencies (optional)
dependencies:
  - name: redis
    version: "17.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled

# Maintainers
maintainers:
  - name: Your Name
    email: you@example.com

# Keywords for search
keywords:
  - fastapi
  - python
  - api
```

### values.yaml

```yaml
# Default values for fastapi-app

replicaCount: 2

image:
  repository: nginx
  tag: "1.25"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: nginx
  hosts:
    - host: api.example.com
      paths:
        - path: /
          pathType: Prefix

resources:
  limits:
    cpu: 500m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

nodeSelector: {}
tolerations: []
affinity: {}
```

---

## Installing Helm

### macOS

```bash
brew install helm
```

### Linux

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Verify Installation

```bash
helm version
# version.BuildInfo{Version:"v3.14.0", ...}
```

---

## Working with Charts

### Install a Chart

```bash
# Install from repository
helm install my-release bitnami/nginx

# Install from local chart
helm install my-release ./mychart

# Install with custom values
helm install my-release ./mychart -f values-prod.yaml

# Install with value overrides
helm install my-release ./mychart --set replicaCount=3

# Install in specific namespace
helm install my-release ./mychart -n production --create-namespace

# Dry run (preview without installing)
helm install my-release ./mychart --dry-run --debug
```

### Upgrade a Release

```bash
# Upgrade with new chart version
helm upgrade my-release ./mychart

# Upgrade with new values
helm upgrade my-release ./mychart -f values-prod.yaml

# Upgrade or install if not exists
helm upgrade --install my-release ./mychart

# Atomic upgrade (rollback on failure)
helm upgrade my-release ./mychart --atomic

# Wait for resources to be ready
helm upgrade my-release ./mychart --wait --timeout 5m
```

### Rollback

```bash
# View release history
helm history my-release

# Rollback to previous revision
helm rollback my-release

# Rollback to specific revision
helm rollback my-release 2
```

### Uninstall

```bash
# Uninstall release
helm uninstall my-release

# Uninstall and keep history
helm uninstall my-release --keep-history
```

### List and Status

```bash
# List all releases
helm list

# List in all namespaces
helm list -A

# Get release status
helm status my-release

# Get release values
helm get values my-release

# Get all release info
helm get all my-release
```

---

## Creating Custom Charts

### Create New Chart

```bash
# Create chart scaffold
helm create fastapi-app

# This creates:
fastapi-app/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── serviceaccount.yaml
│   ├── _helpers.tpl
│   └── NOTES.txt
└── charts/
```

### Customize Templates

#### templates/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "fastapi-app.fullname" . }}
  labels:
    {{- include "fastapi-app.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "fastapi-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "fastapi-app.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.targetPort }}
          {{- with .Values.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if .Values.healthCheck.enabled }}
          livenessProbe:
            httpGet:
              path: {{ .Values.healthCheck.path }}
              port: {{ .Values.service.targetPort }}
            initialDelaySeconds: 10
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: {{ .Values.healthCheck.path }}
              port: {{ .Values.service.targetPort }}
            initialDelaySeconds: 5
            periodSeconds: 5
          {{- end }}
```

#### templates/_helpers.tpl

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "fastapi-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "fastapi-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "fastapi-app.labels" -}}
helm.sh/chart: {{ include "fastapi-app.chart" . }}
{{ include "fastapi-app.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "fastapi-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fastapi-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

---

## Values and Templating

### Template Syntax

```yaml
# Access values
{{ .Values.replicaCount }}

# Access chart metadata
{{ .Chart.Name }}
{{ .Chart.Version }}

# Access release info
{{ .Release.Name }}
{{ .Release.Namespace }}

# Conditionals
{{- if .Values.ingress.enabled }}
  # ... ingress config
{{- end }}

# Loops
{{- range .Values.ingress.hosts }}
  - host: {{ .host }}
{{- end }}

# Default values
{{ .Values.image.tag | default "latest" }}

# Required values (fail if not set)
{{ required "image.repository is required" .Values.image.repository }}

# Include templates
{{ include "myapp.fullname" . }}

# Format as YAML
{{- toYaml .Values.resources | nindent 12 }}
```

### Multi-Environment Values

```bash
# base values.yaml - defaults
# values-dev.yaml - development overrides
# values-prod.yaml - production overrides

# Install for development
helm install myapp ./mychart -f values.yaml -f values-dev.yaml

# Install for production
helm install myapp ./mychart -f values.yaml -f values-prod.yaml
```

#### values-dev.yaml

```yaml
replicaCount: 1

image:
  tag: "dev"

resources:
  limits:
    cpu: 200m
    memory: 128Mi

ingress:
  enabled: false
```

#### values-prod.yaml

```yaml
replicaCount: 5

image:
  tag: "v1.0.0"

resources:
  limits:
    cpu: 1000m
    memory: 512Mi

ingress:
  enabled: true
  hosts:
    - host: api.production.com
      paths:
        - path: /
          pathType: Prefix

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
```

---

## Release Management

### View History

```bash
helm history my-release
# REVISION  UPDATED                   STATUS      DESCRIPTION
# 1         Mon Dec 18 10:00:00 2024  deployed    Install complete
# 2         Mon Dec 18 11:00:00 2024  deployed    Upgrade complete
# 3         Mon Dec 18 12:00:00 2024  deployed    Upgrade complete
```

### Rollback

```bash
# Rollback to previous version
helm rollback my-release

# Rollback to specific revision
helm rollback my-release 2

# Rollback with options
helm rollback my-release 2 --timeout 5m --wait
```

### Release Secrets

Helm stores release info as Kubernetes Secrets:

```bash
kubectl get secrets -l owner=helm

# View release manifest
kubectl get secret sh.helm.release.v1.my-release.v1 -o jsonpath='{.data.release}' | base64 -d | gzip -d
```

---

## Helm Repositories

### Add Repositories

```bash
# Add Bitnami repo
helm repo add bitnami https://charts.bitnami.com/bitnami

# Add ingress-nginx repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Add Prometheus community
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Update repos
helm repo update

# List repos
helm repo list
```

### Search Charts

```bash
# Search all repos
helm search repo nginx

# Search with versions
helm search repo nginx --versions

# Search Artifact Hub
helm search hub prometheus
```

### Create Private Repository

```bash
# Package chart
helm package ./mychart

# Create index
helm repo index . --url https://charts.example.com

# Host on S3, GitHub Pages, or ChartMuseum
```

---

## Best Practices

### 1. Version Your Charts

```yaml
# Chart.yaml
version: 1.2.3     # Chart version - bump on any change
appVersion: "2.0.0" # App version - matches your Docker image
```

### 2. Use Semantic Versioning

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

### 3. Validate Before Deploy

```bash
# Lint chart
helm lint ./mychart

# Template locally
helm template my-release ./mychart

# Dry run install
helm install my-release ./mychart --dry-run --debug
```

### 4. Use Named Templates

```yaml
# _helpers.tpl
{{- define "myapp.labels" -}}
app: {{ .Chart.Name }}
version: {{ .Chart.AppVersion }}
{{- end }}

# In templates
metadata:
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
```

### 5. Document Your Values

```yaml
# values.yaml

# -- Number of replicas for the deployment
replicaCount: 2

# -- Image configuration
image:
  # -- Container image repository
  repository: nginx
  # -- Container image tag
  tag: "1.25"
```

### 6. Use Helm Tests

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "myapp.fullname" . }}-test-connection"
  annotations:
    "helm.sh/hook": test
spec:
  containers:
    - name: wget
      image: busybox
      command: ['wget']
      args: ['{{ include "myapp.fullname" . }}:{{ .Values.service.port }}']
  restartPolicy: Never
```

```bash
# Run tests
helm test my-release
```

---

## Helm Commands Reference

```bash
# ─────────────────────────────────────────────────────────────────
# RELEASES
# ─────────────────────────────────────────────────────────────────
helm install <name> <chart>         # Install chart
helm upgrade <name> <chart>         # Upgrade release
helm uninstall <name>               # Uninstall release
helm rollback <name> [revision]     # Rollback release
helm list                           # List releases
helm status <name>                  # Release status
helm history <name>                 # Release history
helm get all <name>                 # Get all release info
helm get values <name>              # Get release values
helm get manifest <name>            # Get release manifests

# ─────────────────────────────────────────────────────────────────
# CHARTS
# ─────────────────────────────────────────────────────────────────
helm create <name>                  # Create chart scaffold
helm package <chart-path>           # Package chart to .tgz
helm lint <chart-path>              # Lint chart
helm template <name> <chart>        # Render templates locally
helm show all <chart>               # Show chart info
helm show values <chart>            # Show chart values
helm dependency update <chart>      # Update dependencies
helm dependency build <chart>       # Build dependencies

# ─────────────────────────────────────────────────────────────────
# REPOSITORIES
# ─────────────────────────────────────────────────────────────────
helm repo add <name> <url>          # Add repo
helm repo remove <name>             # Remove repo
helm repo update                    # Update repos
helm repo list                      # List repos
helm search repo <keyword>          # Search repos
helm search hub <keyword>           # Search Artifact Hub
```

---

## Next Steps

Now that you understand Helm:

1. **Create a chart** for the FastAPI app
2. **Deploy to different environments** using values files
3. **Learn NGINX Ingress** for traffic routing: [NGINX Ingress Guide →](NGINX_INGRESS.md)

---

## Further Reading

- [Helm Official Documentation](https://helm.sh/docs/)
- [Chart Development Guide](https://helm.sh/docs/chart_template_guide/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Artifact Hub](https://artifacthub.io/) - Public chart repository
