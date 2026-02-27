# yamllint (ci-tooling-offline)

Alpine-based container image bundling [yamllint](https://github.com/adrienverge/yamllint) with **Python 3** and **PyYAML** — designed for air-gapped / offline YAML linting in Gitea and GitLab CI pipelines.

## What's inside

| Component  | Source                                                                              |
| ---------- | ----------------------------------------------------------------------------------- |
| `yamllint` | Latest release from [adrienverge/yamllint](https://github.com/adrienverge/yamllint) |
| `python3`  | Alpine `python3` package                                                            |
| `PyYAML`   | Alpine `py3-yaml` package                                                           |
| `node`     | Alpine `nodejs` package (LTS major version)                                         |
| `npm`      | Alpine `npm` package                                                                |
| `git`      | Alpine `git` package                                                                |

### Why Node.js?

Gitea Actions runners (and `act`) require a Node.js runtime to execute composite actions and JavaScript-based actions. Including Node.js in the image ensures pipelines work correctly in air-gapped environments where the runner cannot download Node.js on the fly.

## Usage

### Gitea Actions

Copy [`examples/gitea-workflow.yml`](examples/gitea-workflow.yml) into your project's `.gitea/workflows/` directory.

### GitLab CI

```yaml
yaml-lint:
  image:
    name: ghcr.io/<your-org>/ci-tooling-offline/yamllint:latest
    entrypoint: [""]
  script:
    - yamllint .
```

### Local

```sh
# Build locally
docker build \
  --build-arg YAMLLINT_VERSION=1.37.0 \
  -t ci-tooling-offline/yamllint:local tools/yamllint/

# Lint current directory
docker run --rm -v "$(pwd):/workspace" ci-tooling-offline/yamllint:local .

# Verify Python 3 and PyYAML are present
docker run --rm --entrypoint python3 ci-tooling-offline/yamllint:local -c "import yaml; print(yaml.__version__)"
```

## Configuration

Place a `.yamllint.yml` (or `.yamllint.yaml` or `.yamllint`) file in the root of your repository to customize rules. See the [yamllint documentation](https://yamllint.readthedocs.io/en/stable/configuration.html) for details.

## Running with act

```sh
cd your-project/
act push -W .gitea/workflows/yamllint.yml
```
