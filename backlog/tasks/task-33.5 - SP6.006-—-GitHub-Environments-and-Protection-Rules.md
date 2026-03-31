---
id: TASK-33.5
title: SP6.006 — GitHub Environments and Protection Rules
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
  - .github/
documentation:
  - doc-17
parent_task_id: TASK-33
priority: medium
ordinal: 6006
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Configure GitHub Environments (dev, staging, prod) with appropriate protection rules. Prod requires reviewer approval and is restricted to main branch. Dev allows auto-deploy. Create documentation for UAMI federated credential setup matching each environment's subject scope. Per doc-17.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 GitHub Environments created: dev, staging, prod
- [x] #2 prod environment has required reviewer protection rule
- [x] #3 prod environment restricted to main branch
- [x] #4 dev environment has no protection rules (auto-deploy)
- [x] #5 Environment-scoped secrets configured: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
- [x] #6 Documentation for UAMI setup per workflow
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Zorg 2026-03-31T21:15:00Z
- Created `docs/ci-cd/github-environments.md` (374 lines)
- Covers all 6 AC items: environment overview table, step-by-step GitHub UI setup, UAMI creation/RBAC assignment, federated credential subjects per UAMI+environment, environment-scoped secrets (AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, KEYVAULT_NAME), and verification steps
- Commit: feat(SP6.006) on sprint/SP6-ci-cd-pipeline

## [Sid — Tester] 2026-03-31T22:00:00Z
**Review: PASS — 97%**
- AC: 6/6 met
- Comprehensive 374-line doc covering: environment overview table, step-by-step setup, UAMI creation/RBAC, federated credentials with subject claims, environment-scoped secrets, verification steps, troubleshooting table
- Design principles section articulates security rationale well
- Federated credential naming convention documented
- Verification steps include CLI commands and expected outputs
- Troubleshooting table covers common OIDC errors
<!-- SECTION:NOTES:END -->
