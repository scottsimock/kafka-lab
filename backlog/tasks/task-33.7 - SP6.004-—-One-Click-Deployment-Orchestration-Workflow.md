---
id: TASK-33.7
title: SP6.004 — One-Click Deployment Orchestration Workflow
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
- [x] #1 Master workflow at .github/workflows/deploy-all.yml
- [x] #2 Triggered by workflow_dispatch with environment and component selection inputs
- [x] #3 Chains terraform -> ansible -> webapp jobs using needs dependencies
- [x] #4 Component selection: all, terraform-only, ansible-only, webapp-only
- [x] #5 Environment input: dev, staging, prod
- [x] #6 Each job references the corresponding reusable workflow
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Zorg] 2026-03-31T21:20:00Z
- Created `.github/workflows/deploy-all.yml` — master orchestration workflow
- Inputs: `environment` (dev/staging/prod), `component` (all/terraform-only/ansible-only/webapp-only), `terraform_action` (plan/apply), `dry_run` (boolean)
- Job chain: terraform → ansible → webapp with `needs` dependencies
- Conditional execution: each job gated by component selection; `always() && !failure()` on downstream jobs; webapp skipped on dry_run
- `plan_only` derived from `dry_run || terraform_action == 'plan'`
- `secrets: inherit` used for all reusable workflow calls
- Concurrency group `deploy-{env}` prevents parallel deploys to the same environment
- Commit: `fce1836` on `sprint/SP6-ci-cd-pipeline`

## [Sid — Tester] 2026-03-31T22:00:00Z
**Review: PASS — 96%**
- AC: 6/6 met
- Clean orchestration: terraform→ansible→webapp with correct `needs` chain
- `always() && !failure()` on downstream jobs correctly handles skipped upstream
- Component selection (all/terraform-only/ansible-only/webapp-only) works with conditional `if` expressions
- Concurrency group `deploy-{env}` prevents parallel deploys — good
- `dry_run` skips webapp and forces plan_only — well-designed
- `secrets: inherit` used consistently
<!-- SECTION:NOTES:END -->
