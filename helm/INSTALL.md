# Quick Start Installation Guide

This guide provides step-by-step instructions to deploy Opencode Web on OpenShift.

## Prerequisites

- OpenShift cluster 4.x or later
- `oc` CLI installed and logged in
- `helm` 3.x or later installed
- Access to create projects/namespaces

## Installation Steps

### 1. Create a Namespace

```bash
oc new-project opencode-web
```

### 2. Basic Installation (No Proxy)

For environments without a proxy:

```bash
helm install opencode-web ./helm \
  --set route.hostname=opencode.apps.your-cluster.com
```

### 3. Installation with Proxy

For corporate environments requiring a proxy:

```bash
# Get your cluster's network CIDRs
SERVICE_CIDR=$(oc get network.config.openshift.io cluster -o jsonpath='{.spec.serviceNetwork[0]}')
POD_CIDR=$(oc get network.config.openshift.io cluster -o jsonpath='{.spec.clusterNetwork[0].cidr}')

echo "Service CIDR: $SERVICE_CIDR"
echo "Pod CIDR: $POD_CIDR"

# Install with proxy configuration
helm install opencode-web ./helm \
  --set route.hostname=opencode.apps.your-cluster.com \
  --set proxy.enabled=true \
  --set proxy.httpProxy=http://proxy.corp.example.com:8080 \
  --set proxy.httpsProxy=http://proxy.corp.example.com:8080 \
  --set proxy.kubernetes.serviceCIDR=$SERVICE_CIDR \
  --set proxy.kubernetes.podCIDR=$POD_CIDR
```

### 4. Installation with Persistence

To enable persistent storage:

```bash
# List available storage classes
oc get storageclasses

# Install with persistence
helm install opencode-web ./helm \
  --set route.hostname=opencode.apps.your-cluster.com \
  --set persistence.enabled=true \
  --set persistence.size=5Gi \
  --set persistence.storageClassName=gp3-csi
```

### 5. Installation with Custom Values File

Create a custom values file:

```bash
cat > my-values.yaml <<EOF
route:
  hostname: opencode.apps.your-cluster.com

persistence:
  enabled: true
  size: 5Gi
  storageClassName: gp3-csi

proxy:
  enabled: true
  httpProxy: "http://proxy.corp.example.com:8080"
  httpsProxy: "http://proxy.corp.example.com:8080"
  kubernetes:
    serviceCIDR: "172.30.0.0/16"
    podCIDR: "10.128.0.0/14"
  additionalNoProxy:
    - ".internal.corp"
    - "registry.internal.corp"

env:
  - name: OPENCODE_SERVER_PASSWORD
    value: "my-secure-password"
  - name: OPENSHIFT_LLM_INFERENCE_ENDPOINT
    value: "http://my-inference-service.namespace.svc:8080"

resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 1000m
    memory: 1Gi
EOF

# Install with custom values
helm install opencode-web ./helm -f my-values.yaml
```

## Post-Installation

### 1. Check Deployment Status

```bash
# Watch deployment
oc get deployment opencode-web -w

# Check pod status
oc get pods -l app.kubernetes.io/name=opencode-web

# View logs
oc logs -l app.kubernetes.io/name=opencode-web --tail=50 -f
```

### 2. Get the Application URL

```bash
# Get route hostname
ROUTE_URL=$(oc get route opencode-web -o jsonpath='{.spec.host}')
echo "Application URL: https://$ROUTE_URL"

# Or use this one-liner
oc get route opencode-web
```

### 3. Access the Application

Open the URL in your browser:
```bash
https://<route-hostname>
```

Default credentials:
- Password: `redhat` (or your custom value from `OPENCODE_SERVER_PASSWORD`)

### 4. Verify Proxy Configuration (if enabled)

```bash
# Get pod name
POD=$(oc get pod -l app.kubernetes.io/name=opencode-web -o jsonpath='{.items[0].metadata.name}')

# Check proxy environment variables
oc exec $POD -- env | grep -i proxy

# Test external connectivity
oc exec $POD -- curl -I https://github.com

# Test internal connectivity (should bypass proxy)
oc exec $POD -- curl -I http://kubernetes.default.svc
```

## Common Configuration Scenarios

### Change Password

```bash
helm upgrade opencode-web ./helm \
  --reuse-values \
  --set env[1].value=new-password
```

### Enable Persistence After Installation

```bash
helm upgrade opencode-web ./helm \
  --reuse-values \
  --set persistence.enabled=true \
  --set persistence.size=5Gi \
  --set persistence.storageClassName=gp3-csi
```

### Update Proxy Settings

```bash
helm upgrade opencode-web ./helm \
  --reuse-values \
  --set proxy.httpProxy=http://new-proxy.corp.example.com:8080 \
  --set proxy.httpsProxy=http://new-proxy.corp.example.com:8080
```

### Scale Replicas

```bash
helm upgrade opencode-web ./helm \
  --reuse-values \
  --set replicaCount=3
```

## Troubleshooting

### Pod Not Starting

```bash
# Describe pod to see events
oc describe pod -l app.kubernetes.io/name=opencode-web

# Check pod logs
oc logs -l app.kubernetes.io/name=opencode-web

# Check events
oc get events --sort-by='.lastTimestamp'
```

### Route Not Accessible

```bash
# Check route configuration
oc get route opencode-web -o yaml

# Test service connectivity
oc port-forward svc/opencode-web 8080:8080
# Then access http://localhost:8080
```

### Storage Issues

```bash
# Check PVC status
oc get pvc

# Describe PVC
oc describe pvc opencode-web

# Check available storage classes
oc get storageclasses
```

### Proxy Issues

```bash
# Check deployment environment variables
oc get deployment opencode-web -o yaml | grep -A 20 "env:"

# Test proxy from within pod
POD=$(oc get pod -l app.kubernetes.io/name=opencode-web -o jsonpath='{.items[0].metadata.name}')
oc exec $POD -- curl -v -x $HTTP_PROXY https://www.google.com
```

## Uninstallation

### Remove Deployment

```bash
helm uninstall opencode-web
```

### Remove PVC (if persistence was enabled)

```bash
oc delete pvc opencode-web
```

### Remove Namespace

```bash
oc delete project opencode-web
```

## Next Steps

- Review [README.md](README.md) for detailed configuration options
- Check [PROXY-EXAMPLES.md](PROXY-EXAMPLES.md) for advanced proxy scenarios
- See [values-proxy-example.yaml](values-proxy-example.yaml) for a complete example

## Support

For issues and questions:
- GitHub Issues: https://github.com/anomalyco/opencode/issues
- Documentation: https://docs.opencode.dev
