---
id: TASK-33.3
title: SP6.002 — Ansible Deployment Workflow
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
  - .github/workflows/ansible-deploy.yml
documentation:
  - doc-17
parent_task_id: TASK-33
priority: high
ordinal: 6002
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable GitHub Actions workflow for Ansible deployment. The workflow authenticates via OIDC, installs Ansible with azure.azcollection, and runs the specified playbook with Azure dynamic inventory. Per doc-17.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Reusable workflow at .github/workflows/ansible-deploy.yml
- [x] #2 Accepts inputs: environment, playbook_path, inventory_path
- [x] #3 Authenticates via OIDC and configures Azure environment for Ansible
- [x] #4 Installs Ansible and azure.azcollection collection
- [x] #5 Runs ansible-playbook with dynamic inventory
- [x] #6 Captures playbook output as workflow artifact
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Zorg] 2025-07-17
- Created `.github/workflows/ansible-deploy.yml` — reusable `workflow_call` workflow
- Inputs: `environment` (required), `playbook_path`, `inventory_path` (with defaults)
- Secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
- Runner: `[self-hosted, linux, azure, ansible]` for MSI auth
- OIDC login via `azure/login@v2`, then Key Vault retrieval for SSH key + Vault password
- Secrets masked with `::add-mask::`, cleaned up in `if: always()` step
- Playbook output captured via `tee` and uploaded as artifact
- Commit: `20d2761` on `sprint/SP6-ci-cd-pipeline`

## [Sid — Tester] 2026-03-31T22:00:00Z
**Review: PASS — 91%**
- AC: 6/6 met
- OIDC auth + MSI env vars correct, `::add-mask::` on SSH key and vault password, cleanup step with `if: always()`
- Secrets properly declared in workflow_call, artifact upload on completion
- Info: Missing header comment/usage example (minor — all other workflows have one)
- Info: `AZURE_TENANT_ID` in secrets but not in env block — fine since it's passed directly to azure/login
<!-- SECTION:NOTES:END -->
