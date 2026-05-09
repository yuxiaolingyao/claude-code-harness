---
name: infra-guard
description: Infrastructure-as-code safety review. Checks Terraform, Kubernetes, Helm, and Docker configs for destructive changes.
model: auto
context: fork
allowed-tools: Read, Grep, Glob
---

# Infrastructure Safety Review

Review infrastructure configuration for destructive or risky changes. Covers Terraform, Kubernetes, Helm, Docker, Ansible, and CI pipeline configs.

## Review Checklist

### Terraform
- `terraform destroy` — is there a targeted `-target` flag or is this a full teardown?
- Resources being **replaced** (not updated in-place) — will this cause downtime?
- `prevent_destroy` lifecycle — is it set on stateful resources (RDS, S3)?
- State file — is it stored remotely with locking? (not local `.tfstate`)
- Sensitive outputs — are secrets/keys exposed in `outputs.tf`?

### Kubernetes
- `kubectl delete namespace` / `kubectl delete --all` — total cluster wipe?
- `helm uninstall` without backup — stateful sets will lose data
- `resources.limits` removed or too low — OOM kills in production?
- `allowPrivilegeEscalation: true` or `privileged: true` — security risk
- Ingress changes that expose internal services publicly

### Docker / Containers
- `docker rm -f $(docker ps -aq)` — wipe all containers
- `docker system prune -af` — deletes all unused images/volumes/networks
- `--privileged` or `--cap-add=ALL` — container escape risk
- Host network mode (`--net=host`) — bypasses network isolation

### CI / CD
- Pipeline changes that deploy to production without approval gates
- Secrets in pipeline YAML (should reference secret manager, not hardcoded)
- `force_push: true` on deployment steps

### General
- Is the change targeting the correct environment/cluster/context?
- Are there rollback instructions?
- Was this change tested in staging first?

## Output Format

| Severity | Category | File:Line | Issue | Fix |
|----------|----------|-----------|-------|-----|
| 🔴 Critical | Kubernetes | ... | delete namespace without confirmation | ... |
| 🟡 Warning | Terraform | ... | RDS instance will be replaced | ... |

End with risk summary: SAFE / NEEDS_REVIEW / DANGEROUS.
