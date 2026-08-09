# kubernetes-platform

Production-grade Kubernetes platform infrastructure with ARC + Supabase CI.

## Repository baseline

This repository now establishes the human-authored baseline for a Kubernetes platform project.
It defines the intended repository layout, the current scope, and how generated assistant metadata fits around the actual project files.

## Current scope

The repository currently provides:

- baseline project documentation
- top-level directories for platform, cluster, and application assets
- committed ECC/Codex/Claude metadata used to support agent workflows in this repository

The repository does not yet provide:

- Kubernetes manifests or Helm charts
- Terraform or other infrastructure provisioning code
- application source code
- GitHub Actions workflows

## Intended stack

The intended platform stack is:

- Kubernetes as the deployment target
- Actions Runner Controller (ARC) for self-hosted GitHub Actions runners
- Supabase-backed CI or platform integration workflows where required by the project

As implementation is added, production assets should be placed under the human-authored directories documented below instead of being mixed into generated assistant metadata.

## Repository layout

- `/apps` - application-facing Kubernetes assets and service-specific deployment material
- `/clusters` - environment or cluster-specific configuration and overlays
- `/docs` - human-authored platform, operations, and contributor documentation
- `/platform` - shared platform components such as ARC, ingress, observability, and base services
- `/scripts` - repository-local operational and validation helpers

## Supported workflows

The current supported workflows are intentionally minimal:

1. document the repository baseline and intended structure
2. keep generated ECC artifacts under version control as supporting metadata
3. add real platform code and CI workflows incrementally into the documented directories

There is currently no build, lint, test, or deployment workflow implemented in this repository.

## Generated ECC artifacts

The `.claude`, `.codex`, and `.agents` directories are generated or agent-supporting repository metadata.
They are committed to help assistant tooling operate consistently in this repository, but they are not the platform implementation itself.

When updating the platform:

- place real infrastructure and documentation in the top-level project directories
- keep generated metadata changes scoped to tooling updates
- review generated-file diffs separately from human-authored platform changes

## Next implementation steps

- add real platform manifests, Helm charts, or infrastructure code under `/platform`, `/clusters`, and `/apps`
- add CI workflows under `.github/workflows` once executable validation exists
- add contributor and operations documentation as the platform structure becomes concrete
