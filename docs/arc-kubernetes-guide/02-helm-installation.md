# 02. Helm installation

## Namespaces and RBAC layout

Create dedicated namespaces to isolate controller and runner resources:

```bash
kubectl create namespace arc-systems
kubectl create namespace arc-runners
```

The controller chart creates its own service account and cluster-scoped permissions. Runner scale sets remain namespaced and bind back to the controller service account.

## Label runner nodes before installation

Apply labels that match the bundled `nodeSelector` settings before installing the scale sets:

```bash
kubectl label nodes <general-node-1> <general-node-2> workload=ci-general --overwrite
kubectl label nodes <supabase-node-1> <supabase-node-2> workload=ci-supabase --overwrite
kubectl get nodes -L workload
```

Use separate node pools when possible so DinD-heavy Supabase jobs do not compete with latency-sensitive application workloads.

## Helm chart source

ARC is distributed as OCI charts from GHCR:

```bash
helm show values --version 0.14.2 oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
helm show values --version 0.14.2 oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

## Install the controller

```bash
helm upgrade --install arc       --namespace arc-systems       --create-namespace       --version 0.14.2       -f helm/values-controller.yaml       oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
```

The bundled [`helm/values-controller.yaml`](../../helm/values-controller.yaml) enables:

- 2 controller replicas for HA.
- Metrics endpoints for Prometheus scraping.
- Readiness and liveness health probes.
- Conservative resource requests.
- Controller image pinning by digest (`ghcr.io/actions/gha-runner-scale-set-controller@sha256:3081ba15c41f0aa791058dedd2a7406fece24c9aeaa94956c268e5099427a452`).

## Install runner scale sets

After the GitHub App secret exists in `arc-runners`:

```bash
./scripts/install-arc.sh
```

The helper script pins chart version `0.14.2` for the controller and both runner scale sets. It also translates the repository's `runnerScaleSetLabels` setting into the current chart input expected by ARC `0.14.2`, while the rendered `AutoScalingRunnerSet` still uses `runnerScaleSetLabels`.

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
