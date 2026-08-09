#!/usr/bin/env bash
set -euo pipefail

fail=0
required_tools=(kubectl helm openssl awk sed grep)

for tool in "${required_tools[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "[ok] $tool found"
  else
    echo "[error] $tool not found"
    fail=1
  fi
done

context=$(kubectl config current-context 2>/dev/null || true)
if [[ -z "$context" ]]; then
  echo "[error] kubectl has no current context"
  exit 1
fi
echo "[ok] Connected to cluster context: $context"

nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
echo "[ok] Nodes discovered: $nodes"

default_sc=$(kubectl get storageclass 2>/dev/null | awk '/\(default\)/ {print $1; exit}')
if [[ -n "$default_sc" ]]; then
  echo "[ok] Default storage class: $default_sc"
else
  echo "[warn] No default storage class detected"
fi

if kubectl auth can-i create namespace >/dev/null 2>&1; then
  echo "[ok] Namespace creation permissions confirmed"
else
  echo "[warn] Current identity cannot create namespaces"
fi

echo "[info] Node capacity snapshot"
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory,EPHEMERAL:.status.allocatable.ephemeral-storage

exit "$fail"
