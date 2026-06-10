#!/bin/bash

set -e

# config file
JSON_FILE=${JSON_FILE:-"/tmp/opencode/.config/opencode/opencode.json"}

# Check if JSON_FILE is readable
if [ ! -r "$JSON_FILE" ]; then
  echo "Error: Cannot read JSON_FILE at $JSON_FILE"
  exit 1
fi

# Extract default values from JSON file
DEFAULT_MODEL=$(jq -r '.provider.openshift.models | keys[0]' "$JSON_FILE")
DEFAULT_ENDPOINT=$(jq -r '.provider.openshift.options.baseURL' "$JSON_FILE")

# create local config dir
CUSTOM_CONFIG_DIR="/tmp/opencode"
mkdir -p "$CUSTOM_CONFIG_DIR"

# Substitute model name key and inference endpoint URL
TMPFILE=$(mktemp $CUSTOM_CONFIG_DIR/opencode.XXXXXX)
jq \
  --arg oldmodel "OPENSHIFT_DEPLOYED_MODEL_NAME" \
  --arg newmodel "${OPENSHIFT_DEPLOYED_MODEL_NAME:-$DEFAULT_MODEL}" \
  --arg oldendpoint "OPENSHIFT_LLM_INFERENCE_ENDPOINT" \
  --arg newendpoint "${OPENSHIFT_LLM_INFERENCE_ENDPOINT:-$DEFAULT_ENDPOINT}" \
  '
  .provider.openshift.models |= (
    with_entries(
      if .key == $oldmodel then .key = $newmodel else . end
    )
  ) |
  .provider.openshift.options.baseURL |= (
    if . == $oldendpoint then $newendpoint else . end
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

OPENCODE_CONFIG_DIR="${CUSTOM_CONFIG_DIR}" opencode web --hostname "${HOST}" --port "${PORT}" --cors="*"
