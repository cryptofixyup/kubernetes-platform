# 06. Troubleshooting

## Fast decision tree

1. **Job queued forever** -> inspect listener logs and `AutoScalingRunnerSet` status.
2. **Runner pod created but job never starts** -> check GitHub App auth, runner group access, and network egress.
3. **Supabase tests fail intermittently** -> inspect DinD memory pressure, ephemeral storage, and Docker pull latency.
4. **Scale set oscillates** -> compare queued job rate with `maxRunners`, node autoscaler latency, and pod scheduling events.

## Core commands

```bash
kubectl get autoscalingrunnersets -n arc-runners
kubectl get ephemeralrunnersets -n arc-runners
kubectl get ephemeralrunners -n arc-runners
kubectl describe autoscalingrunnerset general-runners -n arc-runners
kubectl logs -n arc-systems deploy/arc-gha-rs-controller --tail=200
kubectl logs -n arc-runners -l app.kubernetes.io/component=runner-scale-set-listener --tail=200
```

## Common failure modes

| Symptom | Likely cause | Diagnostic |
| --- | --- | --- |
| `401` or `403` in listener logs | bad app ID, installation ID, or key | recreate secret and restart listener |
| Pods pending | insufficient CPU, memory, or taint mismatch | `kubectl describe pod` and node events |
| Docker daemon never becomes ready | DinD sidecar starved or blocked by PodSecurity | inspect runner pod logs for `dind` container |
| Registration succeeds, job never assigned | runner group or repo scope mismatch | verify `githubConfigUrl` and runner group mapping |
| Long cold starts | image pulls and node scale-up delay | inspect node autoscaler and pre-pull strategy |

## Log inspection workflow

```bash
./scripts/inspect-logs.sh controller
./scripts/inspect-logs.sh listener arc-runners
./scripts/inspect-logs.sh runner arc-runners
```

## Resource debugging

```bash
kubectl top pods -n arc-runners
kubectl describe pod <runner-pod> -n arc-runners
kubectl get events -n arc-runners --sort-by=.lastTimestamp
```

## Network validation

```bash
kubectl run curl-check -n arc-runners --rm -it       --image=curlimages/curl:8.9.1 --restart=Never --       curl -I https://api.github.com
```

## Scaling analysis

Use the bundled watcher during load tests:

```bash
./scripts/check-scaling.sh arc-runners 15
```
