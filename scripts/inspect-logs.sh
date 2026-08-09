#!/usr/bin/env bash
set -euo pipefail

COMPONENT=${1:-controller}
RUNNER_NS=${2:-arc-runners}
CONTROLLER_NS=${3:-arc-systems}
TAIL_LINES=${TAIL_LINES:-200}

case "$COMPONENT" in
  controller)
    kubectl logs -n "$CONTROLLER_NS" deploy/arc-gha-rs-controller --tail="$TAIL_LINES"
    ;;
  listener)
    kubectl logs -n "$RUNNER_NS" -l app.kubernetes.io/component=runner-scale-set-listener --tail="$TAIL_LINES"
    ;;
  runner)
    kubectl logs -n "$RUNNER_NS" -l actions.github.com/scale-set-name --all-containers=true --tail="$TAIL_LINES"
    ;;
  all)
    "$0" controller "$RUNNER_NS" "$CONTROLLER_NS"
    "$0" listener "$RUNNER_NS" "$CONTROLLER_NS"
    "$0" runner "$RUNNER_NS" "$CONTROLLER_NS"
    ;;
  *)
    echo "Usage: $0 {controller|listener|runner|all} [runner-namespace] [controller-namespace]"
    exit 1
    ;;
esac
