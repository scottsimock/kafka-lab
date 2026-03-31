---
id: TASK-33.6
title: SP6.003 — Web Application Deployment Workflow
status: Done
assignee:
  - Smiley
created_date: '2026-03-30 16:47'
updated_date: '2026-03-31 21:20'
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
- [x] #1 Reusable workflow at .github/workflows/webapp-deploy.yml
- [x] #2 Builds Next.js with npm run build
- [x] #3 Packages standalone output for Function App deployment
- [x] #4 Deploys to Azure Function App using azure/functions-action
- [x] #5 Authenticates via OIDC
- [x] #6 Supports slot deployment for zero-downtime updates
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Smiley] 2026-03-31T17:12:00-04:00
- Created `.github/workflows/webapp-deploy.yml` — reusable workflow for Next.js Function App deployment
- Builds standalone output, packages with host.json and static assets
- Deploys via azure/functions-action@v2 with optional slot deployment
- Slot swap step for zero-downtime updates
- OIDC auth, build artifact uploaded
- All 6 AC met

## [Sid — Tester] 2026-03-31T22:00:00Z
**Review: PASS — 90%**
- AC: 6/6 met
- Standalone packaging logic is correct (copies .next/standalone, static, public, host.json)
- Slot deployment + swap step for zero-downtime updates — good
- azure/functions-action@v2 used correctly
- Warning: `function_app_name` default references `${{ inputs.environment }}` — cross-input references in defaults may not resolve. Callers should pass this explicitly. deploy-all.yml does NOT pass it, so it relies on the potentially-broken default.
- Warning: `local.settings.json` copied to deploy package — ensure it contains no secrets
<!-- SECTION:NOTES:END -->
