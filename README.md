# opencode-web-ocp

Deploy [opencode web](https://github.com/anomalyco/opencode) as a containerized web service on OpenShift.

`opencode` is an AI-powered IDE-like terminal interface. This project wraps it for OpenShift deployment, connecting to an OpenShift-hosted LLM inference endpoint.

## Project structure

| File/Directory | Purpose |
|---|---|
| `Containerfile` | Multi-stage image build — downloads the opencode binary for multiple architectures, packages into UBI minimal. Home dir is `/tmp/opencode`. User runs as `opencode` (uid arbitrary, gid 0 for OpenShift compatibility) |
| `scripts/entry.sh` | Entrypoint script (installed as `/usr/local/bin/entrypoint`) — subs env vars into the opencode config, displays proxy settings, exports config path, then launches `opencode web` |
| `config/opencode.json` | OpenCode config (points to OpenShift LLM via `@ai-sdk/openai-compatible` adapter), placed in `/tmp/opencode/.config/opencode/` |
| `config/auth.json` | Placeholder auth config (uses `"key": "none"` — override at runtime), placed in `/tmp/opencode/.local/share/opencode/` |
| `agents/` | Custom opencode agents/subagents, copied to `/tmp/opencode/.config/opencode/agents/` |
| `helm/` | Helm chart for OpenShift deployment with proxy support, persistent storage, and edge-terminated routes |

## How runtime config works

At container start, `entry.sh` uses `jq` to replace two placeholder keys in `opencode.json`:

- `OPENSHIFT_DEPLOYED_MODEL_NAME` → actual model name (env var, default `qwen-coder`)
- `OPENSHIFT_LLM_INFERENCE_ENDPOINT` → actual LLM API URL (env var, default `http://inference.apps.openshift.local`)

**Never edit `opencode.json` directly.** The placeholders are substituted at runtime from environment variables.

## Build

Build the container image:

```bash
podman build -t opencode-web-ocp -f Containerfile .
```

## Run

### Local testing (podman)

```bash
podman run -p 8080:8080 \
  -e OPENSHIFT_LLM_INFERENCE_ENDPOINT=http://your-llm-endpoint \
  -e OPENSHIFT_DEPLOYED_MODEL_NAME=your-model \
  opencode-web-ocp
```

### Deploy on OpenShift

First, get the inference service URL:

```bash
INFERENCE_URL=$(oc get inferenceservice qwen3-coder -o jsonpath="{.status.url}")
```

#### 3-step deploy (recommended)

```bash
oc new-app --name=opencode-web-ocp
oc env dc/opencode-web-ocp \
  OPENSHIFT_LLM_INFERENCE_ENDPOINT=$INFERENCE_URL \
  OPENSHIFT_DEPLOYED_MODEL_NAME=qwen3-coder
oc create route edge --service=opencode-web-ocp --insecure-policy=Redirect
```

#### One-liner deploy

Builds from the local Containerfile, injects env vars, and creates the route:

```bash
INFERENCE_URL=$(oc get inferenceservice qwen3-coder -o jsonpath="{.status.url}") && \

# import image or build it yourself
oc import-image quay.io/marcocaimi/opencode-web-ocp:latest

oc new-app -i opencode-web-ocp --name=opencode-web-ocp \
  -e OPENSHIFT_LLM_INFERENCE_ENDPOINT=$INFERENCE_URL \
  -e OPENSHIFT_DEPLOYED_MODEL_NAME=qwen3-coder \
  && oc create route edge --service=opencode-web-ocp --insecure-policy=Redirect
```

### Mounting auth.json as a secret

The default `auth.json` contains `"key": "none"` — for production use, mount a real auth config as a secret:

```bash
oc create secret generic opencode-auth --from-file=auth.json=/path/to/your/auth.json
```

Then add a volume and volume mount to your deployment:

**Via `oc patch` (existing deployment):**

```bash
oc patch dc/opencode-web-ocp --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/volumes/0", "value": {"name": "opencode-auth", "secret": {"secretName": "opencode-auth"}}}]'

oc patch dc/opencode-web-ocp --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts/0", "value": {"name": "opencode-auth", "mountPath": "/home/opencode/.local/share/opencode", "subPath": "auth.json", "readOnly": true}}]'
```

**Via `oc new-app` (new deployment):**

```bash
INFERENCE_URL=$(oc get inferenceservice qwen3-coder -o jsonpath="{.status.url}") && \

oc new-app -i opencode-web-ocp --name=opencode-web-ocp \
  -e OPENSHIFT_LLM_INFERENCE_ENDPOINT=$INFERENCE_URL \
  -e OPENSHIFT_DEPLOYED_MODEL_NAME=qwen3-coder \
  --volume name=opencode-auth,type=secret,secretName=opencode-auth,target=/home/opencode/.local/share/opencode \
  && oc create route edge --service=opencode-web-ocp --insecure-policy=Redirect
```

## Configuration

| Environment Variable | Default | Description |
|---|---|---|
| `OPENSHIFT_DEPLOYED_MODEL_NAME` | `qwen-coder` | Actual model name to use in `opencode.json` |
| `OPENSHIFT_LLM_INFERENCE_ENDPOINT` | `http://inference.apps.openshift.local` | LLM API base URL |
| `HOST` | local IP / `localhost` | Bind address (auto-resolved from `hostname -i`) |
| `PORT` | `8080` | Listen port |
| `OPENCODE_SERVER_PASSWORD` | `redhat` | OpenCode web UI password |
| `OPENCODE_DISABLE_AUTOUPDATE` | `true` | Disable auto-update |
| `HTTP_PROXY` | (unset) | HTTP proxy URL (displayed at startup) |
| `HTTPS_PROXY` | (unset) | HTTPS proxy URL (displayed at startup) |
| `NO_PROXY` | (unset) | Comma-separated list of domains to exclude from proxy |
| `JSON_FILE` | `/tmp/opencode/.config/opencode/opencode.json` | Path to opencode config file |

## Helm Chart Deployment

A complete Helm chart is available in the `helm/` directory with support for:

- Dedicated ServiceAccount (`opencode-sa`)
- Optional PersistentVolumeClaim for `/tmp/opencode`
- Edge-terminated OpenShift Route with customizable hostname
- **HTTP/HTTPS proxy support** with automatic Kubernetes/OpenShift NO_PROXY exclusions
- Configurable resources, replicas, health checks

See [helm/README.md](helm/README.md) for installation instructions and [helm/PROXY-EXAMPLES.md](helm/PROXY-EXAMPLES.md) for proxy configuration scenarios.

### Quick Helm Install

```bash
# Basic installation
helm install opencode-web ./helm \
  --set route.hostname=opencode.apps.your-cluster.com

# With proxy support
helm install opencode-web ./helm \
  --set route.hostname=opencode.apps.your-cluster.com \
  --set proxy.enabled=true \
  --set proxy.httpProxy=http://proxy.corp.example.com:8080 \
  --set proxy.httpsProxy=http://proxy.corp.example.com:8080
```

## Gotchas

- `opencode.json` uses placeholder values that are replaced at container start by `entry.sh`
- `auth.json` contains dummy credentials (`"key": "none"`) — mount a real auth file to override
- Container runs as unprivileged user `opencode` (uid arbitrary, gid 0 for OpenShift)
- The entrypoint script displays proxy settings (HTTP_PROXY, HTTPS_PROXY, NO_PROXY) at startup for troubleshooting
- Custom agents in `agents/` directory are automatically copied to `/tmp/opencode/.config/opencode/agents/`
- No additional packages can be installed at runtime (runs as non-root)
