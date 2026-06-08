#!/bin/bash

set -e

# config file
JSON_FILE=${JSON_FILE:-"/home/opencode/.config/opencode/opencode.json"}

# Substitute model name key and inference endpoint URL
jq \
  --arg oldmodel "OPENSHIFT_DEPLOYED_MODEL_NAME" \
  --arg newmodel "${OPENSHIFT_DEPLOYED_MODEL_NAME:-$(jq -r '.provider.openshift.models | keys[0]' "$JSON_FILE")}" \
  --arg oldendpoint "OPENSHIFT_LLM_INFERENCE_ENDPOINT" \
  --arg newendpoint "${OPENSHIFT_LLM_INFERENCE_ENDPOINT:-$(jq -r '.provider.openshift.options.baseURL' "$JSON_FILE")}" \
  '
  .provider.openshift.models |= (
    with_entries(
      if .key == $oldmodel then .key = $newmodel else . end
    )
  ) |
  .provider.openshift.options.baseURL |= (
    if . == $oldendpoint then $newendpoint else . end
  )
' "$JSON_FILE" >"${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"

# show config
cat "$JSON_FILE" | jq .

HOST=${HOST:-0.0.0.0}
PORT=${PORT:-8080}

echo "Starting opencode web on ${HOST}:${PORT}"

exec opencode web --hostname "${HOST}" --port "${PORT}" --cors="*"
