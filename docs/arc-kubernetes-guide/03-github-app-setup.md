# 03. GitHub App setup

## Create the GitHub App

Register an organization-owned GitHub App with these settings:

- **Homepage URL:** `https://github.com/actions/actions-runner-controller`
- **Webhook:** not required for ARC scale sets.
- **Repository permissions:**
  - `Administration: Read and write` for repository-scoped runners.
  - `Metadata: Read-only`.
- **Organization permissions:**
  - `Self-hosted runners: Read and write`.

Install the app on the target organization or repository and record:

- App ID
- Installation ID
- Private key PEM file

## Create the Kubernetes secret

```bash
kubectl create namespace arc-runners --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic github-app-secret \
  --namespace arc-runners \
  --from-literal=github_app_id='123456' \
  --from-literal=github_app_installation_id='7890123' \
  --from-file=github_app_private_key=./github-app.pem
```

Reference the secret from each runner scale set:

```yaml
githubConfigSecret: github-app-secret
```

## Automate secret creation

The included helper reads environment variables and creates or updates the secret:

```bash
export GITHUB_APP_ID=123456
export GITHUB_APP_INSTALLATION_ID=7890123
export GITHUB_APP_PRIVATE_KEY_FILE=./github-app.pem
./scripts/create-github-app.sh
```

## Rotation strategy

- Generate a second private key in GitHub before deleting the old one.
- Update the Kubernetes secret with `kubectl apply -f -` or rerun `create-github-app.sh`.
- Restart listeners to force fast pickup if needed:

```bash
kubectl rollout restart deployment -n arc-runners -l app.kubernetes.io/component=runner-scale-set-listener
```

- Review GitHub App installation scope quarterly.
- Prefer external secret managers if your cluster already standardizes on them.

## Security notes

- Store the PEM outside Git, ideally in a vault or sealed-secret workflow.
- Restrict secret read access to the runner namespace.
- Use org runner groups to limit which repos can target each scale set.
