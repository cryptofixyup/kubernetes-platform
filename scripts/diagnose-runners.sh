#!/usr/bin/env bash
set -euo pipefail

RUNNER_NS=${1:-arc-runners}
CONTROLLER_NS=${2:-arc-systems}
SCALE_SET=${3:-}

kubectl get autoscalingrunnersets,ephemeralrunnersets,ephemeralrunners -n "$RUNNER_NS" || true
kubectl get pods -n "$RUNNER_NS" -o wide || true
kubectl get events -n "$RUNNER_NS" --sort-by=.lastTimestamp | tail -n 50 || true

if [[ -n "$SCALE_SET" ]]; then
  kubectl describe autoscalingrunnerset "$SCALE_SET" -n "$RUNNER_NS" || true
fi

echo "--- controller logs ---"
kubectl logs -n "$CONTROLLER_NS" deploy/arc-gha-rs-controller --tail=200 || true

echo "--- listener logs ---"
kubectl logs -n "$RUNNER_NS" -l app.kubernetes.io/component=runner-scale-set-listener --tail=200 || true
