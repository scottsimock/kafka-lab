---
id: TASK-33.8
title: SP6.007 — PR Validation Workflow
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
  - .github/workflows/pr-validation.yml
documentation:
  - doc-17
parent_task_id: TASK-33
priority: medium
ordinal: 6007
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a PR validation workflow that runs on pull requests to main. Validate Terraform formatting and configuration, run terraform plan with PR comment output, build the Next.js app, and syntax-check Ansible playbooks. Per doc-17.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 PR validation workflow at .github/workflows/pr-validation.yml
- [ ] #2 Triggered on pull_request to main
- [ ] #3 Runs terraform fmt -check and terraform validate
- [ ] #4 Runs terraform plan and posts plan output as PR comment
- [ ] #5 Runs Next.js build (npm run build)
- [ ] #6 Runs ansible-playbook --syntax-check
<!-- AC:END -->
