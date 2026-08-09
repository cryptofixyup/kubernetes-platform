# 05. Supabase workflows

The example workflow files live in [`workflows/`](../../workflows/). Copy them into `.github/workflows/` in the application repository that will use ARC.

## Workflow mapping

| File | Runner pool | Use case |
| --- | --- | --- |
| `supabase-lint-unit.yaml` | `general-runners` | lint, unit tests, type checks |
| `supabase-integration.yaml` | `supabase-runners` | `supabase start`, integration tests, service validation |
| `supabase-matrix.yaml` | mixed | split fast and heavy jobs in one workflow |

## Environment variables and secrets

Define application-specific secrets in the consuming repository:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_DB_PASSWORD`
- `NEXT_PUBLIC_SUPABASE_URL` or equivalent runtime values
- package registry credentials if private dependencies are used

Prefer GitHub environments for promotion-specific secrets.

## Caching strategy

- Use `actions/setup-node` cache for npm dependencies.
- Cache build outputs only when hit rates are consistently high.
- For DinD workloads, prefer registry mirrors or pre-pulled node images over local Docker layer cache because ARC runners are ephemeral.
- Upload Supabase logs as artifacts when integration tests fail.

## Expected job behavior

- `general-runners` jobs should start in seconds when warm runners exist.
- `supabase-runners` jobs may spend extra time pulling Docker images on cold nodes.
- Runners should deregister automatically after each job completes.
