---
id: TASK-36.10
title: SP7.004 — Write Smoke Tests for Web Application
status: To Do
assignee: []
created_date: '2026-03-31 22:01'
updated_date: '2026-03-31 22:01'
labels:
  - story
milestone: m-9
dependencies:
  - TASK-36.2
references:
  - webapp/tests/
parent_task_id: TASK-36
priority: high
ordinal: 6504
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Write Playwright smoke tests covering basic web application functionality: all page loads return 200, navigation between pages works, API health endpoint responds, error pages render correctly. These are fast, shallow tests that confirm the app is alive and serving correctly.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Smoke test: home/dashboard page loads with 200 status
- [ ] #2 Smoke test: all navigation links resolve to valid pages
- [ ] #3 Smoke test: API health endpoint returns healthy status
- [ ] #4 Smoke test: topics listing page loads and renders
- [ ] #5 Smoke test: consumer groups page loads and renders
- [ ] #6 Smoke test: schema registry page loads and renders
- [ ] #7 All smoke tests pass against live dev environment
- [ ] #8 Tests organized in webapp/tests/e2e/smoke/
<!-- AC:END -->
