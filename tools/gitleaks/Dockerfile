# syntax=docker/dockerfile:1

# ─────────────────────────────────────────────────────────────────────────────
# Gitleaks – offline secret scanner with Node.js for Gitea runner compatibility
# ─────────────────────────────────────────────────────────────────────────────
FROM alpine:latest

ARG GITLEAKS_VERSION

LABEL org.opencontainers.image.title="ci-tooling-offline/gitleaks" \
    org.opencontainers.image.description="Offline gitleaks secret scanner with Node.js for Gitea/act compatibility"

# Install gitleaks binary, Node.js, git, and basic utilities in a single layer
RUN apk upgrade --no-cache \
    && apk add --no-cache \
    curl git \
    nodejs npm \
    openssh-client \
    \
    # ── gitleaks ─────────────────────────────────────────────────────────────
    && curl -fsSL \
    "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
    | tar -xz -C /usr/local/bin gitleaks \
    && chmod +x /usr/local/bin/gitleaks \
    \
    # ── cleanup ──────────────────────────────────────────────────────────────
    && apk del curl \
    && rm -rf /var/cache/apk/*

# Run as a non-root user (UID 1000 is standard for Gitea/GitLab runners)
RUN addgroup -g 1000 gitleaks \
    && adduser -u 1000 -G gitleaks -s /bin/sh -D gitleaks

USER gitleaks
WORKDIR /workspace

ENTRYPOINT ["gitleaks"]
CMD ["--help"]
