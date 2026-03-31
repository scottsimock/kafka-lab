---
id: TASK-32
title: SP5 — Web Application
status: Done
assignee: []
created_date: '2026-03-30 16:45'
updated_date: '2026-03-31 19:56'
labels:
  - sprint
milestone: m-5
dependencies: []
priority: high
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Web application sprint covering Next.js 15 project scaffolding, Azure Function App infrastructure, shared Kafka client module, four dashboard views (Cluster Overview, Topic Detail, Consumer Groups, Message Browser), and API route handlers.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Next.js 15 application is scaffolded with App Router and shared Kafka client module
- [ ] #2 API route handlers support topic listing, message produce/consume, and schema browsing
- [ ] #3 Four dashboard views are implemented: Cluster Overview, Topic Detail, Consumer Groups, and Message Browser
- [ ] #4 Azure Function App infrastructure is provisioned with private networking and UAMI authentication
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Squad 2026-03-31T14:57:00-04:00
- SP5 sprint started
- Branch: sprint/SP5-web-application
- Wave 1: SP5.001 (Dallas — scaffolding) + SP5.009 (Parker — Function App infra) in parallel

## [Squad] 2026-03-31T15:56ET
- All 10 tasks Done. Build verified (21 routes).
- Ripley review: APPROVE WITH CONDITIONS → 3 critical fixes applied by Parker.
- Branch: sprint/SP5-web-application (14 commits ahead of main).
- Sprint complete.
<!-- SECTION:NOTES:END -->
