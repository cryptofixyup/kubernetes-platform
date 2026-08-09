# Performance tuning recommendations

## Fast wins

- Keep `general-runners` warm with `minRunners: 1-2`.
- Use a registry mirror or pull-through cache for Supabase images.
- Pre-pull large CI images onto DinD nodes with a DaemonSet during low-traffic windows.
- Place `supabase-runners` on nodes with fast network and SSD-backed ephemeral disks.

## Node and pod tuning

- Right-size memory; DinD jobs fail more often from memory pressure than CPU starvation.
- Reserve extra ephemeral storage for Docker layers.
- Apply taints and tolerations so heavyweight runners do not evict business workloads.
- Enable cluster autoscaler expander policies that favor already-warm node groups when possible.

## Measuring success

Track:

- job queue time
- job startup latency
- image pull time
- runner pod scheduling latency
- runner success/failure rate by scale set
