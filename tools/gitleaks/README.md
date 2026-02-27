# gitleaks (ci-tooling-offline)

Alpine-based container image bundling [gitleaks](https://github.com/gitleaks/gitleaks) with **Node.js** — designed for air-gapped / offline secret scanning in Gitea and GitLab CI pipelines.

## What's inside

| Component  | Source                                                                        |
| ---------- | ----------------------------------------------------------------------------- |
| `gitleaks` | Latest release from [gitleaks/gitleaks](https://github.com/gitleaks/gitleaks) |
| `node`     | Alpine `nodejs` package (LTS major version)                                   |
| `npm`      | Alpine `npm` package                                                          |
| `git`      | Alpine `git` package                                                          |

### Why Node.js?

Gitea Actions runners (and `act`) require a Node.js runtime to execute composite actions and JavaScript-based actions. Including Node.js in the image ensures pipelines work correctly in air-gapped environments where the runner cannot download Node.js on the fly.

## Usage

### Gitea Actions

Copy [`examples/gitea-workflow.yml`](examples/gitea-workflow.yml) into your project's `.gitea/workflows/` directory.

### GitLab CI

```yaml
secret-scan:
  image:
    name: ghcr.io/<your-org>/ci-tooling-offline/gitleaks:latest
    entrypoint: [""]
  script:
    - gitleaks detect --source . --verbose
```

### Local

```sh
# Build locally
docker build \
  --build-arg GITLEAKS_VERSION=8.24.0 \
  -t ci-tooling-offline/gitleaks:local tools/gitleaks/

# Scan current directory
docker run --rm -v "$(pwd):/workspace" ci-tooling-offline/gitleaks:local detect --source . --verbose

# Verify Node.js is present
docker run --rm --entrypoint node ci-tooling-offline/gitleaks:local --version
```

## Configuration

Place a `.gitleaks.toml` file in the root of your repository to customize rules, allowlists, and paths. See the [gitleaks documentation](https://github.com/gitleaks/gitleaks#configuration) for details.

## Running with act

```sh
cd your-project/
act push -W .gitea/workflows/gitleaks.yml
```
