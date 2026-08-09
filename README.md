# kubernetes-platform

Production-grade Kubernetes platform infrastructure with ARC + Supabase CI, plus a local microservice scaffold with a Bun gateway, a Python AI backend, and a React frontend component.

This repository contains:

- a deployment and operations guide for running GitHub Actions Runner Controller (ARC) on Kubernetes with dedicated runner pools for Supabase CI
- a local development scaffold for the Bun gateway, Python backend, React frontend, Redis, and PostgreSQL services

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
bun-gateway/
python-backend/
react-frontend/
docker-compose.yml
```

## ARC quick start

1. Read [`docs/arc-kubernetes-guide/01-prerequisites.md`](docs/arc-kubernetes-guide/01-prerequisites.md).
2. Run [`scripts/preflight-check.sh`](scripts/preflight-check.sh) against your cluster.
3. Create the GitHub App secret with [`scripts/create-github-app.sh`](scripts/create-github-app.sh) as described in [`docs/arc-kubernetes-guide/03-github-app-setup.md`](docs/arc-kubernetes-guide/03-github-app-setup.md).
4. Install ARC with [`scripts/install-arc.sh`](scripts/install-arc.sh).
5. Copy the example workflows from [`workflows/`](workflows/) into `.github/workflows/` in the application repository that will use the runners.

The guide assumes two runner pools:

- `general-runners` for fast lint/unit jobs
- `supabase-runners` for Docker-in-Docker (DinD) integration jobs that run `supabase start`

## Local services

- `bun-gateway` - Bun-based API gateway, Stripe webhook ingress, and Redis-backed worker entrypoint
- `python-backend` - FastAPI service that streams AI responses
- `react-frontend` - frontend component scaffold for chat streaming
- `redis-cache` - Redis for queues and caching
- `postgres-db` - PostgreSQL with pgvector image for backend storage needs

## Local development quick start

1. Set the required environment variables:
   - `STRIPE_SECRET_KEY`
   - `STRIPE_WEBHOOK_SECRET`
   - `ANTHROPIC_API_KEY`
   - `POSTGRES_USER` (optional, defaults to `user`)
   - `POSTGRES_PASSWORD` (optional, defaults to `password`)
   - `POSTGRES_DB` (optional, defaults to `saas_db`)
2. Run:

```sh
docker-compose up --build
```

## Notes

- The Bun gateway proxies authenticated chat requests to the Python backend.
- Stripe webhooks are queued through Redis before asynchronous worker processing.
- The React frontend file is a minimal component scaffold and expects `VITE_BACKEND_URL` when used outside local development.
- The gateway currently uses permissive wildcard CORS for local development and should be restricted before broader deployment.
- The auth middleware, rate limiter, and webhook persistence logic are local-development stubs and must be replaced before production use.
- The default Postgres values are for local development only and should be overridden in any shared or production environment.
- The `.claude`, `.codex`, and `.agents` directories remain repository tooling metadata.
