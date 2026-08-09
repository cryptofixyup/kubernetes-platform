#!/usr/bin/env bash
set -euo pipefail

RUNNER_NS=${1:-arc-runners}
INTERVAL=${2:-15}

while true; do
  date -u '+%Y-%m-%dT%H:%M:%SZ'
  kubectl get autoscalingrunnersets -n "$RUNNER_NS"
  echo
  kubectl get ephemeralrunnersets -n "$RUNNER_NS"
  echo
  kubectl get pods -n "$RUNNER_NS" -o wide
  echo "Sleeping for ${INTERVAL}s..."
  echo
  sleep "$INTERVAL"
done
