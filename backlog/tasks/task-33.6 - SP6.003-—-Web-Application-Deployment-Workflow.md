---
id: TASK-33.6
title: SP6.003 — Web Application Deployment Workflow
status: To Do
assignee: []
created_date: '2026-03-30 16:47'
labels:
  - story
milestone: m-6
dependencies: []
references:
  - .github/workflows/webapp-deploy.yml
documentation:
  - doc-17
  - doc-16
parent_task_id: TASK-33
priority: high
ordinal: 6003
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable GitHub Actions workflow for Next.js web application deployment to Azure Function Apps. Build the Next.js app, package the standalone output, and deploy using azure/functions-action. Support deployment slots for zero-downtime updates. Per doc-17 and doc-16.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Reusable workflow at .github/workflows/webapp-deploy.yml
- [ ] #2 Builds Next.js with npm run build
- [ ] #3 Packages standalone output for Function App deployment
- [ ] #4 Deploys to Azure Function App using azure/functions-action
- [ ] #5 Authenticates via OIDC
- [ ] #6 Supports slot deployment for zero-downtime updates
<!-- AC:END -->
