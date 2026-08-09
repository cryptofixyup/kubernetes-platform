#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONTROLLER_NS=${ARC_CONTROLLER_NAMESPACE:-arc-systems}
RUNNER_NS=${ARC_RUNNER_NAMESPACE:-arc-runners}
SECRET_NAME=${GITHUB_SECRET_NAME:-github-app-secret}

if grep -R "YOUR_ORG" "$ROOT_DIR/helm"/values-*.yaml >/dev/null 2>&1; then
  echo "Update githubConfigUrl in helm/values-*.yaml before installing ARC."
  exit 1
fi

kubectl create namespace "$CONTROLLER_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "$RUNNER_NS" --dry-run=client -o yaml | kubectl apply -f -

if ! kubectl get secret "$SECRET_NAME" -n "$RUNNER_NS" >/dev/null 2>&1; then
  echo "Missing secret '$SECRET_NAME' in namespace '$RUNNER_NS'. Run scripts/create-github-app.sh first."
  exit 1
fi

helm upgrade --install arc       --namespace "$CONTROLLER_NS"       --create-namespace       -f "$ROOT_DIR/helm/values-controller.yaml"       oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

helm upgrade --install general-runners       --namespace "$RUNNER_NS"       --create-namespace       -f "$ROOT_DIR/helm/values-general-runners.yaml"       oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

helm upgrade --install supabase-runners       --namespace "$RUNNER_NS"       -f "$ROOT_DIR/helm/values-supabase-runners.yaml"       oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

kubectl get deploy -n "$CONTROLLER_NS"
kubectl get autoscalingrunnersets -n "$RUNNER_NS"
