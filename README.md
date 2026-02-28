# ci-tooling-offline

A monorepo of **air-gapped CI tool images** for Gitea Actions and GitLab CI. Each tool lives in its own directory under `tools/` with a self-contained Dockerfile, documentation, and example workflows.

All images are Alpine-based, pre-bundle everything needed at runtime, and require **no internet access** during pipeline execution.

## Available tools

| Tool            | Image                                            | Description                                                          |
| --------------- | ------------------------------------------------ | -------------------------------------------------------------------- |
| **kubeconform** | `ghcr.io/<owner>/ci-tooling-offline/kubeconform` | Kubernetes manifest validation with offline JSON schemas + kustomize |
| **gitleaks**    | `ghcr.io/<owner>/ci-tooling-offline/gitleaks`    | Secret scanning with Node.js for Gitea runner compatibility          |
| **yamllint**    | `ghcr.io/<owner>/ci-tooling-offline/yamllint`    | YAML linting with Python 3 and PyYAML                                |

## Repository structure

```
ci-tooling-offline/
├── .github/workflows/build.yml   ← matrix CI: builds all tool images
├── tools/
│   ├── kubeconform/
│   │   ├── Dockerfile
│   │   ├── README.md              ← detailed kubeconform docs
│   │   ├── scripts/
│   │   │   └── download-schemas.sh
│   │   └── examples/
│   │       └── gitea-workflow.yml ← copy into your project
│   ├── gitleaks/
│       ├── Dockerfile
│       ├── README.md              ← detailed gitleaks docs
│       └── examples/
│           └── gitea-workflow.yml ← copy into your project
│   └── yamllint/
│       ├── Dockerfile
│       ├── README.md              ← detailed yamllint docs
│       └── examples/
│           └── gitea-workflow.yml ← copy into your project
└── manifests/                     ← test fixtures
```

Each tool directory is a **self-contained Docker build context**. The CI workflow uses a matrix strategy to build and push all tools in parallel.

## Quick start

### Use in Gitea Actions

Copy the example workflow from any tool into your project:

```sh
# For kubeconform
mkdir -p .gitea/workflows
cp tools/kubeconform/examples/gitea-workflow.yml .gitea/workflows/kubeconform.yml

# For gitleaks
cp tools/gitleaks/examples/gitea-workflow.yml .gitea/workflows/gitleaks.yml

# For yamllint
cp tools/yamllint/examples/gitea-workflow.yml .gitea/workflows/yamllint.yml
```

Then adjust the image reference (`ghcr.io/<owner>/ci-tooling-offline/<tool>:latest`) to match your registry.

### Use in GitLab CI

See each tool's README for GitLab CI examples:
- [tools/kubeconform/README.md](tools/kubeconform/README.md)
- [tools/gitleaks/README.md](tools/gitleaks/README.md)
- [tools/yamllint/README.md](tools/yamllint/README.md)

## Automation

The GitHub Actions workflow ([`.github/workflows/build.yml`](.github/workflows/build.yml)) runs on the **1st and 15th of each month**. For each tool it:

1. Resolves the latest upstream release version.
2. Skips the build if a release tag for that version already exists.
3. Builds and pushes the image to GHCR (`ghcr.io/<owner>/ci-tooling-offline/<tool>`).
4. Signs the image with [cosign](https://github.com/sigstore/cosign) (keyless / OIDC).
5. Generates an SPDX SBOM and attaches it as a cosign attestation.
6. Scans the image for vulnerabilities with [Trivy](https://github.com/aquasecurity/trivy).
7. Creates a GitHub Release with tool versions, usage examples, and the SBOM / vulnerability report as assets.

Release tags are prefixed per tool (`kubeconform-v*`, `gitleaks-v*`, `yamllint-v*`) to avoid collisions.

Trigger a manual rebuild via **Actions → Build and Publish → Run workflow** with:
- **force_rebuild**: override the skip guard
- **tools**: comma-separated list to build only specific tools (empty = all)

## Supply-chain security

Every container image is signed and attested using [Sigstore](https://www.sigstore.dev/) tooling:

- **Cosign keyless signing** – each image is signed via OIDC (no long-lived keys). Verify with:
  ```sh
  cosign verify \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    --certificate-identity-regexp 'https://github.com/<owner>/ci-tooling-offline/' \
    ghcr.io/<owner>/ci-tooling-offline/<tool>:<tag>
  ```
- **SBOM attestation** – an SPDX JSON SBOM is generated with [Syft](https://github.com/anchore/syft) and attached to the image as an in-toto attestation. Verify with:
  ```sh
  cosign verify-attestation \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    --certificate-identity-regexp 'https://github.com/<owner>/ci-tooling-offline/' \
    --type spdxjson \
    ghcr.io/<owner>/ci-tooling-offline/<tool>:<tag>
  ```
- **Vulnerability report** – [Trivy](https://github.com/aquasecurity/trivy) scans each image and the report is uploaded as a GitHub Release asset.

## Local builds

```sh
# Build kubeconform image
docker build \
  --build-arg KUBECONFORM_VERSION=v0.7.0 \
  --build-arg KUSTOMIZE_VERSION=v5.8.1 \
  -t ci-tooling-offline/kubeconform:local tools/kubeconform/

# Build gitleaks image
docker build \
  --build-arg GITLEAKS_VERSION=8.24.0 \
  -t ci-tooling-offline/gitleaks:local tools/gitleaks/

# Build yamllint image
docker build \
  --build-arg YAMLLINT_VERSION=1.37.0 \
  -t ci-tooling-offline/yamllint:local tools/yamllint/
```

## Local testing with act

```sh
cp .act.secrets.example .act.secrets
# fill in a PAT with repo + write:packages scopes

# Run all tools
act schedule -W .github/workflows/build.yml

# Run with manual trigger
act workflow_dispatch -W .github/workflows/build.yml

# Build only one tool
act workflow_dispatch -W .github/workflows/build.yml \
    -e '{"inputs":{"tools":"gitleaks"}}'
```

### Testing Gitea workflows per project

Copy a tool's example workflow into your project and run it locally with act:

```sh
cd your-project/

# Test gitleaks workflow
act push -W .gitea/workflows/gitleaks.yml

# Test kubeconform workflow
act push -W .gitea/workflows/kubeconform.yml
```

## Adding a new tool

1. Create `tools/<tool-name>/` with a `Dockerfile`, `README.md`, and `examples/gitea-workflow.yml`.
2. Add the tool to the matrix in `.github/workflows/build.yml`:
   - Add to the default tools JSON array in the `matrix` job.
   - Add version-resolution steps gated with `if: matrix.tool == '<tool-name>'`.
   - Add a release-notes step gated the same way.
3. Update this README's "Available tools" table.
