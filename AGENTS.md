# opencode-web-ocp

Containerized deployment of [opencode web](https://github.com/anomalyco/opencode) for OpenShift.

See [README.md](README.md) for structure, build, and run instructions.

## Key constraints an agent would miss

- `opencode.json` at `/home/opencode/.config/opencode/opencode.json` inside the container contains **literal placeholder strings** — they are replaced in-place by `entry.sh` at container start. **Never edit this file directly; always change via env vars.**
- The `OPENSHIFT_DEPLOYED_MODEL_NAME` placeholder is both an env var name and a JSON key inside the models object. The entry script swaps that key, and uses it as the env var value.
- `auth.json` at `/home/opencode/.local/share/opencode/auth.json` is committed with `"key": "none"`. Override by mounting a real auth file into the container.
- The container runs as unprivileged user `opencode`. No `microdnf` or package installs at runtime.
- Default env vars are baked into the `Containerfile` (`OPENSHIFT_LLM_INFERENCE_ENDPOINT`, `OPENSHIFT_DEPLOYED_MODEL_NAME`, `OPENSHIFT_SERVER_PASSWORD`, `HOST`, `PORT`). They are not read from a `.env` file.
- `entry.sh` has fallback logic: if an env var is unset, it reads the placeholder value from the current `opencode.json` and uses it as the "old" string to replace. This means the script is re-runnable — you can restart the container after changing an env var and it will still substitute correctly.
