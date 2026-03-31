---
id: TASK-33.4
title: SP6.001 — Terraform Deployment Workflow
status: Done
assignee:
  - Zorg
created_date: '2026-03-30 16:47'
updated_date: '2026-03-31 21:20'
labels:
  - story
milestone: m-6
dependencies: []
references:
  - .github/workflows/terraform-deploy.yml
documentation:
  - doc-17
parent_task_id: TASK-33
priority: high
ordinal: 6001
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable GitHub Actions workflow for Terraform deployment. The workflow accepts environment and working directory as inputs, authenticates via OIDC with UAMI, runs init/validate/plan/apply steps. Plan output is saved as artifact. Apply requires approval gate via GitHub Environment protection rules. Per doc-17.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Reusable workflow at .github/workflows/terraform-deploy.yml
- [x] #2 Accepts inputs: environment, working_directory, plan_only (boolean)
- [x] #3 Uses azure/login@v2 with OIDC (client-id, tenant-id, subscription-id from secrets)
- [x] #4 Runs terraform init, validate, plan, and conditionally apply
- [x] #5 Plan output saved as artifact
- [x] #6 Job permissions: id-token: write, contents: read
- [x] #7 terraform fmt -check runs in CI
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Zorg] 2025-07-15T21:00:00Z
- Created `.github/workflows/terraform-deploy.yml` — reusable `workflow_call` workflow
- Two jobs: **plan** (checkout → setup-terraform → cache → login → init → fmt-check → validate → plan → upload artifacts) and **apply** (conditional on `plan_only == false`, downloads plan artifact, applies)
- OIDC auth via `azure/login@v2` with `ARM_USE_OIDC=true` env vars for AzAPI/AzureRM providers
- Inputs: `environment` (required), `working_directory` (default `terraform/environments/dev`), `plan_only` (default false)
- Plan artifacts (`tfplan` + `plan-output.txt`) uploaded with 7-day retention
- `terraform fmt -check -recursive` runs before validate
- Apply job uses GitHub `environment:` key for protection rules
- Commit: `26ca271`

## [Zorg] 2026-03-31T17:12:00-04:00
- Created `.github/workflows/terraform-deploy.yml` — reusable workflow_call with two jobs (plan + apply)
- OIDC auth via azure/login@v2 with ARM_USE_OIDC env vars
- Plan artifacts uploaded (tfplan + plan-output.txt)
- Apply job gated by plan_only input and GitHub Environment protection rules
- terraform fmt -check runs before validate
- All 7 AC met

## [Sid — Tester] 2026-03-31T22:00:00Z
**Review: PASS — 93%**
- AC: 7/7 met
- Clean two-job structure (plan + apply), proper OIDC env vars, provider caching, plan artifacts with 7-day retention
- Apply job correctly gated by `plan_only` input and `environment:` key for protection rules
- `terraform fmt -check -recursive` runs before validate — good
- Consistent action versions (checkout@v4, setup-terraform@v3, cache@v4, login@v2)
- Good header comment with usage example
<!-- SECTION:NOTES:END -->
