# kubeconform-offline

Alpine-based container image bundling [kubeconform](https://github.com/yannh/kubeconform) and [kustomize](https://github.com/kubernetes-sigs/kustomize) with **offline** Kubernetes JSON schemas — no internet access required at runtime.

## What's inside

| Component     | Source                                                                                                                                          |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `kubeconform` | Latest release from [yannh/kubeconform](https://github.com/yannh/kubeconform)                                                                   |
| `kustomize`   | Latest release from [kubernetes-sigs/kustomize](https://github.com/kubernetes-sigs/kustomize)                                                   |
| JSON schemas  | v1.33 – v1.35, `standalone` + `standalone-strict` variants from [yannh/kubernetes-json-schema](https://github.com/yannh/kubernetes-json-schema) |
| CRD schemas   | All groups from [datreeio/CRDs-catalog](https://github.com/datreeio/CRDs-catalog)                                                               |

The image pre-configures two environment variables:

| Variable                   | Value                                                                                               |
| -------------------------- | --------------------------------------------------------------------------------------------------- |
| `$SCHEMA_LOCATION`         | `/schemas/{{.NormalizedKubernetesVersion}}-standalone-strict/{{.ResourceKind}}{{.KindSuffix}}.json` |
| `$DEFAULT_SCHEMA_LOCATION` | `/schemas/default-standalone-strict/{{.ResourceKind}}{{.KindSuffix}}.json`                          |
| `$CRD_SCHEMA_LOCATION`     | `/schemas/crd-catalog/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json`                    |

The latest bundled patch version is always symlinked as `/schemas/default-standalone-strict/` and `/schemas/default-standalone/`. Use `$DEFAULT_SCHEMA_LOCATION` to point kubeconform at them without specifying a concrete Kubernetes version.

## Usage

### GitLab CI withoot CRDs 

```yaml
validate:
  image:
    name: ghcr.io/<your-org>/kubeconform-offline:latest
    entrypoint: [""]
  script:
    - kubeconform
        -schema-location "/schemas/{{.NormalizedKubernetesVersion}}-standalone-strict/{{.ResourceKind}}{{.KindSuffix}}.json"
        -schema-location "/schemas/default-standalone-strict/{{.ResourceKind}}{{.KindSuffix}}.json"
        -summary manifests/

```

### GitLab CI with CRDs 

```yaml
validate:
  image:
    name: ghcr.io/<your-org>/kubeconform-offline:latest
    entrypoint: [""]
  script:
    - kubeconform
        -schema-location "/schemas/{{.NormalizedKubernetesVersion}}-standalone-strict/{{.ResourceKind}}{{.KindSuffix}}.json"
        -schema-location "/schemas/default-standalone-strict/{{.ResourceKind}}{{.KindSuffix}}.json"
        -schema-location "/schemas/crd-catalog/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json"
        -summary manifests/
```

### kustomize + kubeconform pipeline

```yaml
validate:
  image: ghcr.io/<your-org>/kubeconform-offline:latest
  entrypoint: [""]
  script:
    - kustomize build overlays/production 
    - kubeconform
        -schema-location "/schemas/{{.NormalizedKubernetesVersion}}-standalone-strict/{{.ResourceKind}}{{.KindSuffix}}.json"
        -schema-location "/schemas/default-standalone-strict/{{.ResourceKind}}{{.KindSuffix}}.json"
        -schema-location "/schemas/crd-catalog/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json"
        -summary manifests/

```

### Local

```sh
docker build \
  --build-arg KUBECONFORM_VERSION=v0.7.0 \
  --build-arg KUSTOMIZE_VERSION=v5.8.1 \
  -t kubeconform-offline:local .

# Pinned version
docker run --rm -v $(pwd)/:/workspace kubeconform-offline:local \
  -kubernetes-version 1.33.0 \
  -schema-location '/schemas/{{.NormalizedKubernetesVersion}}-standalone-strict/{{.ResourceKind}}{{.KindSuffix}}.json' \
  -summary .

# Latest bundled version via DEFAULT_SCHEMA_LOCATION (must expand env inside container)
docker run --rm -v $(pwd)/:/workspace --entrypoint sh kubeconform-offline:local \
  -c 'kubeconform -schema-location "$DEFAULT_SCHEMA_LOCATION" -summary .'
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

Use `$SCHEMA_LOCATION` together with `-kubernetes-version` to validate against a specific Kubernetes version:
```
-schema-location "$SCHEMA_LOCATION" -kubernetes-version 1.33.0
```

Use `$DEFAULT_SCHEMA_LOCATION` without `-kubernetes-version` to always validate against the latest bundled patch version:
```
-schema-location "$DEFAULT_SCHEMA_LOCATION"
```

Add `$CRD_SCHEMA_LOCATION` as a second `-schema-location` to also validate Custom Resources against the bundled CRD catalog:
```
-schema-location "$DEFAULT_SCHEMA_LOCATION" -schema-location "$CRD_SCHEMA_LOCATION"
```

Replace `-strict` with nothing in either K8s schema path to use the non-strict (more permissive) variant.
