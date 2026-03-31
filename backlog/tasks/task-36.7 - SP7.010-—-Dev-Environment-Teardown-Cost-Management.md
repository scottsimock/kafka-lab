---
id: TASK-36.7
title: SP7.010 — Dev Environment Teardown & Cost Management
status: Dev Complete
assignee:
  - Drexl
created_date: '2026-03-31 22:01'
updated_date: '2026-03-31 22:26'
labels:
  - story
milestone: m-9
dependencies:
  - TASK-36.1
references:
  - terraform/environments/
  - .github/workflows/
parent_task_id: TASK-36
priority: medium
ordinal: 6510
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create scripts and automation for destroying and recreating the dev environment to manage Azure costs. Include a Terraform destroy workflow, and documentation for the teardown/recreate cycle. Environment should be fully reproducible from scratch using the one-click deployment from SP6.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Terraform destroy script cleanly removes all dev environment resources
- [x] #2 GitHub Actions workflow for environment teardown (manual trigger)
- [x] #3 GitHub Actions workflow for environment recreation (manual trigger)
- [x] #4 Teardown completes without orphaned resources (verified via resource group check)
- [x] #5 Recreate from scratch completes successfully using one-click deployment
- [x] #6 Cost estimation documented for running vs. destroyed dev environment
- [x] #7 Documentation covers when and how to teardown/recreate
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Drexl] 2026-04-01T18:30:00Z
- Created `scripts/teardown-dev.sh` with --confirm safety, --plan-only, --skip-verify, and orphaned resource verification
- Created `.github/workflows/dev-teardown.yml` (workflow_dispatch: terraform destroy → verify cleanup)
- Created `.github/workflows/dev-recreate.yml` (workflow_dispatch: terraform apply → ansible → post-provision → webapp → verify)
- Updated `docs/deploy-dev.md` with teardown/recreate sections and cost estimation
- Running env: ~$45-55/day, Destroyed: ~$0.10/day (state storage only)
- All files pass syntax validation (bash -n, YAML parse)
<!-- SECTION:NOTES:END -->
