# opencode-web-ocp

Containerized deployment of [opencode web](https://github.com/anomalyco/opencode) for OpenShift.

See [README.md](README.md) for structure, build, and run instructions.

## Key constraints an agent would miss

- `config/opencode.json` is copied to `/home/opencode/.config/opencode/opencode.json` and contains **literal placeholder strings** — they are replaced in-place by `scripts/entry.sh` at container start. **Never edit this file directly; always change via env vars.**
- The `MODEL_NAME` env var replaces the `OPENSHIFT_DEPLOYED_MODEL_NAME` placeholder key in `opencode.json` at runtime (via `jq`).
- `config/auth.json` is copied to `/home/opencode/.local/share/opencode/auth.json` and is committed with `"key": "none"`. Override by mounting a real auth file into the container.
- The container runs as unprivileged user `opencode` with **gid 0** (root group) for OpenShift compatibility. No `microdnf` or package installs at runtime.
- Default env vars are baked into the `Containerfile` (`INFERENCE_ENDPOINT`, `MODEL_NAME`, `SERVER_PASSWORD`, `OPENCODE_AUTOUPDATE`). They are not read from a `.env` file.
- `scripts/entry.sh` has fallback logic: if an env var is unset, it reads the placeholder value from the current `opencode.json` (via `jq`) and uses it as the default. This means the script is re-runnable — you can restart the container after changing an env var and it will still substitute correctly.
- The entrypoint script **displays proxy settings** (`HTTP_PROXY`, `HTTPS_API`, `NO_PROXY`) at startup for troubleshooting proxy configurations.
- Custom agents/subagents in the `agents/` directory are placed in `/home/opencode/.config/opencode/agents/`.
- The Helm chart (`helm/`) provides advanced deployment features including proxy support with automatic Kubernetes/OpenShift NO_PROXY exclusions, persistent storage, and edge-terminated routes.
- The `code-security` skill is pre-installed from the semgrep/skills repo at image build time.
- Home directory is `/home/opencode`; opencode binary v1.17.4 is downloaded at build time for multiple architectures from UBI minimal.
