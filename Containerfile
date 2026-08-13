# Opencode Web Image for Openshift

ARG UBI_IMAGE=registry.access.redhat.com/ubi10/ubi-minimal:10.1

# Opencode Builder
FROM ${UBI_IMAGE} AS opencode-download
ARG OPENCODE_VERSION=1.18.18
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

# skill downloader
FROM ${UBI_IMAGE} AS skill-download
ARG SKILL_REPO=https://github.com/semgrep/skills

RUN microdnf upgrade -y && microdnf install -y git && microdnf clean all

RUN set -eux; \
  mkdir -p /opt/skills; \
  git clone ${SKILL_REPO} /opt/skills && chgrp -R 0 /opt/skills && chmod -R g=u /opt/skills

# Runtime Image
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

RUN useradd --system --create-home --home-dir /home/opencode --gid 0 --shell /bin/bash opencode \
  && mkdir -p /home/opencode/.config/opencode/agents /home/opencode/.local/share/opencode /home/opencode/.config/opencode/skills /workspace

# Copy binaries and config files
COPY --from=opencode-download /opt/opencode/opencode /usr/local/bin/opencode
COPY --from=skill-download /opt/skills/skills/code-security /home/opencode/.config/opencode/skills/code-security
COPY scripts/entry.sh /usr/local/bin/entrypoint
COPY config/opencode.json /home/opencode/.config/opencode/opencode.json

# Upload custom subagents
COPY agents/git-summary.md /home/opencode/.config/opencode/agents/git-summary.md
COPY agents/security-auditor.md /home/opencode/.config/opencode/agents/security-auditor.md

# fix permissions
RUN chown -Rv opencode:0 /home/opencode /workspace \
  && chmod -R g=u /home/opencode /workspace \
  && chmod 0755 /usr/local/bin/entrypoint

# define volume
VOLUME /workspace

# define workdir
WORKDIR /workspace

# config options
ENV HOME=/home/opencode

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD []
