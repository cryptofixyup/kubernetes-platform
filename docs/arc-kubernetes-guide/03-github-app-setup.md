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

Use the included helper so the PEM stays outside Git while the namespace and secret are created idempotently:

```bash
./scripts/create-github-app.sh \
  --namespace arc-runners \
  --secret-name github-app-secret \
  --app-id 123456 \
  --installation-id 7890123 \
  --private-key-file ./github-app.pem
```

To preview the generated YAML without applying it:

```bash
./scripts/create-github-app.sh \
  --namespace arc-runners \
  --secret-name github-app-secret \
  --app-id 123456 \
  --installation-id 7890123 \
  --private-key-file ./github-app.pem \
  --dry-run
```

Reference the secret from each runner scale set:

```yaml
githubConfigSecret: github-app-secret
```

## Automate secret creation

The helper also supports environment variables for automation:

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
