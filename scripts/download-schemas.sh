#!/bin/sh
# Download Kubernetes JSON schemas (standalone + standalone-strict) for the
# specified minor versions using git sparse-checkout.
#
# Environment variables:
#   K8S_VERSIONS   Space-separated minor versions to bundle (default below)
#   OUTPUT_DIR     Destination directory for schemas (default /schemas)

set -eu

K8S_MINOR_VERSIONS="${K8S_VERSIONS:-v1.33 v1.34 v1.35}"
OUTPUT_DIR="${OUTPUT_DIR:-/schemas}"

SCHEMA_REPO="https://github.com/yannh/kubernetes-json-schema.git"
CONTENTS_API="https://api.github.com/repos/yannh/kubernetes-json-schema/contents/"
CLONE_DIR="/tmp/k8s-json-schema"

echo "==> Fetching Kubernetes JSON schema directory listing from GitHub..."
tree_json=$(curl -fsSL "${CONTENTS_API}")

# Build the list of sparse-checkout paths and resolve latest patch per minor
checkout_paths=""
echo "==> Resolving latest patch versions:"
for minor in $K8S_MINOR_VERSIONS; do
    ver="${minor#v}"  # strip leading 'v' for regex matching
    # Find latest vX.Y.Z-standalone-strict directory
    latest_strict=$(printf '%s\n' "$tree_json" \
        | grep -oE "\"name\": \"v${ver}\\.[0-9]+-standalone-strict\"" \
        | sed 's/"name": "//;s/"//' \
        | sort -V | tail -1)

    # Find latest vX.Y.Z-standalone directory (the -standalone" quote anchor
    # ensures we do NOT match standalone-strict entries here)
    latest=$(printf '%s\n' "$tree_json" \
        | grep -oE "\"name\": \"v${ver}\\.[0-9]+-standalone\"" \
        | sed 's/"name": "//;s/"//' \
        | sort -V | tail -1)

    if [ -z "$latest_strict" ] || [ -z "$latest" ]; then
        echo "ERROR: No schemas found for Kubernetes ${minor}" >&2
        exit 1
    fi

    patch_version="${latest_strict%-standalone-strict}"
    echo "  ${minor}  ->  ${patch_version}"

    checkout_paths="${checkout_paths} ${latest} ${latest_strict}"
done

echo "==> Cloning kubernetes-json-schema with sparse checkout..."
git clone \
    --filter=blob:none \
    --no-checkout \
    --depth=1 \
    --single-branch \
    "$SCHEMA_REPO" \
    "$CLONE_DIR"

cd "$CLONE_DIR"
git sparse-checkout init --no-cone
# shellcheck disable=SC2086  (word-splitting is intentional here)
git sparse-checkout set $checkout_paths
git checkout

echo "==> Copying schemas to ${OUTPUT_DIR}..."
mkdir -p "$OUTPUT_DIR"

for dir in $checkout_paths; do
    if [ -d "$dir" ]; then
        cp -r "$dir" "$OUTPUT_DIR/"
        count=$(find "$OUTPUT_DIR/$dir" -name '*.json' | wc -l)
        echo "  Copied: ${dir}  (${count} schemas)"
    else
        echo "WARNING: Directory '${dir}' not found after checkout" >&2
    fi
done

# Create "default" symlinks pointing to the overall latest patch version
latest_default_strict=$(printf '%s\n' $checkout_paths | grep '\-standalone-strict$' | sort -V | tail -1)
latest_default=$(printf '%s\n' $checkout_paths | grep '\-standalone$' | sort -V | tail -1)
if [ -n "$latest_default_strict" ] && [ -n "$latest_default" ]; then
    ln -sfn "$latest_default_strict" "$OUTPUT_DIR/default-standalone-strict"
    ln -sfn "$latest_default" "$OUTPUT_DIR/default-standalone"
    echo "==> Default schemas -> ${latest_default_strict%-standalone-strict}"
fi

# Write a human-readable version manifest
{
    echo "# Bundled Kubernetes JSON Schema Versions"
    echo "# Format: minor_version=bundled_patch_version"
    for minor in $K8S_MINOR_VERSIONS; do
        ver="${minor#v}"
        patch=$(ls -d "$OUTPUT_DIR/v${ver}."*"-standalone-strict" 2>/dev/null \
            | sort -V | tail -1 | xargs basename | sed 's/-standalone-strict//')
        echo "${minor}=${patch}"
    done
} > "$OUTPUT_DIR/versions.txt"

echo "==> Schema manifest written to ${OUTPUT_DIR}/versions.txt"
echo "==> Done. Total size: $(du -sh "$OUTPUT_DIR" | cut -f1)"
