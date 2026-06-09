# opencode-web-ocp

Deploy [opencode web](https://github.com/anomalyco/opencode) as a containerized web service on OpenShift.

`opencode` is an AI-powered IDE-like terminal interface. This project wraps it for OpenShift deployment, connecting to an OpenShift-hosted LLM inference endpoint.

## Project structure

| File | Purpose |
|---|---|
| `Containerfile` | Multi-stage image build — downloads the opencode binary for multiple architectures, packages into UBI minimal. Home dir is `/tmp/opencode` |
| `entry.sh` | Entrypoint script (as `entrypoint`) — subs env vars into the opencode config, exports config path, then launches `opencode web` |
| `opencode.json` | OpenCode config (points to OpenShift LLM via `@ai-sdk/openai-compatible` adapter), placed in `/tmp/opencode/.config/opencode/` |
| `auth.json` | Placeholder auth config (uses `"key": "none"` — override at runtime), placed in `/tmp/opencode/.local/share/opencode/` |

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
| `HOST` | local IP / `localhost` | Bind address (auto-resolved) |
| `PORT` | `8080` | Listen port |
| `OPENCODE_SERVER_PASSWORD` | `redhat` | OpenShift auth password |
| `OPENCODE_DISABLE_AUTOUPDATE` | `true` | Disable auto-update |

## Gotchas

- `opencode.json` uses placeholder values that are replaced at container start
- `auth.json` contains dummy credentials — mount a real auth file to override
- Container runs as unprivileged user `opencode`; no additional packages can be installed
