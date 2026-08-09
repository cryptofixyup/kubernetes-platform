# ARC on Kubernetes for Supabase CI

This guide is for platform engineers who need production-grade, autoscaling GitHub Actions runners on Kubernetes and want a clean split between lightweight CI jobs and Supabase integration workloads.

## What you get

- ARC controller installation with Helm.
- GitHub App authentication and secret rotation guidance.
- Two runner scale sets:
  - `general-runners` for lint/unit/build jobs.
  - `supabase-runners` for heavier Docker-in-Docker jobs.
- Copy-paste-ready Helm values, workflows, and operational scripts.
- Troubleshooting and integration guidance for existing clusters.

## Recommended namespace model

| Namespace | Purpose |
| --- | --- |
| `arc-systems` | ARC controller, leader election, metrics, webhooks |
| `arc-runners` | Listener pods, ephemeral runners, GitHub App secret |

## Quick start

```bash
./scripts/preflight-check.sh
./scripts/create-github-app.sh
./scripts/install-arc.sh
kubectl get autoscalingrunnersets -n arc-runners
```

Expected healthy output after installation:

```text
NAME                MIN   MAX   CURRENT   READY
general-runners     1     10    1         1
supabase-runners    0     5     0         0
```

## Guide map

1. [Prerequisites](01-prerequisites.md)
2. [Helm installation](02-helm-installation.md)
3. [GitHub App setup](03-github-app-setup.md)
4. [Runner scale sets](04-runner-scale-sets.md)
5. [Supabase workflows](05-supabase-workflows.md)
6. [Troubleshooting](06-troubleshooting.md)
7. [Integration guide](07-integration-guide.md)
