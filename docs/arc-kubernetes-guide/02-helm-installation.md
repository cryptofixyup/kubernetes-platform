# 02. Helm installation

## Namespaces and RBAC layout

Create dedicated namespaces to isolate controller and runner resources:

```bash
kubectl create namespace arc-systems
kubectl create namespace arc-runners
```

The controller chart creates its own service account and cluster-scoped permissions. Runner scale sets remain namespaced and bind back to the controller service account.

## Helm chart source

ARC is distributed as OCI charts from GHCR:

```bash
helm show values oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
helm show values oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

## Install the controller

```bash
helm upgrade --install arc       --namespace arc-systems       --create-namespace       -f helm/values-controller.yaml       oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
```

The bundled [`helm/values-controller.yaml`](../../helm/values-controller.yaml) enables:

- 2 controller replicas for HA.
- Metrics endpoints for Prometheus scraping.
- Readiness and liveness health probes.
- Conservative resource requests.

## Install runner scale sets

After the GitHub App secret exists in `arc-runners`:

```bash
helm upgrade --install general-runners       --namespace arc-runners       --create-namespace       -f helm/values-general-runners.yaml       oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

helm upgrade --install supabase-runners       --namespace arc-runners       -f helm/values-supabase-runners.yaml       oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

## Verification and health checks

```bash
kubectl get deploy -n arc-systems
kubectl get autoscalingrunnersets -n arc-runners
kubectl get pods -n arc-runners
kubectl logs -n arc-systems deploy/arc-gha-rs-controller -f
```

Expected controller status:

```text
NAME                       READY   UP-TO-DATE   AVAILABLE
arc-gha-rs-controller      2/2     2            2
```

Expected runner status after one queued job:

```text
NAME                                      READY   STATUS
general-runners-listener                  1/1     Running
general-runners-7k6px-runner-zv7fr        2/2     Running
```

## Common installation pitfalls

- Secret missing in `arc-runners` -> listener loops on GitHub auth failures.
- `watchSingleNamespace` configured without matching runner chart values -> permission errors.
- Cluster egress blocked to GHCR -> runner image pulls fail before registration.
