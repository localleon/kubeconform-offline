# kubeconform-offline

Alpine-based container image bundling [kubeconform](https://github.com/yannh/kubeconform) and [kustomize](https://github.com/kubernetes-sigs/kustomize) with **offline** Kubernetes JSON schemas — no internet access required at runtime.

## What's inside

| Component     | Source                                                                                                                                          |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `kubeconform` | Latest release from [yannh/kubeconform](https://github.com/yannh/kubeconform)                                                                   |
| `kustomize`   | Latest release from [kubernetes-sigs/kustomize](https://github.com/kubernetes-sigs/kustomize)                                                   |
| JSON schemas  | v1.33 – v1.35, `standalone` + `standalone-strict` variants from [yannh/kubernetes-json-schema](https://github.com/yannh/kubernetes-json-schema) |

The `$SCHEMA_LOCATION` environment variable is pre-configured in the image:
```
/schemas/{{.NormalizedKubernetesVersion}}-standalone{{.StrictSuffix}}/{{.ResourceKind}}{{.KindSuffix}}.json
```

The latest major schema is always found under `/schemas/default-standalone-strict.json` or `/schemas/default-standalone.json` and should be used as a default in CI. 

## Usage

### GitLab CI

```yaml
validate:
  image: ghcr.io/<your-org>/kubeconform-offline:latest
  script:
    - kubeconform
        -kubernetes-version 1.33.0
        -schema-location "$SCHEMA_LOCATION"
        -summary
        manifests/
```

### kustomize + kubeconform pipeline

```yaml
validate:
  image: ghcr.io/<your-org>/kubeconform-offline:latest
  entrypoint: [""]
  script:
    - kustomize build overlays/production |
        kubeconform
          -kubernetes-version 1.33.0
          -schema-location "$SCHEMA_LOCATION"
          -summary -
```

### Local

```sh
docker build \
  --build-arg KUBECONFORM_VERSION=v0.7.0 \
  --build-arg KUSTOMIZE_VERSION=v5.8.1 \
  -t kubeconform-offline:local .

docker run --rm -v $(pwd)/:/workspace kubeconform-offline:local \
  -kubernetes-version 1.33.0 \
  -schema-location "$SCHEMA_LOCATION" \
  -summary .
```

## Automation

A GitHub Actions workflow ([`.github/workflows/build.yml`](.github/workflows/build.yml)) runs on the **1st and 15th of each month**. It:

1. Resolves the latest `kubeconform` and `kustomize` releases.
2. Skips the build if the current `kubeconform` tag has already been released.
3. Builds and pushes the image to `ghcr.io/<repo>:latest` and `ghcr.io/<repo>:<kubeconform-version>`.
4. Creates a GitHub Release with tool versions and usage examples.

Trigger a manual rebuild via **Actions → Build and Publish → Run workflow** (with optional *force rebuild* toggle).

## Local testing with act

```sh
cp .act.secrets.example .act.secrets
# fill in a PAT with repo + write:packages scopes

act schedule -W .github/workflows/build.yml
# or
act workflow_dispatch -W .github/workflows/build.yml
```

## Schema location flag

```
-schema-location '/schemas/{{.NormalizedKubernetesVersion}}-standalone{{.StrictSuffix}}/{{.ResourceKind}}{{.KindSuffix}}.json'
```

Omit `{{.StrictSuffix}}` (or pass `-ignore-missing-schemas`) to use the non-strict variant.
