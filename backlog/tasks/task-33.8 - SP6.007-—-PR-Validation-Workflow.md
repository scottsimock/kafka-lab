---
id: TASK-33.8
title: SP6.007 — PR Validation Workflow
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
- [x] #1 PR validation workflow at .github/workflows/pr-validation.yml
- [x] #2 Triggered on pull_request to main
- [x] #3 Runs terraform fmt -check and terraform validate
- [x] #4 Runs terraform plan and posts plan output as PR comment
- [x] #5 Runs Next.js build (npm run build)
- [x] #6 Runs ansible-playbook --syntax-check
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## @Zorg 2026-03-31T21:30:00Z
- Created `.github/workflows/pr-validation.yml` with 3 parallel jobs
- **terraform-validate**: fmt -check, validate, plan with OIDC login + PR comment via github-script
- **webapp-build**: Node 20, npm ci, build, lint
- **ansible-check**: syntax-check site.yml + all playbooks in ansible/playbooks/
- Patterns aligned with existing terraform-deploy, webapp-deploy, and ansible-deploy workflows
- Commit: a319558

## [Sid — Tester] 2026-03-31T22:00:00Z
**Review: PASS — 94%**
- AC: 6/6 met
- Three parallel jobs: terraform-validate, webapp-build, ansible-check — fast feedback
- PR comment with plan output via github-script, truncated at 60k chars
- Extra `npm run lint` step in webapp job — good addition beyond AC
- Ansible syntax-check covers site.yml + all playbooks in ansible/playbooks/ via loop
- Info: OIDC env vars set at workflow level but only terraform job needs them — minor inefficiency, not a bug
<!-- SECTION:NOTES:END -->
