# opencode-web-ocp

Deploy [opencode web](https://github.com/anomalyco/opencode) as a containerized web service on OpenShift.

`opencode` is an AI-powered IDE-like terminal interface. This project wraps it for OpenShift deployment, connecting to an OpenShift-hosted LLM inference endpoint.

## Project structure

| File | Purpose |
|---|---|
| `Containerfile` | Multi-stage image build — downloads the opencode binary, packages into UBI minimal |
| `entry.sh` | Entrypoint script — subs env vars into the opencode config, then launches `opencode web` |
| `opencode.json` | OpenCode config (points to OpenShift LLM via `@ai-sdk/openai-compatible` adapter) |
| `auth.json` | Placeholder auth config (uses `"key": "none"` — override at runtime) |

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

```bash
oc new-app --name=opencode-web-ocp
oc env dc/opencode-web-ocp \
  OPENSHIFT_LLM_INFERENCE_ENDPOINT=http://inference.apps.openshift.local \
  OPENSHIFT_DEPLOYED_MODEL_NAME=qwen-coder
oc create route edge --service=opencode-web-ocp --insecure-policy=Redirect
```

## Configuration

| Environment Variable | Default | Description |
|---|---|---|
| `OPENSHIFT_DEPLOYED_MODEL_NAME` | `qwen-coder` | Model name key in `opencode.json` |
| `OPENSHIFT_LLM_INFERENCE_ENDPOINT` | `http://inference.apps.openshift.local` | LLM API base URL |
| `HOST` | `0.0.0.0` | Bind address |
| `PORT` | `8080` | Listen port |
| `OPENSHIFT_SERVER_PASSWORD` | `redhat` | OpenShift auth password |
| `OPENCODE_DISABLE_AUTOUPDATE` | `true` | Disable auto-update |

## Gotchas

- `opencode.json` uses placeholder values that are replaced at container start
- `auth.json` contains dummy credentials — mount a real auth file to override
- Container runs as unprivileged user `opencode`; no additional packages can be installed
