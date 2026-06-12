# Proxy Configuration Examples

This document provides detailed examples for configuring HTTP/HTTPS proxy settings in the Opencode Web Helm chart.

## Understanding NO_PROXY Behavior

The chart automatically configures `NO_PROXY` to exclude Kubernetes/OpenShift internal services from proxying when `proxy.enabled: true`. This prevents routing internal cluster traffic through external proxies.

### Default NO_PROXY Exclusions

When you enable proxy without specifying `proxy.noProxy`, the following are automatically excluded:

```
localhost,127.0.0.1,.local,.svc,.svc.cluster.local,kubernetes.default.svc,10.96.0.0/12,10.244.0.0/16
```

These defaults include:
- **localhost/127.0.0.1**: Local loopback
- **.local**: mDNS/Bonjour services
- **.svc, .svc.cluster.local**: All Kubernetes services
- **kubernetes.default.svc**: Kubernetes API server
- **10.96.0.0/12**: Default Kubernetes service CIDR
- **10.244.0.0/16**: Default Kubernetes pod CIDR

## Scenario 1: Basic Proxy Configuration

Use this for a simple corporate proxy setup with default Kubernetes exclusions.

```yaml
proxy:
  enabled: true
  httpProxy: "http://proxy.corp.example.com:8080"
  httpsProxy: "http://proxy.corp.example.com:8080"
```

**Generated NO_PROXY:**
```
localhost,127.0.0.1,.local,.svc,.svc.cluster.local,kubernetes.default.svc,10.96.0.0/12,10.244.0.0/16
```

**Install command:**
```bash
helm install opencode-web ./helm \
  --set proxy.enabled=true \
  --set proxy.httpProxy=http://proxy.corp.example.com:8080 \
  --set proxy.httpsProxy=http://proxy.corp.example.com:8080
```

## Scenario 2: Proxy with Additional Corporate Domains

Add your internal corporate domains to the default exclusions.

```yaml
proxy:
  enabled: true
  httpProxy: "http://proxy.corp.example.com:8080"
  httpsProxy: "http://proxy.corp.example.com:8080"
  additionalNoProxy:
    - ".internal.corp"
    - ".cluster.internal"
    - "registry.internal.corp"
    - "artifactory.corp.example.com"
```

**Generated NO_PROXY:**
```
localhost,127.0.0.1,.local,.svc,.svc.cluster.local,kubernetes.default.svc,10.96.0.0/12,10.244.0.0/16,.internal.corp,.cluster.internal,registry.internal.corp,artifactory.corp.example.com
```

## Scenario 3: OpenShift-Specific Network Configuration

OpenShift uses different default CIDRs than vanilla Kubernetes. Adjust the network ranges to match your cluster.

```yaml
proxy:
  enabled: true
  httpProxy: "http://proxy.corp.example.com:8080"
  httpsProxy: "http://proxy.corp.example.com:8080"
  kubernetes:
    serviceCIDR: "172.30.0.0/16"   # OpenShift default service network
    podCIDR: "10.128.0.0/14"        # OpenShift default pod network
    apiServer: "kubernetes.default.svc.cluster.local"
```

**Generated NO_PROXY:**
```
localhost,127.0.0.1,.local,.svc,.svc.cluster.local,kubernetes.default.svc.cluster.local,172.30.0.0/16,10.128.0.0/14
```

**How to find your cluster's network CIDRs:**

```bash
# Service CIDR
oc get network.config.openshift.io cluster -o jsonpath='{.spec.serviceNetwork[*]}'

# Pod CIDR
oc get network.config.openshift.io cluster -o jsonpath='{.spec.clusterNetwork[*].cidr}'
```

## Scenario 4: Proxy with Private Subnets

Exclude private network ranges (RFC 1918) when your infrastructure uses private IPs.

```yaml
proxy:
  enabled: true
  httpProxy: "http://proxy.corp.example.com:8080"
  httpsProxy: "http://proxy.corp.example.com:8080"
  additionalNoProxy:
    - "10.0.0.0/8"      # Private Class A
    - "172.16.0.0/12"   # Private Class B
    - "192.168.0.0/16"  # Private Class C
    - ".internal"
```

## Scenario 5: Authenticated Proxy

For proxies requiring authentication, include credentials in the URL.

```yaml
proxy:
  enabled: true
  httpProxy: "http://username:password@proxy.corp.example.com:8080"
  httpsProxy: "http://username:password@proxy.corp.example.com:8080"
```

**Security Note:** For production, use Kubernetes secrets instead:

```bash
# Create a secret
kubectl create secret generic proxy-credentials \
  --from-literal=http-proxy='http://username:password@proxy.corp.example.com:8080' \
  --from-literal=https-proxy='http://username:password@proxy.corp.example.com:8080'
```

Then reference it in a custom deployment template or use an init container to inject the values.

## Scenario 6: Custom NO_PROXY (Override All Defaults)

When you need complete control over NO_PROXY, set it explicitly. This **replaces** all defaults.

```yaml
proxy:
  enabled: true
  httpProxy: "http://proxy.corp.example.com:8080"
  httpsProxy: "http://proxy.corp.example.com:8080"
  noProxy: "localhost,127.0.0.1,.svc,.internal,.corp,10.0.0.0/8"
```

**Generated NO_PROXY:** (exactly as specified)
```
localhost,127.0.0.1,.svc,.internal,.corp,10.0.0.0/8
```

**Warning:** When using custom `noProxy`, ensure you include all necessary Kubernetes/OpenShift exclusions!

## Scenario 7: Different Proxies for HTTP and HTTPS

Use separate proxy servers for HTTP and HTTPS traffic.

```yaml
proxy:
  enabled: true
  httpProxy: "http://http-proxy.corp.example.com:8080"
  httpsProxy: "http://https-proxy.corp.example.com:8443"
```

## Scenario 8: Complete Production Example

A realistic production configuration combining multiple features.

```yaml
replicaCount: 2

image:
  repository: quay.io/marcocaimi/opencode-web-ocp
  tag: "v1.16.2"
  pullPolicy: IfNotPresent

route:
  enabled: true
  hostname: "opencode.apps.prod.corp.example.com"

persistence:
  enabled: true
  size: 5Gi
  storageClassName: "ocs-storagecluster-ceph-rbd"

proxy:
  enabled: true
  httpProxy: "http://proxy.prod.corp.example.com:8080"
  httpsProxy: "http://proxy.prod.corp.example.com:8080"
  
  # OpenShift network configuration
  kubernetes:
    serviceCIDR: "172.30.0.0/16"
    podCIDR: "10.128.0.0/14"
    apiServer: "api.prod.ocp.corp.example.com"
  
  # Additional corporate exclusions
  additionalNoProxy:
    - ".internal.corp"
    - ".apps.prod.corp.example.com"
    - "registry.internal.corp"
    - "artifactory.corp.example.com"
    - "10.0.0.0/8"
    - "172.16.0.0/12"
    - "192.168.0.0/16"

env:
  - name: OPENCODE_SERVER_PASSWORD
    valueFrom:
      secretKeyRef:
        name: opencode-credentials
        key: password
  - name: OPENSHIFT_LLM_INFERENCE_ENDPOINT
    value: "http://inference-service.ai-platform.svc.cluster.local:8080"
  - name: OPENSHIFT_DEPLOYED_MODEL_NAME
    value: "qwen-coder"

resources:
  limits:
    cpu: 2000m
    memory: 4Gi
  requests:
    cpu: 1000m
    memory: 2Gi
```

## Testing Proxy Configuration

### Verify Generated NO_PROXY

```bash
helm template opencode-web ./helm -f your-values.yaml | grep -A 1 "name: NO_PROXY"
```

### Test Proxy Connectivity

After deployment, test that the proxy is being used:

```bash
# Get pod name
POD=$(oc get pod -l app.kubernetes.io/name=opencode-web -o jsonpath='{.items[0].metadata.name}')

# Check environment variables
oc exec $POD -- env | grep -i proxy

# Test external connectivity (should go through proxy)
oc exec $POD -- curl -v https://api.github.com

# Test internal connectivity (should bypass proxy)
oc exec $POD -- curl -v http://kubernetes.default.svc
```

## Troubleshooting

### Proxy Not Working

1. Verify proxy settings are applied:
   ```bash
   oc get deployment opencode-web -o yaml | grep -A 5 proxy
   ```

2. Check proxy environment variables in pod:
   ```bash
   oc exec <pod-name> -- env | grep -E "(http|https|no)_proxy"
   ```

3. Test proxy connectivity from pod:
   ```bash
   oc exec <pod-name> -- curl -x $HTTP_PROXY -v https://www.google.com
   ```

### Internal Services Being Proxied

If Kubernetes services are incorrectly being routed through the proxy:

1. Verify NO_PROXY includes `.svc` and `.svc.cluster.local`
2. Check that service/pod CIDRs match your cluster configuration
3. Ensure NO_PROXY is properly formatted (comma-separated, no spaces)

### Certificate Issues with HTTPS Proxy

If using an HTTPS proxy with self-signed certificates, you may need to:

1. Mount CA certificates into the container
2. Set `NODE_EXTRA_CA_CERTS` or similar environment variables
3. Configure the application to trust your corporate CA

## References

- [Kubernetes Proxy Configuration](https://kubernetes.io/docs/concepts/cluster-administration/proxies/)
- [OpenShift Network Configuration](https://docs.openshift.com/container-platform/latest/networking/understanding-networking.html)
- [RFC 1918 - Private Address Space](https://datatracker.ietf.org/doc/html/rfc1918)
