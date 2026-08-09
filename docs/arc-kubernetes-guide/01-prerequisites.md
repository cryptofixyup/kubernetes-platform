# 01. Prerequisites

## Cluster and access requirements

- Kubernetes 1.27+ with cluster-admin or delegated namespace/RBAC privileges.
- Helm 3.14+.
- Outbound HTTPS to `github.com`, `api.github.com`, `ghcr.io`, `pkg-containers.githubusercontent.com`, and package registries used by CI.
- A default `StorageClass` if you plan to customize runner work volumes beyond `emptyDir`.
- Node images that can sustain Docker-in-Docker CPU, memory, and ephemeral storage pressure.

## Sizing guidance

Plan separately for the controller and for the runner pools.

| Component | Baseline | Production recommendation |
| --- | --- | --- |
| ARC controller | 0.25 vCPU / 256Mi | 2 replicas, 0.5 vCPU / 512Mi each |
| `general-runners` pod | 1 vCPU / 2Gi / 4Gi ephemeral storage | 1-2 warm runners |
| `supabase-runners` pod | 2 vCPU / 6Gi / 20Gi ephemeral storage | dedicated node pool preferred |
| DinD sidecar | included in runner pod sizing | reserve extra 2-4Gi memory headroom |

Use a separate node pool for `supabase-runners` if your cluster also runs latency-sensitive workloads.

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
[ok] Nodes discovered: 6
[ok] Default storage class: gp3
[ok] Namespace creation permissions confirmed
```

## Supabase-specific planning notes

- `supabase start` needs Docker, so use the DinD runner pool only for integration jobs.
- Reduce cold starts with image pre-pulls, a registry mirror, or `minRunners: 1` during business hours.
- Set memory alerts on runner nodes; Supabase services plus Docker pulls can spike above steady-state usage.
