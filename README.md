# kubernetes-platform

Production-grade Kubernetes platform infrastructure with ARC + Supabase CI.

This repository contains a deployment and operations guide for running GitHub Actions Runner Controller (ARC) on Kubernetes with dedicated runner pools for Supabase CI.

## Repository layout

```text
docs/
├── arc-kubernetes-guide/
│   ├── README.md
│   ├── 01-prerequisites.md
│   ├── 02-helm-installation.md
│   ├── 03-github-app-setup.md
│   ├── 04-runner-scale-sets.md
│   ├── 05-supabase-workflows.md
│   ├── 06-troubleshooting.md
│   └── 07-integration-guide.md
├── FAQ.md
├── PERFORMANCE.md
└── SECURITY.md
helm/
├── values-controller.yaml
├── values-general-runners.yaml
└── values-supabase-runners.yaml
workflows/
├── supabase-integration.yaml
├── supabase-lint-unit.yaml
└── supabase-matrix.yaml
scripts/
├── check-scaling.sh
├── create-github-app.sh
├── diagnose-runners.sh
├── inspect-logs.sh
├── install-arc.sh
└── preflight-check.sh
```

## Quick start

1. Read [`docs/arc-kubernetes-guide/01-prerequisites.md`](docs/arc-kubernetes-guide/01-prerequisites.md).
2. Run [`scripts/preflight-check.sh`](scripts/preflight-check.sh) against your cluster.
3. Create the GitHub App secret with [`scripts/create-github-app.sh`](scripts/create-github-app.sh) as described in [`docs/arc-kubernetes-guide/03-github-app-setup.md`](docs/arc-kubernetes-guide/03-github-app-setup.md).
4. Install ARC with [`scripts/install-arc.sh`](scripts/install-arc.sh).
5. Copy the example workflows from [`workflows/`](workflows/) into `.github/workflows/` in the application repository that will use the runners.

The guide assumes two runner pools:

- `general-runners` for fast lint/unit jobs.
- `supabase-runners` for Docker-in-Docker (DinD) integration jobs that run `supabase start`.
