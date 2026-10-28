#!/bin/bash

set -e

# config file
WORKDIR=${WORKDIR:-"/workspace"}
JSON_FILE=${CONFIG_FILE:-"/home/opencode/.config/opencode/opencode.json"}
# OPENCODE_AUTOUPDATE is the legacy name; it always meant "disable autoupdate"
O_DISABLE_AUTOUPDATE=${DISABLE_AUTOUPDATE:-${OPENCODE_AUTOUPDATE:-true}}
O_SERVER_PASSWORD="${SERVER_PASSWORD:-redhat}"
LLM_INFERENCE_ENDPOINT="${INFERENCE_ENDPOINT:-http://inference.apps.openshift.local}"
DEPLOYED_MODEL_NAME="${MODEL_NAME:-qwen-coder}"
LLM_APIKEY="${APIKEY:-}"

# Check if JSON_FILE is readable
if [ ! -r "$JSON_FILE" ]; then
  echo "Error: Cannot read JSON_FILE at $JSON_FILE"
  exit 1
fi

# Extract default values from JSON file
DEFAULT_MODEL=$(jq -r '.providers.openshift.models | keys[0]' "$JSON_FILE")

# create local config dir
CUSTOM_CONFIG_DIR="/home/opencode/.config/opencode"
mkdir -p "$CUSTOM_CONFIG_DIR"

# Substitute model name key
TMPFILE=$(mktemp $CUSTOM_CONFIG_DIR/opencode.XXXXXX)
jq \
  --arg oldmodel "OPENSHIFT_DEPLOYED_MODEL_NAME" \
  --arg newmodel "${DEPLOYED_MODEL_NAME:-$DEFAULT_MODEL}" \
  '
  .providers.openshift.models |= (
    with_entries(
      if .key == $oldmodel then .key = $newmodel else . end
    )
  )
' "$JSON_FILE" >"$TMPFILE"

# show config and replace the default one
cat "$TMPFILE" | jq .
mv "$TMPFILE" "$JSON_FILE"

# Get local IP address or fallback to localhost
LOCAL_IP=$(hostname -i 2>/dev/null | awk '{print $1}')
HOST=${HOST:-${LOCAL_IP:-localhost}}
PORT=${PORT:-8080}

echo "Starting opencode web on ${HOST}:${PORT}"
echo "Using Proxy Settings: HTTP_PROXY=${HTTP_PROXY}, HTTPS_PROXY=${HTTPS_PROXY}, NO_PROXY=${NO_PROXY}"

# start opencode in server mode
export OPENCODE_CONFIG_DIR="${CUSTOM_CONFIG_DIR}"
export OPENCODE_DISABLE_AUTOUPDATE=${O_DISABLE_AUTOUPDATE}
export OPENCODE_PASSWORD=${O_SERVER_PASSWORD}
export OPENSHIFT_LLM_INFERENCE_ENDPOINT="${LLM_INFERENCE_ENDPOINT}"
export OPENSHIFT_AI_VLLM_API_KEY="${LLM_APIKEY}"
# v2 serve takes no project directory: the server starts in $WORKDIR
cd "$WORKDIR"
exec opencode serve --hostname "${HOST}" --port "${PORT}"
