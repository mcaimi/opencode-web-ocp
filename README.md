# opencode-web-ocp

[![Docker Repository on Quay](https://quay.io/repository/marcocaimi/opencode-web-ocp/status "Docker Repository on Quay")](https://quay.io/repository/marcocaimi/opencode-web-ocp)

Deploy [opencode web](https://github.com/anomalyco/opencode) as a containerized web service on OpenShift via [openchamber](https://github.com/openchamber/openchamber).

`opencode` is an AI-powered IDE-like terminal interface. `openchamber` is a lightweight server wrapper that provides multi-session support and improved stability. This project wraps both for OpenShift deployment, connecting to an OpenShift-hosted LLM inference endpoint.

## Project structure

| File/Directory | Purpose |
|---|---|
| `Containerfile.openchamber` | Multi-stage image build — downloads the pinned opencode v2 binary (`OPENCODE_VERSION`, default 2.2.0, checksum-verified) and ripgrep (`RIPGREP_VERSION`, default 15.2.0) for multiple architectures, installs Node.js 24 and `@openchamber/web` (`OPENCHAMBER_VERSION`, default 2.5.2) via npm, packages into UBI minimal. Downloads skills from GitHub. Home dir is `/home/opencode`. User runs as `opencode` (uid arbitrary, gid 0 for OpenShift compatibility) |
| `scripts/entry.sh` | Entrypoint script (installed as `/usr/local/bin/entrypoint`) — substitutes env vars into the opencode config, displays proxy settings, then launches `openchamber serve` (which spawns and manages `opencode serve` for multi-session support) |
| `config/opencode.json` | OpenCode v2 config (`providers.openshift` points to the OpenShift LLM via the `aisdk:@ai-sdk/openai-compatible` package), placed in `/home/opencode/.config/opencode/` |
| `config/cli.json` | OpenCode v2 CLI/TUI settings (theme), replaces the v1 `tui.json` |
| `agents/` | Custom opencode subagents (`deep-security-auditor.md`, `git-repo-analyst.md`, `wikipedia-researcher.md`) placed in `/home/opencode/.config/opencode/agents/` |
| `container-compose.yml` | Local test setup with podman/docker compose |
| `helm/` | Helm chart for OpenShift deployment with proxy support, persistent storage, and edge-terminated routes |

## How runtime config works

At container start, `entry.sh` uses `jq` to rename the (first) model key under `providers.openshift.models` — initially the placeholder `OPENSHIFT_DEPLOYED_MODEL_NAME` — to the value of the `MODEL_NAME` env var, sets the default `model` to `openshift/$MODEL_NAME` and sets `update` from `OPENCODE_AUTOUPDATE`. Because it always renames the current key, restarting with a different `MODEL_NAME` works.

**Never edit `opencode.json` directly.** The placeholder is substituted at runtime from environment variables.

## Build

Build the container image:

```bash
podman build -t opencode-web-ocp -f Containerfile.openchamber .

# override pinned versions
podman build -t opencode-web-ocp -f Containerfile.openchamber \
  --build-arg OPENCODE_VERSION=2.2.0 \
  --build-arg OPENCHAMBER_VERSION=2.5.2 .
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

Imports the published image, injects env vars, and creates the route:

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
| `OPENCODE_AUTOUPDATE` | `false` | Enable auto-update (`true`/`1`); sets `update` in `opencode.json` and `OPENCODE_DISABLE_AUTOUPDATE` |
| `API_ONLY` | `0` | Set to `1` to run openchamber in API-only mode (`--api-only`, no web UI) |
| `APIKEY` | (empty) | OpenShift vLLM API key (maps to `OPENSHIFT_AI_VLLM_API_KEY`) |
| `CONFIG_FILE` | `/home/opencode/.config/opencode/opencode.json` | Path to opencode config file (exported as `OPENCODE_CONFIG` when set) |
| `WORKDIR` | `/workspace` | Working directory openchamber is started from |
| `OPENCODE_DB` | `/home/opencode/.local/share/opencode/opencode.db` | opencode v2 state database (sessions, provider credentials) |
| `OPENCHAMBER_DATA_DIR` | `/home/opencode/.config/openchamber` | openchamber data directory |
| `HOST` | local IP / `localhost` | Bind address (auto-resolved from `hostname -i`) |
| `PORT` | `8080` | Listen port |
| `HTTP_PROXY` | (unset) | HTTP proxy URL (displayed at startup) |
| `HTTPS_PROXY` | (unset) | HTTPS proxy URL (displayed at startup) |
| `NO_PROXY` | (unset) | Comma-separated list of domains to exclude from proxy (`localhost,127.0.0.1,::1` is always appended) |

## Helm Chart Deployment

A complete Helm chart is available in the `helm/` directory with support for:

- Dedicated ServiceAccount (`opencode-sa`)
- Optional PersistentVolumeClaim for `/workspace`
- Edge-terminated OpenShift Route with customizable hostname
- **HTTP/HTTPS proxy support** with automatic Kubernetes/OpenShift NO_PROXY exclusions
- Configurable resources, replicas, health checks
- `SERVER_PASSWORD` / `APIKEY` injected from a Secret (`auth.*` values or `auth.existingSecret`)
- Optional PersistentVolumeClaims for openchamber data and opencode state (`opencode.db`)
- Probes on the unauthenticated openchamber `/health` endpoint

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
  --set auth.serverPassword=yourpassword \
  --set auth.apiKey=your-api-key

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
- `openchamber` 2.x requires the opencode v2 server (>= 2.1.0) and Node.js >= 24.14; it spawns `opencode serve` on `127.0.0.1` itself and generates the internal opencode password
- `GET /health` on port 8080 is unauthenticated and used for health checks
- opencode v2 stores provider credentials in `opencode.db`; a legacy `auth.json` is only imported once, so pass the inference key via `APIKEY`
- opencode v2 no longer runs language servers (`lsp`), and `tui.json` has been replaced by `cli.json`
- `ripgrep` (`rg`) is included for fast code search capabilities
- Node.js 24 runtime is included for openchamber and skill dependencies
