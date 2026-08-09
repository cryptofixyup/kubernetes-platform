# 04. Runner scale sets

This repository ships two scale set values files:

- [`helm/values-general-runners.yaml`](../../helm/values-general-runners.yaml)
- [`helm/values-supabase-runners.yaml`](../../helm/values-supabase-runners.yaml)

## General runners

Use for lint, unit tests, type checks, and packaging.

Key settings:

- `runnerScaleSetName: general-runners`
- `minRunners: 1`
- `maxRunners: 10`
- no DinD sidecar

## Supabase runners

Use only for jobs that need `supabase start`, Docker builds, or service containers with elevated resource demand.

Key settings:

- `runnerScaleSetName: supabase-runners`
- `containerMode.type: dind`
- `minRunners: 0`
- `maxRunners: 6`
- higher CPU, memory, and ephemeral storage reservations

## Installation commands

```bash
helm upgrade --install general-runners       --namespace arc-runners       -f helm/values-general-runners.yaml       oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

helm upgrade --install supabase-runners       --namespace arc-runners       -f helm/values-supabase-runners.yaml       oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

## Scale behavior

ARC targets approximately:

```text
desired runners = minRunners + assigned_jobs
```

capped by `maxRunners`.

## Validation commands

```bash
kubectl get autoscalingrunnersets -n arc-runners
kubectl get ephemeralrunnersets -n arc-runners
kubectl get pods -n arc-runners -w
./scripts/check-scaling.sh arc-runners 10
```

## Real-world tuning tips

- Keep `general-runners` warm with `minRunners: 1-2` to reduce queue latency.
- Start `supabase-runners` at `minRunners: 0` and add registry caching before increasing warm capacity.
- Pin runners to a dedicated node pool with taints if DinD jobs compete with app workloads.
- Add image pre-pull DaemonSets for Supabase images when cold starts dominate test time.
