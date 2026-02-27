# kubeconform (ci-tooling-offline)

Alpine-based container image bundling [kubeconform](https://github.com/yannh/kubeconform) and [kustomize](https://github.com/kubernetes-sigs/kustomize) with **offline** Kubernetes JSON schemas — no internet access required at runtime.

## What's inside

| Component     | Source                                                                                                                                          |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `kubeconform` | Latest release from [yannh/kubeconform](https://github.com/yannh/kubeconform)                                                                   |
| `kustomize`   | Latest release from [kubernetes-sigs/kustomize](https://github.com/kubernetes-sigs/kustomize)                                                   |
| JSON schemas  | v1.33 – v1.35, `standalone` + `standalone-strict` variants from [yannh/kubernetes-json-schema](https://github.com/yannh/kubernetes-json-schema) |
| CRD schemas   | All groups from [datreeio/CRDs-catalog](https://github.com/datreeio/CRDs-catalog)                                                               |

## Environment variables

The image pre-configures three environment variables:

| Variable                   | Value                                                                                               |
| -------------------------- | --------------------------------------------------------------------------------------------------- |
| `$SCHEMA_LOCATION`         | `/schemas/{{.NormalizedKubernetesVersion}}-standalone-strict/{{.ResourceKind}}{{.KindSuffix}}.json` |
| `$DEFAULT_SCHEMA_LOCATION` | `/schemas/default-standalone-strict/{{.ResourceKind}}{{.KindSuffix}}.json`                          |
| `$CRD_SCHEMA_LOCATION`     | `/schemas/crd-catalog/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json`                    |

The latest bundled patch version is always symlinked as `/schemas/default-standalone-strict/` and `/schemas/default-standalone/`. Use `$DEFAULT_SCHEMA_LOCATION` to validate without specifying a concrete Kubernetes version.

## Usage

### Gitea Actions

Copy [`examples/gitea-workflow.yml`](examples/gitea-workflow.yml) into your project's `.gitea/workflows/` directory.

### GitLab CI (without CRDs)

```yaml
validate:
  image:
    name: ghcr.io/<your-org>/ci-tooling-offline/kubeconform:latest
    entrypoint: [""]
  script:
    - kubeconform
        -schema-location "$SCHEMA_LOCATION"
        -schema-location "$DEFAULT_SCHEMA_LOCATION"
        -summary manifests/
```

### GitLab CI (with CRDs)

```yaml
validate:
  image:
    name: ghcr.io/<your-org>/ci-tooling-offline/kubeconform:latest
    entrypoint: [""]
  script:
    - kubeconform
        -schema-location "$SCHEMA_LOCATION"
        -schema-location "$DEFAULT_SCHEMA_LOCATION"
        -schema-location "$CRD_SCHEMA_LOCATION"
        -summary manifests/
```

### kustomize + kubeconform pipeline

```yaml
validate:
  image:
    name: ghcr.io/<your-org>/ci-tooling-offline/kubeconform:latest
    entrypoint: [""]
  script:
    - kustomize build overlays/production |
        kubeconform
          -kubernetes-version 1.33.0
          -schema-location "$SCHEMA_LOCATION"
          -schema-location "$DEFAULT_SCHEMA_LOCATION"
          -schema-location "$CRD_SCHEMA_LOCATION"
          -summary -
```

### Local

```sh
# Build locally (from repo root)
docker build \
  --build-arg KUBECONFORM_VERSION=v0.7.0 \
  --build-arg KUSTOMIZE_VERSION=v5.8.1 \
  -t ci-tooling-offline/kubeconform:local tools/kubeconform/

# Validate manifests with a pinned version
docker run --rm -v "$(pwd):/workspace" ci-tooling-offline/kubeconform:local \
  -kubernetes-version 1.33.0 \
  -schema-location '/schemas/{{.NormalizedKubernetesVersion}}-standalone-strict/{{.ResourceKind}}{{.KindSuffix}}.json' \
  -summary .

# Use DEFAULT_SCHEMA_LOCATION (must expand env inside container)
docker run --rm -v "$(pwd):/workspace" --entrypoint sh ci-tooling-offline/kubeconform:local \
  -c 'kubeconform -schema-location "$DEFAULT_SCHEMA_LOCATION" -summary .'
```

## Schema location flags

Use `$SCHEMA_LOCATION` together with `-kubernetes-version` to validate against a specific Kubernetes version:
```
-schema-location "$SCHEMA_LOCATION" -kubernetes-version 1.33.0
```

Use `$DEFAULT_SCHEMA_LOCATION` without `-kubernetes-version` to validate against the latest bundled patch version:
```
-schema-location "$DEFAULT_SCHEMA_LOCATION"
```

Add `$CRD_SCHEMA_LOCATION` as a second `-schema-location` to also validate Custom Resources against the bundled CRD catalog:
```
-schema-location "$DEFAULT_SCHEMA_LOCATION" -schema-location "$CRD_SCHEMA_LOCATION"
```

Replace `-strict` with nothing in either K8s schema path to use the non-strict (more permissive) variant.
