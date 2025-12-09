# Platform UX & Developer Experience Best Practices

Checklist-style guidance for building a productive, safe, and consistent developer experience on top of AKS.

---

## 1. Goals & Principles

- **Define clear platform goals and non-goals**  
  *Why*: Align expectations; clarify what the platform provides (golden paths, self-service) and what remains the teams' responsibility.

- **Optimize for developer flow, not just infrastructure control**  
  *Why*: A platform that is secure but painful to use will be bypassed; UX is a core feature, not a nice-to-have.

- **Treat platform UX as a product with users and a roadmap**  
  *Why*: Encourage iterative improvements based on feedback rather than ad-hoc tooling.

---

## 2. Golden Paths & Templates

- **Provide opinionated templates for common service types (API, worker, job)**  
  *Why*: Make it easy to start new services that already follow security, reliability, and observability best practices.

- **Include CI/CD, manifests, and baseline instrumentation in templates**  
  *Why*: Ensure new services are production-ready from day one, not just locally runnable.

- **Version and document templates and starter kits**  
  *Why*: Allow teams to know which template version they used and what improvements are available.

- **Encourage contributions to golden paths via a lightweight review process**  
  *Why*: Capture good patterns discovered by teams and share them across the organization.

---

## 3. Developer-Facing Tooling & CLIs

- **Offer a unified CLI or tooling entry point for common tasks**  
  *Why*: Reduce the cognitive load of many disjoint scripts and commands.

- **Automate repetitive operations (env creation, log viewing, kubectl context setup)**  
  *Why*: Let developers focus on code and behavior rather than plumbing.

- **Provide safe convenience commands (e.g. port-forward, tail logs, describe)**  
  *Why*: Make powerful operations easy while embedding guardrails for dangerous actions.

- **Document supported tools and versions (kubectl, Helm, language runtimes)**  
  *Why*: Avoid subtle issues due to tool version drift between developers and CI.

---

## 4. Self-Service Workflows

- **Implement self-service flows for creating services, namespaces, and pipelines**  
  *Why*: Reduce dependency on platform teams for routine tasks and speed up delivery.

- **Automate RBAC and policy attachments during onboarding of a new service**  
  *Why*: Ensure new workloads are created with correct permissions and guardrails by default.

- **Use GitOps for environment changes with clear review and approval**  
  *Why*: Provide a consistent, auditable mechanism for modifying cluster state.

- **Expose status and history of GitOps syncs in a UI (e.g. Argo CD)**  
  *Why*: Give developers visibility into what is running and why.

---

## 5. Local Development & Inner Loop

- **Provide documented workflows for local dev against AKS-backed services**  
  *Why*: Reduce friction when integrating with real dependencies like databases and APIs.

- **Use mocks, test doubles, or local emulators where real dependencies are impractical**  
  *Why*: Allow fast local iteration without requiring every external system.

- **Enable local runs of containers and manifests close to production configuration**  
  *Why*: Catch environment-specific issues earlier in the dev cycle.

- **Standardize environment variable and config handling across services**  
  *Why*: Simplify switching between local, dev, and prod configurations.

---

## 6. Documentation, Discoverability & Onboarding

- **Maintain a single, well-organized platform documentation hub**  
  *Why*: Avoid scattered docs; make it easy to find how-to guides, references, and policies.

- **Provide quick-start guides for new services and new developers**  
  *Why*: Shorten time-to-first-success on the platform.

- **Document golden paths as step-by-step flows, not just reference YAML**  
  *Why*: Help developers understand the why and how, not just copy-paste configs.

- **Keep examples and docs tested and versioned with the platform**  
  *Why*: Prevent drift between documentation and reality.

---

## 7. Feedback Loops & DX Metrics

- **Create easy channels for feedback (issues, surveys, office hours)**  
  *Why*: Understand friction points and prioritize improvements based on real user input.

- **Track developer experience metrics (time-to-first-deploy, lead time, MTTR)**  
  *Why*: Quantify the impact of platform changes and identify bottlenecks.

- **Use regular platform reviews with representative developers**  
  *Why*: Validate that the platform roadmap aligns with team needs and pain points.

---

## 8. Guardrails, Policies & Safety Nets

- **Encode guardrails as code (policies, templates) instead of manual reviews**  
  *Why*: Provide instant feedback to developers and reduce review overhead.

- **Offer clear error messages and remediation guidance when policies block changes**  
  *Why*: Turn policy failures into teachable moments rather than frustration.

- **Provide safe sandboxes or playground environments**  
  *Why*: Allow experimentation and learning without risking production systems.

- **Support easy rollbacks and feature flags**  
  *Why*: Give teams confidence to deploy frequently and recover quickly from issues.

---

## 9. Collaboration Between Platform & Product Teams

- **Establish clear ownership boundaries between platform and product teams**  
  *Why*: Avoid confusion over who maintains which parts of the stack and who responds to which incidents.

- **Include platform engineers in design reviews for new or critical services**  
  *Why*: Surface platform capabilities and constraints early in the design.

- **Encourage shared libraries and patterns owned by the platform team**  
  *Why*: Centralize expertise while enabling reuse across many services.

- **Recognize platform contributions as product-enabling work, not overhead**  
  *Why*: Incentivize investment in DX that yields compound benefits across teams.

---

## 10. Design Principles for a Good Developer Experience

- **Prefer convention over configuration**  
  *Why*: Reduce the number of decisions developers must make for common scenarios.

- **Make the right thing the easy thing**  
  *Why*: Embed best practices into defaults and tooling so that secure, reliable setups require less effort.

- **Fail fast with actionable errors**  
  *Why*: Help developers understand what went wrong and how to fix it quickly.

- **Continuously evolve the platform based on usage and feedback**  
  *Why*: Keep the platform aligned with changing technologies and team needs.
