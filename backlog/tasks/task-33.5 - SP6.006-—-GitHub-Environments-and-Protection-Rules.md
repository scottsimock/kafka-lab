---
id: TASK-33.5
title: SP6.006 — GitHub Environments and Protection Rules
status: To Do
assignee: []
created_date: '2026-03-30 16:47'
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
- [ ] #1 GitHub Environments created: dev, staging, prod
- [ ] #2 prod environment has required reviewer protection rule
- [ ] #3 prod environment restricted to main branch
- [ ] #4 dev environment has no protection rules (auto-deploy)
- [ ] #5 Environment-scoped secrets configured: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
- [ ] #6 Documentation for UAMI setup per workflow
<!-- AC:END -->
