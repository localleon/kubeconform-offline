# syntax=docker/dockerfile:1

# ─────────────────────────────────────────────────────────────────────────────
# yamllint – offline YAML linter with Python 3 and PyYAML
# ─────────────────────────────────────────────────────────────────────────────
FROM alpine:latest

ARG YAMLLINT_VERSION

LABEL org.opencontainers.image.title="ci-tooling-offline/yamllint" \
    org.opencontainers.image.description="Offline yamllint YAML linter with Python 3 and PyYAML for Gitea/act compatibility"

# Install yamllint via pip, Python 3, PyYAML, Node.js, and basic utilities in a single layer
RUN apk upgrade --no-cache \
    && apk add --no-cache \
    python3 py3-pip py3-yaml \
    nodejs npm \
    git openssh-client \
    \
    # ── yamllint ──────────────────────────────────────────────────────────────
    && pip install --no-cache-dir --break-system-packages \
    yamllint==${YAMLLINT_VERSION} \
    \
    # ── cleanup ───────────────────────────────────────────────────────────────
    && rm -rf /var/cache/apk/*

# Run as a non-root user (UID 1000 is standard for Gitea/GitLab runners)
RUN addgroup -g 1000 yamllint \
    && adduser -u 1000 -G yamllint -s /bin/sh -D yamllint

USER yamllint
WORKDIR /workspace

ENTRYPOINT ["yamllint"]
CMD ["--help"]
