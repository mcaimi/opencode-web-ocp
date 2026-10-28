# opencode-web-ocp

[![Docker Repository on Quay](https://quay.io/repository/marcocaimi/opencode-web-ocp/status "Docker Repository on Quay")](https://quay.io/repository/marcocaimi/opencode-web-ocp)

Deploy [opencode web](https://github.com/anomalyco/opencode) as a containerized web service on OpenShift.

`opencode` is an AI-powered IDE-like terminal interface. This project wraps it for OpenShift deployment, connecting to an OpenShift-hosted LLM inference endpoint.

## Project structure

| File/Directory | Purpose |
|---|---|
| `Containerfile` | Multi-stage image build — downloads the opencode binary (v2, pinned via the `OPENCODE_VERSION` build arg) for multiple architectures, packages into UBI minimal. Downloads the code-security skill from GitHub. Home dir is `/home/opencode`. User runs as `opencode` (uid arbitrary, gid 0 for OpenShift compatibility) |
| `scripts/entry.sh` | Entrypoint script (installed as `/usr/local/bin/entrypoint`) — substitutes env vars into the opencode config, displays proxy settings, then launches `opencode serve` from `/workspace` |
| `config/opencode.json` | OpenCode v2 config (points to OpenShift LLM via the built-in `@opencode/ai/providers/openai-compatible` package), placed in `/home/opencode/.config/opencode/` |
| `config/cli.json` | OpenCode v2 TUI/CLI settings (theme), placed in `/home/opencode/.config/opencode/` |
| `agents/` | Custom opencode subagents (`deep-security-auditor.md`, `git-repo-analyst.md`, `wikipedia-researcher.md`) placed in `/home/opencode/.config/opencode/agents/` |
| `helm/` | Helm chart for OpenShift deployment with proxy support, persistent storage, and edge-terminated routes |

## How runtime config works

At container start, `entry.sh` uses `jq` to replace the placeholder key `OPENSHIFT_DEPLOYED_MODEL_NAME` in `opencode.json` with the value of the `MODEL_NAME` env var.

**Never edit `opencode.json` directly.** The placeholder is substituted at runtime from environment variables.

## Build

Build the container image:

```bash
podman build -t opencode-web-ocp -f Containerfile .

# pick a different opencode release
podman build --build-arg OPENCODE_VERSION=2.2.0 -t opencode-web-ocp -f Containerfile .
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
| `SERVER_PASSWORD` | `redhat` | OpenCode web UI password (exported as `OPENCODE_PASSWORD`; username is always `opencode`) |
| `DISABLE_AUTOUPDATE` | `true` | Disable auto-update (legacy name `OPENCODE_AUTOUPDATE` is still read) |
| `APIKEY` | (empty) | OpenShift vLLM API key (maps to `OPENSHIFT_AI_VLLM_API_KEY`) |
| `CONFIG_FILE` | `/home/opencode/.config/opencode/opencode.json` | Path to opencode config file |
| `HOST` | local IP / `localhost` | Bind address (auto-resolved from `hostname -i`) |
| `WORKDIR` | `/workspace` | Directory the server starts in (default project) |
| `PORT` | `8080` | Listen port |
| `HTTP_PROXY` | (unset) | HTTP proxy URL (displayed at startup) |
| `HTTPS_PROXY` | (unset) | HTTPS proxy URL (displayed at startup) |
| `NO_PROXY` | (unset) | Comma-separated list of domains to exclude from proxy |

## Helm Chart Deployment

A complete Helm chart is available in the `helm/` directory with support for:

- Dedicated ServiceAccount (`opencode-sa`)
- Optional PersistentVolumeClaims for `/workspace` and the opencode session database
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
- The web UI pages (`/`) are public; every `/api/*` request needs basic auth (`opencode` / `SERVER_PASSWORD`), e.g. `curl -u opencode:$SERVER_PASSWORD http://<host>:8080/api/info`
- Container runs as unprivileged user `opencode` (uid arbitrary, gid 0 for OpenShift)
- The entrypoint script displays proxy settings (HTTP_PROXY, HTTPS_PROXY, NO_PROXY) at startup for troubleshooting
- Custom subagents in `agents/` directory are automatically placed in `/home/opencode/.config/opencode/agents/`
- No additional packages can be installed at runtime (runs as non-root)
- The `code-security` skill is pre-installed from the semgrep/skills repo at image build time
