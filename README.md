# kubernetes-platform

Microservice repository with a Bun gateway, a Python AI backend, and a React frontend component scaffold.

## Services

- `bun-gateway` - Bun-based API gateway, Stripe webhook ingress, and Redis-backed worker entrypoint
- `python-backend` - FastAPI service that streams AI responses
- `react-frontend` - frontend component scaffold for chat streaming
- `redis-cache` - Redis for queues and caching
- `postgres-db` - PostgreSQL with pgvector image for backend storage needs

## Quick start

1. Set the required environment variables:
   - `STRIPE_SECRET_KEY`
   - `STRIPE_WEBHOOK_SECRET`
   - `ANTHROPIC_API_KEY`
2. Run:

```sh
docker-compose up --build
```

## Repository layout

- `/docker-compose.yml` - local multi-service orchestration
- `/bun-gateway` - Bun gateway and webhook worker
- `/python-backend` - FastAPI AI backend
- `/react-frontend` - frontend chat component scaffold
- `/apps`, `/clusters`, `/docs`, `/platform`, `/scripts` - reserved platform baseline directories from the earlier repository bootstrap

## Notes

- The Bun gateway proxies authenticated chat requests to the Python backend.
- Stripe webhooks are queued through Redis before asynchronous worker processing.
- The React frontend file is a minimal component scaffold and is not yet wired into a full frontend build.
- The `.claude`, `.codex`, and `.agents` directories remain repository tooling metadata.
