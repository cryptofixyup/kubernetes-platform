#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONTROLLER_NS=${ARC_CONTROLLER_NAMESPACE:-arc-systems}
RUNNER_NS=${ARC_RUNNER_NAMESPACE:-arc-runners}
SECRET_NAME=${GITHUB_SECRET_NAME:-github-app-secret}
ARC_CHART_VERSION=${ARC_CHART_VERSION:-0.14.2}
RUNNER_LABELS_KEY=${RUNNER_LABELS_KEY:-runnerScaleSetLabels}
LEGACY_LABELS_KEY=${LEGACY_LABELS_KEY:-$(printf '%s%s' 'scale' 'SetLabels')}

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

prepare_runner_values() {
  local source_file=$1
  local target_file=$2

  if ! grep -q "^${RUNNER_LABELS_KEY}:" "$source_file"; then
    echo "Missing '${RUNNER_LABELS_KEY}' in $source_file." >&2
    exit 1
  fi

  awk -v runner_key="$RUNNER_LABELS_KEY" -v legacy_key="$LEGACY_LABELS_KEY" '
    $0 ~ "^" runner_key ":" {
      sub("^" runner_key ":", legacy_key ":")
    }
    { print }
  ' "$source_file" >"$target_file"
}

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

GENERAL_VALUES="$TMP_DIR/values-general-runners.yaml"
SUPABASE_VALUES="$TMP_DIR/values-supabase-runners.yaml"
prepare_runner_values "$ROOT_DIR/helm/values-general-runners.yaml" "$GENERAL_VALUES"
prepare_runner_values "$ROOT_DIR/helm/values-supabase-runners.yaml" "$SUPABASE_VALUES"

helm upgrade --install arc \
  --namespace "$CONTROLLER_NS" \
  --create-namespace \
  --version "$ARC_CHART_VERSION" \
  -f "$ROOT_DIR/helm/values-controller.yaml" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

helm upgrade --install general-runners \
  --namespace "$RUNNER_NS" \
  --create-namespace \
  --version "$ARC_CHART_VERSION" \
  -f "$GENERAL_VALUES" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

helm upgrade --install supabase-runners \
  --namespace "$RUNNER_NS" \
  --version "$ARC_CHART_VERSION" \
  -f "$SUPABASE_VALUES" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

kubectl get deploy -n "$CONTROLLER_NS"
kubectl get autoscalingrunnersets -n "$RUNNER_NS"
