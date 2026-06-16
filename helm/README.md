# Opencode Web Helm Chart

This Helm chart deploys the Opencode Web application with OpenChamber on OpenShift.

## What's New in v0.2.0

- **OpenChamber Integration**: The application now runs with OpenChamber, providing an enhanced web interface for OpenCode
- **Ripgrep Support**: Added ripgrep for improved code search capabilities
- **Node.js Runtime**: Included Node.js runtime for enhanced functionality
- **Separate Data Storage**: Optional persistent volume for OpenChamber configuration and data
- **API-Only Mode**: New `API_ONLY` environment variable to run in API-only mode

## Prerequisites

- OpenShift cluster 4.x or later
- Helm 3.x or later
- `oc` CLI logged into your OpenShift cluster

## Installation

### Basic Installation

```bash
helm install opencode-web ./helm
```

### Installation with Custom Values

```bash
helm install opencode-web ./helm \
  --set route.hostname=opencode.apps.example.com \
  --set persistence.enabled=true \
  --set persistence.size=2Gi
```

### Installation with Custom Values File

Create a custom values file:

```yaml
# custom-values.yaml
route:
  hostname: opencode.apps.example.com

persistence:
  enabled: true
  size: 5Gi
  storageClassName: ocs-storagecluster-ceph-rbd

env:
  - name: OPENCODE_SERVER_PASSWORD
    value: "mypassword"
  - name: OPENSHIFT_LLM_INFERENCE_ENDPOINT
    value: "http://my-inference-service.namespace.svc:8080"
```

Install with the custom values:

```bash
helm install opencode-web ./helm -f custom-values.yaml
```

## Configuration

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Container image repository | `quay.io/marcocaimi/opencode-web-ocp` |
| `image.tag` | Container image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `serviceAccount.name` | ServiceAccount name | `opencode-sa` |
| `route.enabled` | Enable OpenShift Route | `true` |
| `route.hostname` | Route hostname (optional) | `""` |
| `route.tls.termination` | TLS termination type | `edge` |
| `persistence.enabled` | Enable persistent storage for workspace | `false` |
| `persistence.size` | PVC size for workspace | `1Gi` |
| `persistence.storageClassName` | Storage class name for workspace | `""` |
| `persistence.mountPath` | Mount path in container | `/workspace` |
| `openchamber.persistence.enabled` | Enable persistent storage for OpenChamber data | `false` |
| `openchamber.persistence.size` | PVC size for OpenChamber data | `1Gi` |
| `openchamber.persistence.storageClassName` | Storage class name for OpenChamber | `""` |
| `openchamber.persistence.mountPath` | OpenChamber data mount path | `/home/opencode/.config/openchamber` |
| `proxy.enabled` | Enable proxy configuration | `false` |
| `proxy.httpProxy` | HTTP proxy URL | `""` |
| `proxy.httpsProxy` | HTTPS proxy URL | `""` |
| `proxy.noProxy` | Custom NO_PROXY list (overrides defaults) | `""` |
| `proxy.additionalNoProxy` | Additional domains to exclude from proxy | `[]` |

### Environment Variables

The following environment variables can be customized via `env` array in values.yaml:

- `OPENCODE_AUTOUPDATE`: Enable/disable automatic updates (default: `true`)
- `SERVER_PASSWORD`: Web UI password for OpenChamber (default: `redhat`)
- `API_ONLY`: Run OpenChamber in API-only mode, no UI (default: `0`)
- `INFERENCE_ENDPOINT`: LLM inference endpoint URL (default: `http://inference.apps.openshift.local`)
- `MODEL_NAME`: Model name to use (default: `qwen-coder`)
- `APIKEY`: API key for LLM inference endpoint (default: `""`)

### Proxy Configuration

The chart supports corporate proxy environments with automatic Kubernetes/OpenShift NO_PROXY exclusions.

**Default NO_PROXY exclusions** (when `proxy.enabled: true` and `proxy.noProxy` is not set):
- `localhost`, `127.0.0.1`, `.local`
- `.svc`, `.svc.cluster.local` (all Kubernetes services)
- `kubernetes.default.svc` (Kubernetes API server)
- Service CIDR: `10.96.0.0/12` (configurable via `proxy.kubernetes.serviceCIDR`)
- Pod CIDR: `10.244.0.0/16` (configurable via `proxy.kubernetes.podCIDR`)

**Example: Basic proxy setup**
```yaml
proxy:
  enabled: true
  httpProxy: "http://proxy.example.com:8080"
  httpsProxy: "http://proxy.example.com:8080"
```

**Example: Proxy with additional exclusions**
```yaml
proxy:
  enabled: true
  httpProxy: "http://proxy.example.com:8080"
  httpsProxy: "http://proxy.example.com:8080"
  additionalNoProxy:
    - ".internal.corp"
    - "registry.example.com"
    - "192.168.0.0/16"
```

**Example: Custom NO_PROXY (overrides all defaults)**
```yaml
proxy:
  enabled: true
  httpProxy: "http://proxy.example.com:8080"
  httpsProxy: "http://proxy.example.com:8080"
  noProxy: "localhost,127.0.0.1,.svc,.internal"
```

**Example: Adjusting Kubernetes CIDRs for OpenShift**
```yaml
proxy:
  enabled: true
  httpProxy: "http://proxy.example.com:8080"
  httpsProxy: "http://proxy.example.com:8080"
  kubernetes:
    serviceCIDR: "172.30.0.0/16"    # OpenShift default service network
    podCIDR: "10.128.0.0/14"         # OpenShift default pod network
    apiServer: "kubernetes.default.svc.cluster.local"
```

**Command-line installation with proxy:**
```bash
helm install opencode-web ./helm \
  --set proxy.enabled=true \
  --set proxy.httpProxy=http://proxy.example.com:8080 \
  --set proxy.httpsProxy=http://proxy.example.com:8080 \
  --set proxy.additionalNoProxy[0]=.internal.corp
```

## Features

### Service Account

The chart creates a dedicated service account (`opencode-sa`) for enhanced security and RBAC management.

### Persistent Storage (Optional)

The chart supports two types of persistent storage:

1. **Workspace Storage** (`/workspace`): For user project files and code
2. **OpenChamber Data Storage** (`/home/opencode/.config/openchamber`): For OpenChamber configuration and session data

Enable workspace persistence:

```bash
helm install opencode-web ./helm \
  --set persistence.enabled=true \
  --set persistence.size=2Gi \
  --set persistence.storageClassName=gp2
```

Enable OpenChamber data persistence (recommended for production):

```bash
helm install opencode-web ./helm \
  --set openchamber.persistence.enabled=true \
  --set openchamber.persistence.size=1Gi \
  --set openchamber.persistence.storageClassName=gp2
```

Enable both:

```bash
helm install opencode-web ./helm \
  --set persistence.enabled=true \
  --set persistence.size=5Gi \
  --set openchamber.persistence.enabled=true \
  --set openchamber.persistence.size=2Gi \
  --set persistence.storageClassName=gp2
```

### OpenShift Route

An edge-terminated route is automatically created for external access. You can customize the hostname:

```bash
helm install opencode-web ./helm \
  --set route.hostname=opencode.apps.example.com
```

If no hostname is specified, OpenShift will generate one automatically.

## Upgrade

To upgrade an existing release:

```bash
helm upgrade opencode-web ./helm -f custom-values.yaml
```

## Uninstall

To remove the deployment:

```bash
helm uninstall opencode-web
```

Note: PersistentVolumeClaims are not automatically deleted and must be removed manually if needed:

```bash
# Delete workspace PVC
oc delete pvc opencode-web

# Delete OpenChamber data PVC (if enabled)
oc delete pvc opencode-web-openchamber
```

## Accessing the Application

After installation, get the route URL:

```bash
oc get route opencode-web
```

Or use:

```bash
echo "https://$(oc get route opencode-web -o jsonpath='{.spec.host}')"
```

Access the application using the displayed URL with the configured password.

## Security

The chart implements OpenShift security best practices:

- Runs as non-root user
- Uses dedicated service account
- Drops all capabilities
- Disables privilege escalation
- Uses SecComp runtime/default profile

## Troubleshooting

### Check pod status

```bash
oc get pods -l app.kubernetes.io/name=opencode-web
```

### View logs

```bash
oc logs -l app.kubernetes.io/name=opencode-web
```

### Describe deployment

```bash
oc describe deployment opencode-web
```

### Test connectivity

```bash
oc port-forward svc/opencode-web 8080:8080
```

Then access http://localhost:8080
