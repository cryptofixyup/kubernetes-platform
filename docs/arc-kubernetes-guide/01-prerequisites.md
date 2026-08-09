# 01. Prerequisites

## Cluster and access requirements

- Kubernetes 1.27+ with cluster-admin or delegated namespace/RBAC privileges.
- Helm 3.14+.
- Outbound HTTPS to `github.com`, `api.github.com`, `ghcr.io`, `pkg-containers.githubusercontent.com`, and package registries used by CI.
- A default `StorageClass` if you plan to customize runner work volumes beyond `emptyDir`.
- Node images that can sustain Docker-in-Docker CPU, memory, and ephemeral storage pressure.
- Dedicated node labels for ARC scheduling:
  - `workload=ci-general` for `general-runners`
  - `workload=ci-supabase` for `supabase-runners`

## Sizing guidance

Plan separately for the controller and for the runner pools.

| Component | Baseline | Production recommendation |
| --- | --- | --- |
| ARC controller | 0.25 vCPU / 256Mi | 2 replicas, 0.5 vCPU / 512Mi each |
| `general-runners` pod | 1 vCPU / 2Gi / 4Gi ephemeral storage | 1-2 warm runners |
| `supabase-runners` pod | 2 vCPU / 8Gi / 20Gi ephemeral storage | dedicated node pool preferred, with 10-12Gi limit headroom |
| DinD sidecar | privileged Docker daemon container in the same runner pod | reserve 2-3Gi for Docker plus 3-4Gi for Supabase services |

Use a separate node pool for `supabase-runners` if your cluster also runs latency-sensitive workloads.

ARC DinD mode is a dual-container model: the runner pod includes the `runner` container plus a privileged Docker daemon container that serves `docker` commands for `supabase start`. Size Supabase runners around the full pod footprint, not just the visible CI step:

- base runner process: ~2Gi
- Docker daemon and image extraction: ~2-3Gi
- Supabase services: ~3-4Gi

Avoid aggressively packing DinD runners onto production nodes just because steady-state usage looks lower; image pulls and service startup spikes are what usually trigger eviction or `OOMKilled` events.

## Tools checklist

```bash
kubectl version --client
helm version
openssl version
kubectl config current-context
```

## Permissions checklist

- Create namespaces, secrets, service accounts, roles, role bindings, CRDs, and deployments.
- Read nodes, storage classes, and network policies.
- Access controller and runner logs.

## Pre-flight validation

Run the bundled checker before installation:

```bash
./scripts/preflight-check.sh
```

Healthy run example:

```text
[ok] kubectl found
[ok] helm found
[ok] Connected to cluster context: production-us-east-1
[ok] Kubernetes server version v1.30.4 satisfies >= 1.27
[ok] Helm version v3.14.4 satisfies >= 3.14
[ok] Nodes discovered: 6
[ok] Default storage class: gp3
[ok] Namespace creation permissions confirmed
[ok] CRD creation permissions confirmed
[ok] Cluster-scoped RBAC creation permissions confirmed
[ok] In-cluster HTTPS egress to GitHub and GHCR succeeded
[ok] Privileged DinD pod admission is allowed in namespace: default
[ok] Found 3 node(s) labeled workload=ci-general
[ok] Found 3 node(s) labeled workload=ci-supabase
```

## Supabase-specific planning notes

- `supabase start` needs Docker, so use the DinD runner pool only for integration jobs.
- Reduce cold starts with image pre-pulls, a registry mirror, or `minRunners: 1` during business hours.
- Set memory alerts on runner nodes; Supabase services plus Docker pulls can spike above steady-state usage.
- If you see `OOMKilled` on either the `runner` or Docker daemon container, inspect both containers before lowering requests; under-sizing DinD runners is more dangerous than leaving modest headroom.
