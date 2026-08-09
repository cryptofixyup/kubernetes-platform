#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_APP_ID:?Set GITHUB_APP_ID}"
: "${GITHUB_APP_INSTALLATION_ID:?Set GITHUB_APP_INSTALLATION_ID}"
: "${GITHUB_APP_PRIVATE_KEY_FILE:?Set GITHUB_APP_PRIVATE_KEY_FILE}"

RUNNER_NS=${ARC_RUNNER_NAMESPACE:-arc-runners}
SECRET_NAME=${GITHUB_SECRET_NAME:-github-app-secret}

if [[ ! -f "$GITHUB_APP_PRIVATE_KEY_FILE" ]]; then
  echo "Private key file not found: $GITHUB_APP_PRIVATE_KEY_FILE"
  exit 1
fi

cat <<'EOF'
GitHub App requirements:
  - Homepage URL: https://github.com/actions/actions-runner-controller
  - Repository permissions: Administration (read/write for repo-scoped runners), Metadata (read-only)
  - Organization permissions: Self-hosted runners (read/write)
EOF

kubectl create namespace "$RUNNER_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic "$SECRET_NAME"       --namespace "$RUNNER_NS"       --from-literal=github_app_id="$GITHUB_APP_ID"       --from-literal=github_app_installation_id="$GITHUB_APP_INSTALLATION_ID"       --from-file=github_app_private_key="$GITHUB_APP_PRIVATE_KEY_FILE"       --dry-run=client -o yaml | kubectl apply -f -

echo "Created/updated secret '$SECRET_NAME' in namespace '$RUNNER_NS'."
echo "Restart listeners after rotation if you need immediate pickup:"
echo "kubectl rollout restart deployment -n $RUNNER_NS -l app.kubernetes.io/component=runner-scale-set-listener"
