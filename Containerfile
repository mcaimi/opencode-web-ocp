# Opencode Web Image for Openshift

ARG UBI_IMAGE=registry.access.redhat.com/ubi10/ubi-minimal:10.1

# Opencode Builder
FROM ${UBI_IMAGE} AS opencode-download
ARG OPENCODE_VERSION=1.16.2
ARG TARGETARCH

RUN microdnf install -y \
  curl \
  gzip \
  tar \
  && microdnf clean all \
  && rm -rf /var/cache/dnf /var/cache/yum

RUN set -eux; \
  arch="${TARGETARCH:-$(uname -m)}"; \
  case "$arch" in \
  amd64|x86_64) opencode_asset="opencode-linux-x64.tar.gz"; ripgrep_target="x86_64-unknown-linux-musl" ;; \
  arm64|aarch64) opencode_asset="opencode-linux-arm64.tar.gz"; ripgrep_target="aarch64-unknown-linux-gnu" ;; \
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

# switch to root to install prerequisites
USER 0

RUN microdnf install -y \
  bash \
  shadow-utils \
  util-linux \
  which \
  git \
  jq \
  && microdnf clean all \
  && rm -rf /var/cache/dnf /var/cache/yum

RUN groupadd --system opencode \
  && useradd --system --create-home --home-dir /home/opencode --gid opencode --shell /bin/bash opencode \
  && mkdir -p /workspace /home/opencode/.config/opencode /home/opencode/.local/share/opencode

COPY --from=opencode-download /opt/opencode/opencode /usr/local/bin/opencode
COPY entry.sh /usr/local/bin/entrypoint
COPY opencode.json /home/opencode/.config/opencode/opencode.json
COPY auth.json /home/opencode/.local/share/opencode/auth.json
RUN chown -R opencode:opencode /workspace /home/opencode
RUN chmod 0755 /usr/local/bin/entrypoint

ENV HOME=/home/opencode \
  WORKSPACE_DIR=/workspace \
  OPENCODE_DISABLE_AUTOUPDATE=true

# config options
ENV OPENCODE_SERVER_PASSWORD=redhat
ENV OPENSHIFT_LLM_INFERENCE_ENDPOINT="http://inference.apps.openshift.local"
ENV OPENSHIFT_DEPLOYED_MODEL_NAME="qwen-coder"

WORKDIR /workspace

USER opencode

ENV HOST=0.0.0.0
ENV PORT=8080

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD []
