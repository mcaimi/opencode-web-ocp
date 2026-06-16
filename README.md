# opencode-web-ocp

[![Docker Repository on Quay](https://quay.io/repository/marcocaimi/opencode-web-ocp/status "Docker Repository on Quay")](https://quay.io/repository/marcocaimi/opencode-web-ocp)

Deploy [opencode web](https://github.com/anomalyco/opencode) as a containerized web service on OpenShift via [openchamber](https://github.com/btriapitsyn/openchamber).

`opencode` is an AI-powered IDE-like terminal interface. `openchamber` is a lightweight server wrapper that provides multi-session support and improved stability. This project wraps both for OpenShift deployment, connecting to an OpenShift-hosted LLM inference endpoint.

## Project structure

| File/Directory | Purpose |
|---|---|
| `Containerfile` | Multi-stage image build — downloads opencode binary (v1.17.4), ripgrep (v15.1.0), and installs openchamber for multiple architectures, packages into UBI minimal. Installs Node.js runtime. Downloads the code-security skill from GitHub. Home dir is `/home/opencode`. User runs as `opencode` (uid arbitrary, gid 0 for OpenShift compatibility) |
| `scripts/entry.sh` | Entrypoint script (installed as `/usr/local/bin/entrypoint`) — substitutes env vars into the opencode config, displays proxy settings, then launches `openchamber serve` (which wraps opencode for multi-session support) |
| `config/opencode.json` | OpenCode config (points to OpenShift LLM via `@ai-sdk/openai-compatible` adapter), placed in `/home/opencode/.config/opencode/` |
| `agents/` | Custom opencode subagents (`git-summary.md`, `security-auditor.md`) placed in `/home/opencode/.config/opencode/agents/` |
| `helm/` | Helm chart for OpenShift deployment with proxy support, persistent storage, and edge-terminated routes |

## How runtime config works

At container start, `entry.sh` uses `jq` to replace the placeholder key `OPENSHIFT_DEPLOYED_MODEL_NAME` in `opencode.json` with the value of the `MODEL_NAME` env var.

**Never edit `opencode.json` directly.** The placeholder is substituted at runtime from environment variables.

## Build

Build the container image:

```bash
podman build -t opencode-web-ocp -f Containerfile .
```

## Run

### Local testing (podman)

```bash
podman run -p 8080:8080 \
  -e INFERENCE_ENDPOINT=http://your-llm-endpoint \
  -e MODEL_NAME=qwen-coder \
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
  INFERENCE_ENDPOINT=$INFERENCE_URL \
  MODEL_NAME=qwen-coder \
  SERVER_PASSWORD=yourpassword
oc create route edge --service=opencode-web-ocp --insecure-policy=Redirect
```

#### One-liner deploy

Builds from the local Containerfile, injects env vars, and creates the route:

```bash
INFERENCE_URL=$(oc get inferenceservice qwen3-coder -o jsonpath="{.status.url}") && \

# import image or build it yourself
oc import-image quay.io/marcocaimi/opencode-web-ocp:latest

oc new-app -i opencode-web-ocp --name=opencode-web-ocp \
  -e INFERENCE_ENDPOINT=$INFERENCE_URL \
  -e MODEL_NAME=qwen-coder \
  && oc create route edge --service=opencode-web-ocp --insecure-policy=Redirect
```

## Configuration

| Environment Variable | Default | Description |
|---|---|---|
| `INFERENCE_ENDPOINT` | `http://inference.apps.openshift.local` | LLM API base URL |
| `MODEL_NAME` | `qwen-coder` | Model name to use in `opencode.json` |
| `SERVER_PASSWORD` | `redhat` | OpenCode/OpenChamber web UI password (maps to `OPENCHAMBER_UI_PASSWORD`) |
| `OPENCODE_AUTOUPDATE` | `true` | Enable/disable auto-update |
| `API_ONLY` | `0` | Set to `1` to run openchamber in API-only mode (no web UI) |
| `APIKEY` | (empty) | OpenShift vLLM API key (maps to `OPENSHIFT_AI_VLLM_API_KEY`) |
| `CONFIG_FILE` | `/home/opencode/.config/opencode/opencode.json` | Path to opencode config file |
| `HOST` | local IP / `localhost` | Bind address (auto-resolved from `hostname -i`) |
| `PORT` | `8080` | Listen port |
| `HTTP_PROXY` | (unset) | HTTP proxy URL (displayed at startup) |
| `HTTPS_PROXY` | (unset) | HTTPS proxy URL (displayed at startup) |
| `NO_PROXY` | (unset) | Comma-separated list of domains to exclude from proxy |

## Helm Chart Deployment

A complete Helm chart is available in the `helm/` directory with support for:

- Dedicated ServiceAccount (`opencode-sa`)
- Optional PersistentVolumeClaim for `/workspace`
- Edge-terminated OpenShift Route with customizable hostname
- **HTTP/HTTPS proxy support** with automatic Kubernetes/OpenShift NO_PROXY exclusions
- Configurable resources, replicas, health checks
- API key support via `APIKEY` env var

See [helm/README.md](helm/README.md) for installation instructions and [helm/PROXY-EXAMPLES.md](helm/PROXY-EXAMPLES.md) for proxy configuration scenarios.

### Quick Helm Install

```bash
# Basic installation
helm install opencode-web ./helm \
  --set route.hostname=opencode.apps.your-cluster.com

# With inference endpoint and API key
helm install opencode-web ./helm \
  --set route.hostname=opencode.apps.your-cluster.com \
  --set env[0].name=INFERENCE_ENDPOINT \
  --set env[0].value=http://your-inference-endpoint \
  --set env[1].name=MODEL_NAME \
  --set env[1].value=qwen-coder \
  --set env[2].name=APIKEY \
  --set env[2].value=your-api-key

# With proxy support
helm install opencode-web ./helm \
  --set route.hostname=opencode.apps.your-cluster.com \
  --set proxy.enabled=true \
  --set proxy.httpProxy=http://proxy.corp.example.com:8080 \
  --set proxy.httpsProxy=http://proxy.corp.example.com:8080
```

## Gotchas

- `opencode.json` uses placeholder values that are replaced at container start by `entry.sh`
- Container runs as unprivileged user `opencode` (uid arbitrary, gid 0 for OpenShift)
- The entrypoint script displays proxy settings (HTTP_PROXY, HTTPS_PROXY, NO_PROXY) at startup for troubleshooting
- Custom subagents in `agents/` directory are automatically placed in `/home/opencode/.config/opencode/agents/`
- No additional packages can be installed at runtime (runs as non-root)
- The `code-security` skill is pre-installed from the semgrep/skills repo at image build time
- `openchamber` wraps opencode to provide multi-session support and improved stability — server runs as `openchamber serve` instead of `opencode serve`
- `ripgrep` (`rg`) is included for fast code search capabilities
- Node.js runtime is included for openchamber and skill dependencies
