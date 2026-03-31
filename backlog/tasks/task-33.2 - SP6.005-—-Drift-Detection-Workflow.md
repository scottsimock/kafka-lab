---
id: TASK-33.2
title: SP6.005 — Drift Detection Workflow
status: Done
assignee:
  - Zorg
created_date: '2026-03-30 16:47'
updated_date: '2026-03-31 21:20'
labels:
  - story
milestone: m-6
dependencies:
  - TASK-33.4
references:
  - .github/workflows/drift-detection.yml
documentation:
  - doc-17
parent_task_id: TASK-33
priority: medium
ordinal: 6005
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a scheduled GitHub Actions workflow for Terraform drift detection. Run nightly, execute terraform plan without apply, and report drift as a GitHub issue. Authenticate via OIDC on main branch. Per doc-17, drift detection ensures infrastructure matches desired state.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Scheduled workflow at .github/workflows/drift-detection.yml
- [x] #2 Runs nightly on cron schedule
- [x] #3 Executes terraform plan in each Terraform directory
- [x] #4 Detects changes between state and actual infrastructure
- [x] #5 Creates GitHub issue if drift detected
- [x] #6 Does NOT apply any changes
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Zorg 2026-03-31T21:30:00Z
- Created `.github/workflows/drift-detection.yml`
- Schedule: `cron: '0 3 * * *'` + `workflow_dispatch`
- OIDC auth pattern matches `terraform-deploy.yml` (env-level vars, `azure/login@v2`)
- `terraform plan -detailed-exitcode` captures exit code via `PIPESTATUS[0]`
- Exit code 2 → creates GitHub issue with truncated plan output (≤10k chars), labels `drift` + `infrastructure`
- Exit code 1 → fails the workflow explicitly
- No `terraform apply` anywhere in the file
- Commit: `a415d17` on `sprint/SP6-ci-cd-pipeline`

## [Sid — Tester] 2026-03-31T22:00:00Z
**Review: PASS — 90%**
- AC: 6/6 met (currently one terraform directory, one check — scales later)
- `-detailed-exitcode` correctly captures exit code 2 (drift) vs 1 (error)
- GitHub issue creation with truncated plan output (≤10k chars), labels `drift` + `infrastructure`
- No `terraform apply` anywhere — confirmed observe-only
- Warning: Job uses `environment: prod` but checks `terraform/environments/dev`. This works (prod credentials can read dev state) but is confusing. Consider adding a matrix strategy for multi-env drift detection in future.
- Warning: Only checks dev directory — when prod environment directory is added, this workflow needs a second job or matrix.
<!-- SECTION:NOTES:END -->
