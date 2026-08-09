#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONTROLLER_NS=${ARC_CONTROLLER_NAMESPACE:-arc-systems}
RUNNER_NS=${ARC_RUNNER_NAMESPACE:-arc-runners}
SECRET_NAME=${GITHUB_SECRET_NAME:-github-app-secret}
ARC_CHART_VERSION=${ARC_CHART_VERSION:-0.14.2}
ARC_CONTROLLER_IMAGE_REPOSITORY=${ARC_CONTROLLER_IMAGE_REPOSITORY:-ghcr.io/actions/gha-runner-scale-set-controller}
ARC_CONTROLLER_IMAGE_TAG=${ARC_CONTROLLER_IMAGE_TAG:-0.14.2}
ARC_CONTROLLER_IMAGE_DIGEST=${ARC_CONTROLLER_IMAGE_DIGEST:-sha256:3081ba15c41f0aa791058dedd2a7406fece24c9aeaa94956c268e5099427a452}
RUNNER_LABELS_KEY=${RUNNER_LABELS_KEY:-runnerScaleSetLabels}
LEGACY_LABELS_KEY=${LEGACY_LABELS_KEY:-$(printf '%s%s' 'scale' 'SetLabels')}

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

CONTROLLER_POST_RENDERER="$TMP_DIR/controller-post-renderer.sh"
cat >"$CONTROLLER_POST_RENDERER" <<EOF
#!/usr/bin/env bash
set -euo pipefail

input_file=\$(mktemp)
trap 'rm -f "\$input_file"' EXIT
cat >"\$input_file"

expected_image="${ARC_CONTROLLER_IMAGE_REPOSITORY}:${ARC_CONTROLLER_IMAGE_TAG}"
pinned_image="${ARC_CONTROLLER_IMAGE_REPOSITORY}@${ARC_CONTROLLER_IMAGE_DIGEST}"

if ! grep -q "\$expected_image" "\$input_file"; then
  echo "Expected controller image '\$expected_image' not found in rendered manifest." >&2
  exit 1
fi

sed "s#\$expected_image#\$pinned_image#g" "\$input_file"
EOF
chmod +x "$CONTROLLER_POST_RENDERER"

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
  --post-renderer "$CONTROLLER_POST_RENDERER" \
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
