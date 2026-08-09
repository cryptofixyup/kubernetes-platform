# 04. Runner scale sets

This repository ships two scale set values files:

- [`helm/values-general-runners.yaml`](../../helm/values-general-runners.yaml)
- [`helm/values-supabase-runners.yaml`](../../helm/values-supabase-runners.yaml)

## General runners

Use for lint, unit tests, type checks, and packaging.

Key settings:

- `runnerScaleSetName: general-runners`
- `runnerScaleSetLabels: [general-runners]`
- `minRunners: 1`
- `maxRunners: 10`
- no DinD sidecar

## Supabase runners

Use only for jobs that need `supabase start`, Docker builds, or service containers with elevated resource demand.

Key settings:

- `runnerScaleSetName: supabase-runners`
- `runnerScaleSetLabels: [supabase-runners, docker, supabase]`
- `containerMode.type: dind`
- `minRunners: 0`
- `maxRunners: 5`
- `requests.memory: 8Gi`
- higher CPU, memory, and ephemeral storage reservations

ARC `containerMode.type: dind` runs a dual-container pod: the GitHub runner container plus a privileged Docker daemon container. The bundled values reserve memory for both so `supabase start` can absorb image-pull and service-start bursts without starving the daemon.

## Installation commands

```bash
./scripts/install-arc.sh
```

The repository values files use `runnerScaleSetLabels` consistently. `scripts/install-arc.sh` keeps that naming intact in this guide while translating to the current ARC `0.14.2` chart input during installation.

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
- Do not reduce Supabase memory requests aggressively in production; the Docker daemon container often OOMs before GitHub job logs make the cause obvious.
