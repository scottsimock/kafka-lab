---
id: TASK-33.4
title: SP6.001 — Terraform Deployment Workflow
status: To Do
assignee: []
created_date: '2026-03-30 16:47'
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
- [ ] #1 Reusable workflow at .github/workflows/terraform-deploy.yml
- [ ] #2 Accepts inputs: environment, working_directory, plan_only (boolean)
- [ ] #3 Uses azure/login@v2 with OIDC (client-id, tenant-id, subscription-id from secrets)
- [ ] #4 Runs terraform init, validate, plan, and conditionally apply
- [ ] #5 Plan output saved as artifact
- [ ] #6 Job permissions: id-token: write, contents: read
- [ ] #7 terraform fmt -check runs in CI
<!-- AC:END -->
