---
id: TASK-33.7
title: SP6.004 — One-Click Deployment Orchestration Workflow
status: To Do
assignee: []
created_date: '2026-03-30 16:47'
updated_date: '2026-03-30 16:48'
labels:
  - story
milestone: m-6
dependencies:
  - TASK-33.4
  - TASK-33.3
  - TASK-33.6
references:
  - .github/workflows/deploy-all.yml
documentation:
  - doc-17
parent_task_id: TASK-33
priority: high
ordinal: 6004
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the master one-click deployment workflow that chains Terraform, Ansible, and web app workflows. Trigger via workflow_dispatch with inputs for environment selection and component filtering. Chain jobs with needs dependencies: terraform -> ansible -> webapp. Per doc-17, this is the primary deployment mechanism.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Master workflow at .github/workflows/deploy-all.yml
- [ ] #2 Triggered by workflow_dispatch with environment and component selection inputs
- [ ] #3 Chains terraform -> ansible -> webapp jobs using needs dependencies
- [ ] #4 Component selection: all, terraform-only, ansible-only, webapp-only
- [ ] #5 Environment input: dev, staging, prod
- [ ] #6 Each job references the corresponding reusable workflow
<!-- AC:END -->
