# opencode-web-ocp

Containerized deployment of [opencode web](https://github.com/anomalyco/opencode) for OpenShift.

See [README.md](README.md) for structure, build, and run instructions.

## Key constraints an agent would miss

- `config/opencode.json` is copied to `/tmp/opencode/.config/opencode/opencode.json` inside the container and contains **literal placeholder strings** — they are replaced in-place by `scripts/entry.sh` at container start. **Never edit this file directly; always change via env vars.**
- The `OPENSHIFT_DEPLOYED_MODEL_NAME` placeholder is both an env var name and a JSON key inside the models object. The entry script swaps that key, and uses it as the env var value.
- `config/auth.json` is copied to `/tmp/opencode/.local/share/opencode/auth.json` and is committed with `"key": "none"`. Override by mounting a real auth file into the container.
- The container runs as unprivileged user `opencode` with **gid 0** (root group) for OpenShift compatibility. No `microdnf` or package installs at runtime.
- Default env vars are baked into the `Containerfile` (`OPENSHIFT_LLM_INFERENCE_ENDPOINT`, `OPENSHIFT_DEPLOYED_MODEL_NAME`, `OPENCODE_SERVER_PASSWORD`, `OPENCODE_DISABLE_AUTOUPDATE`). They are not read from a `.env` file.
- `scripts/entry.sh` has fallback logic: if an env var is unset, it reads the placeholder value from the current `opencode.json` (via `jq`) and uses it as the default. This means the script is re-runnable — you can restart the container after changing an env var and it will still substitute correctly.
- The entrypoint script **displays proxy settings** (`HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`) at startup for troubleshooting proxy configurations.
- Custom agents/subagents in the `agents/` directory are automatically copied to `/tmp/opencode/.config/opencode/agents/` at image build time.
- The Helm chart (`helm/`) provides advanced deployment features including proxy support with automatic Kubernetes/OpenShift NO_PROXY exclusions, persistent storage, and edge-terminated routes.
