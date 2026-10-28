# opencode-web-ocp

Containerized deployment of [opencode web](https://github.com/anomalyco/opencode) for OpenShift.

See [README.md](README.md) for structure, build, and run instructions.

## Key constraints an agent would miss

- `config/opencode.json` is copied to `/home/opencode/.config/opencode/opencode.json` and contains **literal placeholder strings** — they are replaced in-place by `scripts/entry.sh` at container start. **Never edit this file directly; always change via env vars.**
- `config/opencode.json` uses the **opencode v2 schema** (`providers`, `package: "aisdk:..."`, `settings`). The `MODEL_NAME` env var renames the first key of `.providers.openshift.models` (initially the `OPENSHIFT_DEPLOYED_MODEL_NAME` placeholder) and sets `.model` to `openshift/$MODEL_NAME` at runtime (via `jq`). `OPENCODE_AUTOUPDATE` sets `.update` (`auto`/`disable`).
- The container runs `openchamber serve --foreground`; openchamber spawns and manages `opencode serve` on `127.0.0.1` (found via `OPENCODE_BINARY`) and generates its internal password. Do not export `OPENCODE_PASSWORD`, it would override openchamber's.
- openchamber 2.x **requires opencode v2 (>= 2.1.0)**. `releases/latest` on GitHub still points to opencode v1, so the version is pinned via `ARG OPENCODE_VERSION` (2.2.0) in `Containerfile.openchamber`; openchamber is pinned via `ARG OPENCHAMBER_VERSION` (2.5.2) and installed with npm from `@openchamber/web`.
- There is no `auth.json`: opencode v2 stores credentials in `opencode.db` (`OPENCODE_DB`) and only imports a legacy `auth.json` once. The inference API key comes from `APIKEY` via `{env:OPENSHIFT_AI_VLLM_API_KEY}`.
- `config/cli.json` (v2 replacement for `tui.json`) is copied to `/home/opencode/.config/opencode/cli.json`.
- The container runs as unprivileged user `opencode` with **gid 0** (root group) for OpenShift compatibility. No `microdnf` or package installs at runtime.
- Default env vars are baked into `Containerfile.openchamber` (`INFERENCE_ENDPOINT`, `MODEL_NAME`, `SERVER_PASSWORD`, `OPENCODE_AUTOUPDATE=false`, `OPENCODE_BINARY`, `OPENCODE_CONFIG_DIR`, `OPENCODE_DB`, `OPENCHAMBER_DATA_DIR`). They are not read from a `.env` file.
- `scripts/entry.sh` has fallback logic: if `MODEL_NAME` is unset, it keeps the model key currently in `opencode.json` (via `jq`). Since it always renames the current first key, the script is re-runnable — you can restart the container after changing `MODEL_NAME` and it will still substitute correctly.
- The entrypoint script **displays proxy settings** (`HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`) at startup for troubleshooting proxy configurations, and always appends `localhost,127.0.0.1,::1` to `NO_PROXY`/`no_proxy` (openchamber reaches opencode over loopback).
- Custom agents/subagents in the `agents/` directory are placed in `/home/opencode/.config/opencode/agents/`.
- The Helm chart (`helm/`) provides advanced deployment features including proxy support with automatic Kubernetes/OpenShift NO_PROXY exclusions, persistent storage (workspace, openchamber data, opencode state), Secret-backed `SERVER_PASSWORD`/`APIKEY` (`auth.*` values), `/health` probes, and edge-terminated routes.
- The `code-security` skill is pre-installed from the semgrep/skills repo at image build time.
- Home directory is `/home/opencode`; the opencode v2 binary is downloaded (checksum-verified against `SHA256SUMS`) at build time for multiple architectures; the image is based on UBI minimal.
- `openchamber` (repo moved to `github.com/openchamber/openchamber`) is installed with `npm install -g @openchamber/web` at image build time. Its data directory is `/home/opencode/.config/openchamber`. `GET /health` is unauthenticated.
- `ripgrep` (`ARG RIPGREP_VERSION`, 15.2.0) is installed for fast code search — the `rg` binary is available in `/usr/local/bin/rg`.
- Node.js 24 is installed via `microdnf` (`nodejs24`, which ships `/usr/bin/node-24`; symlinked to `/usr/local/bin/node`, `npm`, `npx`) — openchamber requires Node >= 24.14.
- The `SERVER_PASSWORD` env var is mapped to `OPENCHAMBER_UI_PASSWORD` for authentication.
- Set `API_ONLY=1` to run openchamber in API-only mode (`--api-only`) without the web UI.
- opencode v2 no longer runs language servers (`lsp` was removed from the config).
