# syntax=docker/dockerfile:1

# ─────────────────────────────────────────────────────────────────────────────
# Stage 1 – Download Kubernetes JSON schemas
# ─────────────────────────────────────────────────────────────────────────────
FROM alpine:3.21 AS schema-downloader

ARG K8S_VERSIONS="v1.31 v1.32 v1.33 v1.34 v1.35"

RUN apk add --no-cache curl git

COPY scripts/download-schemas.sh /scripts/download-schemas.sh
RUN chmod +x /scripts/download-schemas.sh \
    && K8S_VERSIONS="${K8S_VERSIONS}" \
    OUTPUT_DIR="/schemas" \
    /scripts/download-schemas.sh

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2 – Final image
# ─────────────────────────────────────────────────────────────────────────────
FROM alpine:3.21

ARG KUBECONFORM_VERSION
ARG KUSTOMIZE_VERSION

LABEL org.opencontainers.image.title="kubeconform-offline" \
    org.opencontainers.image.description="Offline kubeconform + kustomize with bundled Kubernetes JSON schemas (v1.31-v1.35)" \
    dev.kubeconform-offline.bundled-k8s-versions="v1.31 v1.32 v1.33 v1.34 v1.35"

# Upgrade base packages and install the two tools in a single layer,
# then remove curl so it does not remain in the final image.
RUN apk upgrade --no-cache \
    && apk add --no-cache curl \
    \
    # ── kubeconform ──────────────────────────────────────────────────────────
    && curl -fsSL \
    "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz" \
    | tar -xz -C /usr/local/bin kubeconform \
    && chmod +x /usr/local/bin/kubeconform \
    \
    # ── kustomize ────────────────────────────────────────────────────────────
    && curl -fsSL \
    "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" \
    | tar -xz -C /usr/local/bin kustomize \
    && chmod +x /usr/local/bin/kustomize \
    \
    # ── cleanup ──────────────────────────────────────────────────────────────
    && apk del curl \
    && rm -rf /var/cache/apk/*

# Copy the pre-built schema directories from stage 1
COPY --from=schema-downloader /schemas /schemas

# Run as a non-root user (UID 1000 is standard for GitLab and rootless runners)
RUN addgroup -g 1000 kubeconform \
    && adduser -u 1000 -G kubeconform -s /bin/sh -D kubeconform

USER kubeconform
WORKDIR /workspace

# Convenience variable so users can pass it directly on the CLI:
#   kubeconform -schema-location "$SCHEMA_LOCATION" manifests/
ENV SCHEMA_LOCATION="/schemas/{{.NormalizedKubernetesVersion}}-standalone{{.StrictSuffix}}/{{.ResourceKind}}{{.KindSuffix}}.json"

ENTRYPOINT ["kubeconform"]
# Default: show available schema versions then print help
CMD ["-h"]
