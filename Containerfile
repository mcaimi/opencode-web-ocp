# Opencode Web Image for Openshift

ARG UBI_IMAGE=registry.access.redhat.com/ubi10/ubi-minimal:10.1

# Opencode Builder
FROM ${UBI_IMAGE} AS opencode-download
ARG OPENCODE_VERSION=1.17.2
ARG TARGETARCH

RUN microdnf upgrade -y && microdnf install -y \
  curl \
  gzip \
  tar \
  && microdnf clean all \
  && rm -rf /var/cache/dnf /var/cache/yum

RUN set -eux; \
  arch="${TARGETARCH:-$(uname -m)}"; \
  case "$arch" in \
  amd64|x86_64) opencode_asset="opencode-linux-x64.tar.gz" ;; \
  arm64|aarch64) opencode_asset="opencode-linux-arm64.tar.gz" ;; \
  *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
  esac; \
  curl -fsSL \
  -o /tmp/opencode.tar.gz \
  "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/${opencode_asset}"; \
  mkdir -p /opt/opencode; \
  tar -xzf /tmp/opencode.tar.gz -C /opt/opencode; \
  chmod 0755 /opt/opencode/opencode; \
  /opt/opencode/opencode --version;

# Runtime Image
FROM registry.access.redhat.com/ubi10/ubi:latest
FROM ${UBI_IMAGE}

# install requirements
RUN microdnf upgrade -y && microdnf install -y \
  bash \
  shadow-utils \
  util-linux \
  which \
  git \
  jq \
  iproute \
  hostname \
  && microdnf clean all \
  && rm -rf /var/cache/dnf /var/cache/yum

RUN useradd --system --create-home --home-dir /tmp/opencode --gid 0 --shell /bin/bash opencode \
  && mkdir -p /tmp/opencode/.config/opencode/agents /tmp/opencode/.local/share/opencode

# Copy binaries and config files
COPY --from=opencode-download /opt/opencode/opencode /usr/local/bin/opencode
COPY scripts/entry.sh /usr/local/bin/entrypoint
COPY config/opencode.json /tmp/opencode/.config/opencode/opencode.json
COPY config/auth.json /tmp/opencode/.local/share/opencode/auth.json

# Upload custom subagents
COPY agents/git-summary.md /tmp/opencode/.config/opencode/agents/git-summary.md

# fix permissions
RUN chown -Rv opencode:0 /tmp/opencode \
  && chmod 0755 /usr/local/bin/entrypoint && chmod -Rv 0755 /tmp/opencode

# config options
ENV OPENCODE_DISABLE_AUTOUPDATE=true
ENV OPENCODE_SERVER_PASSWORD=redhat
ENV OPENSHIFT_LLM_INFERENCE_ENDPOINT="http://inference.apps.openshift.local"
ENV OPENSHIFT_DEPLOYED_MODEL_NAME="qwen-coder"

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD []
