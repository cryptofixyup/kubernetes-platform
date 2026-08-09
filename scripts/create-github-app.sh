#!/usr/bin/env bash
set -euo pipefail

RUNNER_NS=${ARC_RUNNER_NAMESPACE:-arc-runners}
SECRET_NAME=${GITHUB_SECRET_NAME:-github-app-secret}
GITHUB_APP_ID=${GITHUB_APP_ID:-}
GITHUB_APP_INSTALLATION_ID=${GITHUB_APP_INSTALLATION_ID:-}
GITHUB_APP_PRIVATE_KEY_FILE=${GITHUB_APP_PRIVATE_KEY_FILE:-}
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./scripts/create-github-app.sh [options]

Create or update the ARC GitHub App secret without committing the PEM to Git.

Options:
  --namespace <name>          Runner namespace (default: arc-runners or $ARC_RUNNER_NAMESPACE)
  --secret-name <name>        Secret name (default: github-app-secret or $GITHUB_SECRET_NAME)
  --app-id <id>               GitHub App ID (default: $GITHUB_APP_ID)
  --installation-id <id>      GitHub App installation ID (default: $GITHUB_APP_INSTALLATION_ID)
  --private-key-file <path>   Path to the GitHub App private key PEM (default: $GITHUB_APP_PRIVATE_KEY_FILE)
  --dry-run                   Print the Namespace and Secret YAML instead of applying it
  -h, --help                  Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)
      RUNNER_NS=${2:?Missing value for --namespace}
      shift 2
      ;;
    --secret-name)
      SECRET_NAME=${2:?Missing value for --secret-name}
      shift 2
      ;;
    --app-id)
      GITHUB_APP_ID=${2:?Missing value for --app-id}
      shift 2
      ;;
    --installation-id)
      GITHUB_APP_INSTALLATION_ID=${2:?Missing value for --installation-id}
      shift 2
      ;;
    --private-key-file)
      GITHUB_APP_PRIVATE_KEY_FILE=${2:?Missing value for --private-key-file}
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

: "${GITHUB_APP_ID:?Set GITHUB_APP_ID or pass --app-id}"
: "${GITHUB_APP_INSTALLATION_ID:?Set GITHUB_APP_INSTALLATION_ID or pass --installation-id}"
: "${GITHUB_APP_PRIVATE_KEY_FILE:?Set GITHUB_APP_PRIVATE_KEY_FILE or pass --private-key-file}"

if [[ ! -f "$GITHUB_APP_PRIVATE_KEY_FILE" ]]; then
  echo "Private key file not found: $GITHUB_APP_PRIVATE_KEY_FILE"
  exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  namespace_manifest=$(kubectl create namespace "$RUNNER_NS" --dry-run=client -o yaml)
  secret_manifest=$(kubectl create secret generic "$SECRET_NAME" \
    --namespace "$RUNNER_NS" \
    --from-literal=github_app_id="$GITHUB_APP_ID" \
    --from-literal=github_app_installation_id="$GITHUB_APP_INSTALLATION_ID" \
    --from-file=github_app_private_key="$GITHUB_APP_PRIVATE_KEY_FILE" \
    --dry-run=client -o yaml)
  printf '%s\n---\n%s\n' "$namespace_manifest" "$secret_manifest"
  exit 0
fi

kubectl create namespace "$RUNNER_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic "$SECRET_NAME" \
  --namespace "$RUNNER_NS" \
  --from-literal=github_app_id="$GITHUB_APP_ID" \
  --from-literal=github_app_installation_id="$GITHUB_APP_INSTALLATION_ID" \
  --from-file=github_app_private_key="$GITHUB_APP_PRIVATE_KEY_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Created/updated secret '$SECRET_NAME' in namespace '$RUNNER_NS'."
echo "Restart listeners after rotation if you need immediate pickup:"
echo "kubectl rollout restart deployment -n $RUNNER_NS -l app.kubernetes.io/component=runner-scale-set-listener"
