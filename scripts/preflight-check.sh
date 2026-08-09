#!/usr/bin/env bash
set -euo pipefail

fail=0
required_tools=(kubectl helm openssl awk sed grep curl mktemp)
minimum_kubernetes_minor=27
minimum_helm_minor=14
general_workload_label=ci-general
supabase_workload_label=ci-supabase

ok() {
  echo "[ok] $*"
}

warn() {
  echo "[warn] $*"
}

error() {
  echo "[error] $*"
  fail=1
}

normalize_version() {
  printf '%s' "${1#v}" | sed 's/[+-].*$//'
}

version_at_least() {
  local version=$1
  local expected_major=$2
  local expected_minor=$3
  local major minor patch

  IFS=. read -r major minor patch <<<"$(normalize_version "$version")"
  major=${major:-0}
  minor=${minor:-0}

  if (( major > expected_major )); then
    return 0
  fi

  if (( major == expected_major && minor >= expected_minor )); then
    return 0
  fi

  return 1
}

probe_namespace() {
  local configured_namespace

  configured_namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || true)
  if [[ -n "$configured_namespace" ]]; then
    printf '%s\n' "$configured_namespace"
  else
    printf 'default\n'
  fi
}

network_probe() {
  local namespace=$1
  local pod_name="arc-preflight-egress-$RANDOM"
  local urls=(
    "https://github.com"
    "https://api.github.com"
    "https://ghcr.io"
  )
  local phase=
  local attempt=

  kubectl delete pod "$pod_name" -n "$namespace" --ignore-not-found >/dev/null 2>&1 || true

  if ! kubectl run "$pod_name" \
    -n "$namespace" \
    --image=curlimages/curl:8.9.1 \
    --restart=Never \
    --command -- sh -ceu '
      for url in "$@"; do
        echo "probing ${url}"
        curl -fsSIL --retry 2 --connect-timeout 10 --max-time 20 "$url" >/dev/null
      done
    ' -- "${urls[@]}" >/dev/null 2>&1; then
    error "Unable to start in-cluster egress probe pod in namespace '$namespace'"
    return
  fi

  for attempt in {1..24}; do
    phase=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null || true)
    case "$phase" in
      Succeeded)
        ok "In-cluster HTTPS egress to GitHub and GHCR succeeded"
        kubectl delete pod "$pod_name" -n "$namespace" --ignore-not-found >/dev/null 2>&1 || true
        return
        ;;
      Failed)
        error "In-cluster HTTPS egress probe failed"
        kubectl logs "$pod_name" -n "$namespace" 2>/dev/null || true
        kubectl delete pod "$pod_name" -n "$namespace" --ignore-not-found >/dev/null 2>&1 || true
        return
        ;;
    esac
    sleep 5
  done

  error "Timed out waiting for in-cluster egress probe pod in namespace '$namespace'"
  kubectl describe pod "$pod_name" -n "$namespace" 2>/dev/null || true
  kubectl delete pod "$pod_name" -n "$namespace" --ignore-not-found >/dev/null 2>&1 || true
}

for tool in "${required_tools[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool found"
  else
    error "$tool not found"
    fail=1
  fi
done

if [[ "$fail" -ne 0 ]]; then
  exit "$fail"
fi

context=$(kubectl config current-context 2>/dev/null || true)
if [[ -z "$context" ]]; then
  error "kubectl has no current context"
  exit 1
fi
ok "Connected to cluster context: $context"

server_version=$(kubectl version -o yaml 2>/dev/null | awk '
  $1 == "serverVersion:" { in_server=1; next }
  in_server && $1 == "gitVersion:" { gsub(/"/, "", $2); print $2; exit }
')
if [[ -z "$server_version" ]]; then
  error "Unable to determine Kubernetes server version"
elif version_at_least "$server_version" 1 "$minimum_kubernetes_minor"; then
  ok "Kubernetes server version ${server_version} satisfies >= 1.${minimum_kubernetes_minor}"
else
  error "Kubernetes server version ${server_version} is below 1.${minimum_kubernetes_minor}"
fi

helm_version=$(helm version --template '{{ .Version }}' 2>/dev/null || true)
if [[ -z "$helm_version" ]]; then
  error "Unable to determine Helm version"
elif version_at_least "$helm_version" 3 "$minimum_helm_minor"; then
  ok "Helm version ${helm_version} satisfies >= 3.${minimum_helm_minor}"
else
  error "Helm version ${helm_version} is below 3.${minimum_helm_minor}"
fi

nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
ok "Nodes discovered: $nodes"
if [[ "$nodes" -eq 0 ]]; then
  error "No nodes found in the current cluster context"
  exit 1
fi

default_sc=$(kubectl get storageclass 2>/dev/null | awk '/\(default\)/ {print $1; exit}')
if [[ -n "$default_sc" ]]; then
  ok "Default storage class: $default_sc"
else
  warn "No default storage class detected"
fi

if kubectl auth can-i create namespaces >/dev/null 2>&1; then
  ok "Namespace creation permissions confirmed"
else
  error "Current identity cannot create namespaces"
fi

if kubectl auth can-i create customresourcedefinitions.apiextensions.k8s.io >/dev/null 2>&1; then
  ok "CRD creation permissions confirmed"
else
  error "Current identity cannot create CustomResourceDefinitions"
fi

if kubectl auth can-i create clusterroles.rbac.authorization.k8s.io >/dev/null 2>&1 &&
  kubectl auth can-i create clusterrolebindings.rbac.authorization.k8s.io >/dev/null 2>&1; then
  ok "Cluster-scoped RBAC creation permissions confirmed"
else
  error "Current identity cannot create required cluster-scoped RBAC resources"
fi

namespace_for_probes=$(probe_namespace)
if kubectl auth can-i create pods -n "$namespace_for_probes" >/dev/null 2>&1; then
  ok "Pod creation permissions confirmed in namespace: $namespace_for_probes"
  network_probe "$namespace_for_probes"
else
  warn "Cannot create probe pods in namespace '$namespace_for_probes'; falling back to local HTTPS checks only"
  for url in https://github.com https://api.github.com https://ghcr.io; do
    if curl -fsSIL --retry 2 --connect-timeout 10 --max-time 20 "$url" >/dev/null; then
      ok "Local HTTPS reachability confirmed for $url"
    else
      error "Local HTTPS reachability failed for $url"
    fi
  done
fi

if cat <<EOF | kubectl apply --dry-run=server -n "$namespace_for_probes" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: arc-preflight-privileged
spec:
  restartPolicy: Never
  containers:
    - name: dind-smoke
      image: docker:27.1.1-dind
      command: ["sh", "-c", "echo privileged-check"]
      securityContext:
        privileged: true
EOF
then
  ok "Privileged DinD pod admission is allowed in namespace: $namespace_for_probes"
else
  error "Privileged DinD pod admission was denied in namespace: $namespace_for_probes"
fi

echo "[info] Node workload labels"
kubectl get nodes -L workload

general_nodes=$(kubectl get nodes -l "workload=${general_workload_label}" --no-headers 2>/dev/null | wc -l | tr -d ' ')
supabase_nodes=$(kubectl get nodes -l "workload=${supabase_workload_label}" --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [[ "$general_nodes" -gt 0 ]]; then
  ok "Found ${general_nodes} node(s) labeled workload=${general_workload_label}"
else
  error "No nodes labeled workload=${general_workload_label}"
fi

if [[ "$supabase_nodes" -gt 0 ]]; then
  ok "Found ${supabase_nodes} node(s) labeled workload=${supabase_workload_label}"
else
  error "No nodes labeled workload=${supabase_workload_label}"
fi

echo "[info] Node capacity snapshot"
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory,EPHEMERAL:.status.allocatable.ephemeral-storage

exit "$fail"
