---
id: TASK-33.2
title: SP6.005 — Drift Detection Workflow
status: To Do
assignee: []
created_date: '2026-03-30 16:47'
updated_date: '2026-03-30 16:48'
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
- [ ] #1 Scheduled workflow at .github/workflows/drift-detection.yml
- [ ] #2 Runs nightly on cron schedule
- [ ] #3 Executes terraform plan in each Terraform directory
- [ ] #4 Detects changes between state and actual infrastructure
- [ ] #5 Creates GitHub issue if drift detected
- [ ] #6 Does NOT apply any changes
<!-- AC:END -->
