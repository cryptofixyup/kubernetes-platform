# 07. Integration guide

## Pre-flight checks for existing clusters

- Confirm Pod Security admission or PSP replacements allow privileged DinD pods in the runner namespace.
- Confirm cluster autoscaler or Karpenter policies can scale the node pool selected by `supabase-runners`.
- Confirm observability agents tolerate short-lived pods.
- Confirm egress controls allow GitHub, GHCR, package registries, and Supabase downloads.

## Storage and volume considerations

ARC DinD mode uses `emptyDir` by default. For heavier jobs:

- prefer nodes with fast local SSD-backed ephemeral storage
- monitor node disk pressure
- increase ephemeral-storage requests and limits in the runner values file
- use a dedicated storage class only when switching away from default DinD behavior

## Network policies

Minimum egress destinations:

- `github.com`
- `api.github.com`
- `ghcr.io`
- `pkg-containers.githubusercontent.com`
- your language package registries
- any SaaS endpoints reached by integration tests

If your CNI supports FQDN policies, prefer explicit allow-lists for the runner namespace.

## Observability integration

- scrape controller and listener metrics with Prometheus
- add Grafana panels for queued jobs, registered runners, busy runners, and job startup latency
- ship controller and listener logs to ELK/Loki with labels for `namespace`, `scale_set`, and `repository`
- alert on auth failures, unschedulable runner pods, and prolonged queue depth

## High availability

- run 2 controller replicas
- spread controllers across nodes or zones
- keep the runner namespace separate from application namespaces
- use more than one node group when `supabase-runners` are mission critical

## Multi-region or multi-cluster patterns

- keep one ARC deployment per cluster
- shard runner scale sets by region or workload class
- use GitHub runner groups to steer repositories to the correct scale set
- keep runner names region-aware, for example `general-runners-us-east-1`
- test failover by draining one cluster and verifying queued jobs land on the alternate runner group
