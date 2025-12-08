# CI Hardening Roadmap (demo-api)

This document describes how to evolve the `demo-api` GitHub Actions pipeline from a basic build into a hardened, production-style CI flow. The same patterns can later be applied to other services.

Current baseline (`demo-api CI`):

- Build and push image to `trenchacrcoredev.azurecr.io`.
- Lint with flake8 (2-space indentation, `.venv` excluded).
- Scan image with Trivy for HIGH/CRITICAL vulnerabilities.

---

## Phase 1: Code Quality Baseline

Goal: Ensure code is in good shape before adding heavier security gates.

**Actions:**

- Lint and formatting:
  - Keep flake8 with project-specific config (`.flake8`).
  - (Optional later) Introduce `black` or `ruff` for auto-formatting / faster linting.
- Testing:
  - Add a `tests/` package for `demo-api` with pytest.
  - CI: run `pytest` and fail on test failures.
  - (Optional) Generate coverage (e.g. `pytest --cov=apps/demo-api`).
- Typing:
  - (Optional later) Add `mypy` or `pyright` for static type checking.

Checkpoint:

- A PR that breaks tests or linting fails fast.

---

## Phase 2: Security Scanning in Depth

Goal: Catch obvious security issues before images are pushed or deployed.

**Actions:**

- Secret scanning:
  - Add a job/step to scan the repo for secrets.
  - Options:
    - Trivy in `secret` mode (`trivy fs --scanners secret .`).
    - Or Gitleaks GitHub Action.
- Dependency / SCA scanning:
  - Continue to use Trivy image scanning for OS + Python deps.
  - (Optional) Add `pip-audit` or Trivy filesystem scan to fail earlier on vulnerable dependencies.
- Config / K8s manifest scanning:
  - Scan `k8s/base/apps/demo-api/**` for misconfigurations:
    - Use Trivy config scan, Checkov, kube-linter, or similar.

Checkpoint:

- Every PR runs: lint, (tests), secret scan, dependency/image scan, and config scan.

---

## Phase 3: SBOM + Image Signing

Goal: Improve supply-chain transparency and integrity.

### SBOM (Software Bill of Materials)

**Actions:**

- Use Trivy to generate an SBOM for the built `demo-api` image.
- Choose a format (CycloneDX or SPDX).
- Upload the SBOM as a GitHub artifact.
- (Optional) Push SBOM as an OCI artifact to ACR alongside the image.

### Image signing

**Actions:**

- Introduce Sigstore Cosign for keyless signing via GitHub OIDC.
- After build + push, sign the image digest with Cosign.
- Store signatures in ACR as OCI artifacts.
- (Later phase) Enforce signed images in AKS with admission policies (e.g. Kyverno / Gatekeeper).

Checkpoint:

- Every promoted image has a corresponding SBOM and signature.

---

## Phase 4: Code Analysis (SAST)

Goal: Detect deeper code-level issues and security smells.

**Actions:**

- Integrate SonarCloud or SonarQube for `demo-api`:
  - Analyze Python code for bugs, vulnerabilities, and code smells.
  - Feed coverage data from pytest for more accurate analysis.
- Configure a quality gate:
  - Fail CI if new critical issues are introduced.
  - Optionally require the gate to pass before merging to main branches.

Checkpoint:

- Code changes that introduce serious issues are blocked before merge.

---

## Phase 5: Advanced Enhancements (Optional)

Goal: Approach a production-grade CI posture for the lab.

**Examples:**

- License compliance:
  - Use SBOM + tooling (e.g. Trivy, Syft/Grype) to track licenses across dependencies.
- DAST (runtime scanning):
  - Once the app is reachable via ingress, run a lightweight DAST scan (e.g. OWASP ZAP) against dev.
- Policy-as-code for infra:
  - Run policy checks on Terraform (`infra/terraform`) using tools like Checkov or OPA/Conftest.
- Branch protections and required checks:
  - Make `demo-api CI` (and later Sonar/other checks) required for `rel/dev` and `main` merges.

---

## Usage in the Lab

- Start from the current baseline (Phase 5.1 in PLAN).
- Incrementally add phases above:
  - First: secret scanning and manifest scanning.
  - Then: SBOM + image signing.
  - Then: Sonar / SAST.
- Use `demo-api` as the template; later replicate the hardened CI pattern for `catalog-api`, `orders-api`, etc.
