# FAQ

## Do I need Docker-in-Docker for every workflow?

No. Use DinD only for jobs that need `supabase start`, Docker builds, or nested container execution. Keep lint and unit tests on `general-runners`.

## Why are my Supabase jobs slower than hosted runners?

Cold nodes and repeated image pulls are the usual causes. Add registry caching, pre-pull images, or maintain a small warm pool.

## Can I use a PAT instead of a GitHub App?

Yes, but a GitHub App is the recommended production path because it provides narrower scope and simpler rotation.

## Where should workflow files live?

The examples are stored in `workflows/` in this repository. Copy them into `.github/workflows/` in the application repository that will execute the jobs.

## How do I verify a runner registered correctly?

Check `kubectl get autoscalingrunnersets -n arc-runners`, then inspect listener logs and confirm the runner appears in the expected GitHub runner group.
