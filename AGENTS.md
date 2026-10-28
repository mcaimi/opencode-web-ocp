# opencode-web-ocp

Containerized deployment of [opencode web](https://github.com/anomalyco/opencode) for OpenShift.

See [README.md](README.md) for structure, build, and run instructions.

## Key constraints an agent would miss

- `config/opencode.json` is copied to `/home/opencode/.config/opencode/opencode.json` and contains **literal placeholder strings** — they are replaced in-place by `scripts/entry.sh` at container start. **Never edit this file directly; always change via env vars.**
- The `MODEL_NAME` env var replaces the `OPENSHIFT_DEPLOYED_MODEL_NAME` placeholder key in `opencode.json` at runtime (via `jq`).
- `config/opencode.json` uses the **opencode v2 format** (`providers`, `settings`, `package`, `policies`), not v1 (`provider`, `options`, `npm`, `enabled_providers`). `config/cli.json` replaces v1's `tui.json`.
- The container runs as unprivileged user `opencode` with **gid 0** (root group) for OpenShift compatibility. No `microdnf` or package installs at runtime.
- Defaults for `INFERENCE_ENDPOINT`, `MODEL_NAME`, `SERVER_PASSWORD`, `DISABLE_AUTOUPDATE` live in `scripts/entry.sh`. They are not read from a `.env` file. `SERVER_PASSWORD` is exported as `OPENCODE_PASSWORD`.
- v2 `opencode serve` takes no directory argument; `entry.sh` `cd`s into `$WORKDIR` before starting. Web UI pages (`/`) are public, so `httpGet /` probes work; `/api/*` requires basic auth (username `opencode`).
- `scripts/entry.sh` has fallback logic: if an env var is unset, it reads the placeholder value from the current `opencode.json` (via `jq`) and uses it as the default. The substitution only works on a fresh copy of the config (the placeholder key is gone after the first run), which is what a container restart gives you.
- The entrypoint script **displays proxy settings** (`HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`) at startup for troubleshooting proxy configurations.
- Custom agents/subagents in the `agents/` directory are placed in `/home/opencode/.config/opencode/agents/`.
- The Helm chart (`helm/`) provides advanced deployment features including proxy support with automatic Kubernetes/OpenShift NO_PROXY exclusions, persistent storage (workspace and session database), and edge-terminated routes.
- The `code-security` skill is pre-installed from the semgrep/skills repo at image build time.
- Home directory is `/home/opencode`; the opencode v2 binary is downloaded at build time (pinned by the `OPENCODE_VERSION` build arg, because GitHub's `releases/latest` still points at the v1 line) for multiple architectures from UBI minimal.
