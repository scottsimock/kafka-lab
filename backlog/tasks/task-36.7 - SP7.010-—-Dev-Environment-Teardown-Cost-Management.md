---
id: TASK-36.7
title: SP7.010 — Dev Environment Teardown & Cost Management
status: To Do
assignee: []
created_date: '2026-03-31 22:01'
updated_date: '2026-03-31 22:01'
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
- [ ] #1 Terraform destroy script cleanly removes all dev environment resources
- [ ] #2 GitHub Actions workflow for environment teardown (manual trigger)
- [ ] #3 GitHub Actions workflow for environment recreation (manual trigger)
- [ ] #4 Teardown completes without orphaned resources (verified via resource group check)
- [ ] #5 Recreate from scratch completes successfully using one-click deployment
- [ ] #6 Cost estimation documented for running vs. destroyed dev environment
- [ ] #7 Documentation covers when and how to teardown/recreate
<!-- AC:END -->
