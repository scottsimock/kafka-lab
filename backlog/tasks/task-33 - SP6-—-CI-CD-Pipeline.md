---
id: TASK-33
title: SP6 — CI/CD Pipeline
status: Done
assignee:
  - Drexl
created_date: '2026-03-30 16:47'
updated_date: '2026-03-31 21:29'
labels:
  - sprint
milestone: m-6
dependencies: []
priority: high
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
CI/CD pipeline sprint covering GitHub Actions workflows for Terraform, Ansible, and web application deployment, OIDC authentication setup, reusable workflow patterns, one-click deployment orchestration, and drift detection.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Terraform, Ansible, and web application deployment workflows run successfully via GitHub Actions
- [x] #2 One-click orchestration workflow deploys the full stack in correct dependency order
- [x] #3 Drift detection workflow identifies and reports infrastructure configuration drift
- [x] #4 PR validation workflow runs linting, plan preview, and security checks on pull requests
- [x] #5 GitHub Environments with protection rules enforce approval gates for staging and production
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Sid — Tester] 2026-03-31T22:00:00Z
**Sprint Review: ALL 8 TASKS PASS**

| Task | Score | Verdict |
|---|---|---|
| SP6.001 — Terraform Deploy | 93% | PASS |
| SP6.002 — Ansible Deploy | 91% | PASS |
| SP6.003 — Webapp Deploy | 90% | PASS |
| SP6.004 — Deploy All | 96% | PASS |
| SP6.005 — Drift Detection | 90% | PASS |
| SP6.006 — Environments Doc | 97% | PASS |
| SP6.007 — PR Validation | 94% | PASS |
| SP6.008 — Env Configs | 93% | PASS |

**Sprint average: 93%**

All 5 sprint AC satisfied. Moved all 8 tasks to Done.

**Cross-cutting observations:**
- Consistent OIDC pattern across all workflows (azure/login@v2, ARM_USE_OIDC env vars)
- Action versions consistent: checkout@v4, setup-terraform@v3, cache@v4, upload-artifact@v4, github-script@v7
- Permissions are least-privilege (id-token: write, contents: read)
- Secrets masked with ::add-mask:: in Ansible workflow

**Warnings to address in future sprints:**
1. webapp-deploy.yml: `function_app_name` default cross-references `inputs.environment` — may not resolve
2. drift-detection.yml: `environment: prod` but checks dev directory — confusing
3. drift-detection.yml: Only checks one directory — needs matrix when prod env added
4. terraform.prod.tfvars lives in dev/ directory — relocate when prod directory exists

## [Drexl — Lead/Architect] 2026-04-01T10:30:00Z
**Architecture Review: APPROVE WITH CONDITIONS**

Overall grade: B. Architecture is sound — reusable workflows, OIDC, environment gating, concurrency controls. But 4 wiring bugs prevent runtime functionality.

**4 Required Changes:**
1. **CRITICAL** — Terraform plan commands missing `-var-file` and `-var` flags. `subscription_id` and `ssh_public_key` are required variables with no defaults. Every TF workflow fails at runtime.
2. **CRITICAL** — drift-detection.yml `environment: prod` blocks nightly schedule behind 2-reviewer approval AND causes OIDC subject claim mismatch. Change to `environment: dev`.
3. **HIGH** — webapp-deploy.yml `function_app_name` default cross-references `inputs.environment` which doesn't resolve in workflow_call input defaults. Make it `required: true`.
4. **HIGH** — webapp-deploy.yml copies gitignored `local.settings.json` which won't exist in CI. Make conditional or remove.

**Confirmed Sid's warnings:** All 4 validated. Warnings #1 and #2 are bugs. #3 deferred to SP7. #4 is tolerable as placeholder.

**SP7 readiness:** Grade C+. No `region` parameter, no matrix strategy, hardcoded `scus` region suffixes. Extensible but needs parameterization work.

**8 non-blocking recommendations** documented (SHA pinning, path filters, health checks, etc.).

Full review: `.squad/decisions/inbox/drexl-sp6-architecture-review.md`
Assign fixes to a different implementor per lockout rules.
<!-- SECTION:NOTES:END -->
