# Contributing to The Trench

This document defines how changes are made to this repository. It applies to application code, infrastructure, Kubernetes manifests, and CI configuration.

The default assumption is a single primary maintainer plus occasional collaborators. The rules still hold if the team grows.

---

## 1. Workflow Overview

1. Work on a branch, never directly on `main`.
2. Make small, coherent changes with clear commit messages.
3. Run local checks (tests, linters, Terraform validate/plan where relevant).
4. Open a Pull Request (PR) to `main`.
5. Use the PR description to explain what changed and why.
6. After review, squash or rebase, then merge.
7. Let CI and ArgoCD deploy from `main`.

`main` represents the current state of the active environment (initially `dev`).

---

## 2. Branching Model

### Branch Types

- Feature branches: `feat/<short-description>`
- Fix branches: `fix/<short-description>`
- Infra branches: `infra/<short-description>`
- Experiment branches: `exp/<short-description>` (must be short lived)

Examples:
- `feature/add-events-api`
- `fix/ui-auth-redirect`
- `infra/add-postgres-module`

### Rules

- One logical change per branch. Do not mix unrelated infra and app changes in one branch.
- Delete branches after they are merged.
- Experiments that turn into real work should be rebased or cleaned up on a new branch.

---

## 3. Commit Message Conventions

Commit messages must be clear, specific, and written in the imperative.

Format:
`<short summary in imperative>`

Good examples:
- `Add basic events API endpoints`
- `Wire Service Bus client into worker`
- `Refactor Terraform networking module`
- `Fix NGINX ingress for UI service`

Bad examples:
- `changes`
- `WIP`
- `stuff`

Guidelines:
- Keep the subject line under 72 characters.
- Use the body (optional) to explain why, not what, if the change is non-trivial.
- Do not hide multiple unrelated changes behind a single commit.

---

## 4. Pull Requests

Each PR should:

- Target `main` only.
- Be focused on one thing: a feature, a fix, or a discrete infra change.
- Include a concise description:
  - What changed.
  - Why it changed.
  - Any risks or rollback notes.

Example PR checklist:
- [ ] Tests passing locally.
- [ ] Terraform validated and plan reviewed (if infra changed).
- [ ] Kubernetes manifests linted / rendered (if k8s changed).

Avoid huge PRs. If it feels too large, split it into smaller, sequential PRs.

---

## 5. Infrastructure Changes (Terraform)

Location:
- `infra/terraform` for core Azure resources.
- `infra/cluster-addons` for Helm and add-ons that may be bootstrapped.

Rules:
- All Terraform code must pass:
  - `terraform fmt`
  - `terraform validate`
- Run `terraform plan` and examine the diff before applying.
- Do not commit local state files. Only use `.tfstate` in a proper backend when that phase is reached.
- Every new module must:
  - Use the shared naming and tagging conventions.
  - Have variables for environment specific values.
  - Avoid hard-coding secrets.

---

## 6. Kubernetes and GitOps Changes

Location:
- `k8s/apps` for workloads.
- `k8s/infra` for add-ons managed via ArgoCD.

Rules:
- No direct kubectl `apply` against the cluster for long lived resources. Changes must go through Git (GitOps).
- Every Deployment must define:
  - Resource requests and limits.
  - Liveness and readiness probes.
- Sensitive values must never be stored in plain Kubernetes Secrets. Use Key Vault CSI and Workload Identity.
- Keep environment specific details in overlays or values files, not in shared base manifests.

When adding a new add-on or workload, document:
- Namespace used.
- How it is wired into observability, ingress, and identity.

---

## 7. Application Code Changes

Location:
- `apps/service-*` for backend services.
- `apps/ui` for the Next.js frontend.

Guidelines:
- Keep service boundaries clean. Do not let one service reach directly into another service’s database.
- All external calls (HTTP, messaging, database) must respect timeouts and error handling.
- Logging must be structured and suitable for consumption by OTEL and centralized log sinks.
- Add or update tests in `tests` when behavior changes, not after the fact.

If an application change affects public API contracts, note it in the PR and update any relevant documentation under `ops/docs`.

---

## 8. CI and Pipelines

Location:
- `ci/github` (eventually `.github/workflows` in the repo root)

Guidelines:
- Keep workflows minimal and composable. Separate build, test, and security scanning where it makes sense.
- Pipelines must be idempotent. No manual toggles or ad-hoc steps.
- When adding or modifying a workflow, explain in the PR:
  - Trigger conditions.
  - What gates are enforced before merge.

CI failures block merges. Do not bypass them.

---

## 9. Style and Quality

- Follow the language specific linters and formatters (for example `eslint` for TypeScript, `black` for Python if used).
- Do not leave commented out code in the main branches.
- Avoid premature abstraction. Prefer clear, simple code with good names.
- Error handling and logging matter more than clever implementation details.

---

## 10. Security and Secrets

- Never commit secrets, keys, connection strings, or tokens.
- For local development, use `.env` files that are ignored by Git.
- In the cluster, all secrets must come from Key Vault via CSI or direct SDK usage with Workload Identity.

If there is any doubt about security impact, treat the change as security sensitive and document the reasoning in the PR

