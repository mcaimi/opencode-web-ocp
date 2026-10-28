#!/bin/bash

set -euo pipefail

# config file
WORKDIR=${WORKDIR:-"/workspace"}
CUSTOM_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-/home/opencode/.config/opencode}"
JSON_FILE=${CONFIG_FILE:-"${CUSTOM_CONFIG_DIR}/opencode.json"}
O_DATA_DIR="${OPENCHAMBER_DATA_DIR:-/home/opencode/.config/openchamber}"
O_AUTOUPDATE="${OPENCODE_AUTOUPDATE:-false}"
O_SERVER_PASSWORD="${SERVER_PASSWORD:-redhat}"
O_API_ONLY="${API_ONLY:-0}"
LLM_INFERENCE_ENDPOINT="${INFERENCE_ENDPOINT:-http://inference.apps.openshift.local}"
LLM_APIKEY="${APIKEY:-}"

# Check if JSON_FILE is readable
if [ ! -r "$JSON_FILE" ]; then
  echo "Error: Cannot read JSON_FILE at $JSON_FILE"
  exit 1
fi

# Fallback model name: whatever key is currently configured (placeholder or a previous substitution)
DEFAULT_MODEL=$(jq -r '.providers.openshift.models | keys[0]' "$JSON_FILE")
DEPLOYED_MODEL_NAME="${MODEL_NAME:-$DEFAULT_MODEL}"

case "${O_AUTOUPDATE,,}" in
1 | true | yes) O_UPDATE_MODE="auto" O_DISABLE_AUTOUPDATE="false" ;;
*) O_UPDATE_MODE="disable" O_DISABLE_AUTOUPDATE="true" ;;
esac

# create local config dirs
mkdir -p "$CUSTOM_CONFIG_DIR" "$O_DATA_DIR" "$(dirname "${OPENCODE_DB:-/home/opencode/.local/share/opencode/opencode.db}")"

# Substitute model name key (the first configured model is always the deployed one,
# so this is re-runnable after MODEL_NAME changes) and the default model selection
TMPFILE=$(mktemp "$CUSTOM_CONFIG_DIR/opencode.XXXXXX")
jq \
  --arg oldmodel "$DEFAULT_MODEL" \
  --arg newmodel "$DEPLOYED_MODEL_NAME" \
  --arg update "$O_UPDATE_MODE" \
  '
  .providers.openshift.models |= (
    with_entries(
      if .key == $oldmodel then .key = $newmodel else . end
    )
  )
  | .model = "openshift/" + $newmodel
  | .update = $update
' "$JSON_FILE" >"$TMPFILE"

# show config and replace the default one
jq . "$TMPFILE"
mv "$TMPFILE" "$JSON_FILE"

# Get local IP address or fallback to localhost
LOCAL_IP=$(hostname -i 2>/dev/null | awk '{print $1}' || true)
HOST=${HOST:-${LOCAL_IP:-localhost}}
PORT=${PORT:-8080}

# openchamber talks to its managed opencode server over loopback: never proxy it
LOOPBACK_NO_PROXY="localhost,127.0.0.1,::1"
NO_PROXY="${NO_PROXY:+${NO_PROXY},}${LOOPBACK_NO_PROXY}"
no_proxy="${no_proxy:+${no_proxy},}${LOOPBACK_NO_PROXY}"
export NO_PROXY no_proxy

if [ "$O_SERVER_PASSWORD" = "redhat" ]; then
  echo "WARNING: SERVER_PASSWORD is set to the default value, change it before exposing this service"
fi

echo "opencode $(opencode --version), openchamber $(openchamber --version)"
echo "Starting openchamber on ${HOST}:${PORT} (workdir ${WORKDIR})"
echo "Using Proxy Settings: HTTP_PROXY=${HTTP_PROXY:-}, HTTPS_PROXY=${HTTPS_PROXY:-}, NO_PROXY=${NO_PROXY}"

# opencode environment (openchamber spawns `opencode serve` and manages its password)
export OPENCODE_CONFIG_DIR="${CUSTOM_CONFIG_DIR}"
if [ -n "${CONFIG_FILE:-}" ]; then
  export OPENCODE_CONFIG="${JSON_FILE}"
fi
export OPENCODE_DISABLE_AUTOUPDATE="${O_DISABLE_AUTOUPDATE}"
export OPENCODE_BINARY="${OPENCODE_BINARY:-/usr/local/bin/opencode}"
export OPENSHIFT_LLM_INFERENCE_ENDPOINT="${LLM_INFERENCE_ENDPOINT}"
export OPENSHIFT_AI_VLLM_API_KEY="${LLM_APIKEY}"

# openchamber environment
export OPENCHAMBER_UI_PASSWORD="${O_SERVER_PASSWORD}"
export OPENCHAMBER_HOST="${HOST}"
export OPENCHAMBER_DATA_DIR="${O_DATA_DIR}"
export OPENCHAMBER_OPENCODE_HOSTNAME="${OPENCHAMBER_OPENCODE_HOSTNAME:-127.0.0.1}"

OPENCHAMBER_ARGS=(serve --foreground --port "${PORT}" --host "${HOST}")
case "${O_API_ONLY,,}" in
1 | true | yes) OPENCHAMBER_ARGS+=(--api-only) ;;
esac

# startup openchamber/opencode
cd "$WORKDIR"
exec openchamber "${OPENCHAMBER_ARGS[@]}"
