# Security checklist and best practices

## Minimum baseline

- [ ] Use a GitHub App instead of a long-lived PAT.
- [ ] Store the private key outside Git and rotate it regularly.
- [ ] Restrict runner groups to trusted private repositories.
- [ ] Do not run untrusted fork pull requests on organization-wide ARC runners.
- [ ] Separate `arc-systems` and `arc-runners` namespaces.
- [ ] Limit secret read access in `arc-runners`.
- [ ] Apply network policies for runner egress.
- [ ] Pin runner images to approved tags or digests before production rollout.
- [ ] Enable audit logging for Kubernetes and GitHub organization settings.

## DinD-specific concerns

- DinD requires privileged execution; isolate those pods onto dedicated nodes where possible.
- Monitor for disk exhaustion caused by image pulls and container layer growth.
- Prefer ephemeral runners so Docker state is destroyed after every job.

## Secret handling

- Use `kubectl create secret --dry-run=client -o yaml | kubectl apply -f -` for idempotent updates.
- Back the secret with an external manager if your platform standard already exists.
- Never embed PEM content directly in Helm values committed to Git.
