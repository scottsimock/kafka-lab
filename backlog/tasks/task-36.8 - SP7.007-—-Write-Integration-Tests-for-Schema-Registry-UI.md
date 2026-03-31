---
id: TASK-36.8
title: SP7.007 — Write Integration Tests for Schema Registry UI
status: To Do
assignee: []
created_date: '2026-03-31 22:01'
updated_date: '2026-03-31 22:01'
labels:
  - story
milestone: m-9
dependencies:
  - TASK-36.1
  - TASK-36.10
references:
  - webapp/app/
  - webapp/tests/
parent_task_id: TASK-36
priority: medium
ordinal: 6507
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Write Playwright integration tests for the Schema Registry UI features: schema listing displays registered schemas, schema detail shows versions and compatibility settings, compatibility check UI works correctly. Tests exercise the web app to Function App to Schema Registry path.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Test: schema subjects listing page shows registered schemas
- [ ] #2 Test: schema detail page displays schema versions and content
- [ ] #3 Test: compatibility level shown correctly for each subject
- [ ] #4 Test: compatibility check UI validates schema against existing versions
- [ ] #5 Test: register new schema version via UI and verify it appears
- [ ] #6 Tests organized in webapp/tests/e2e/schema-registry/
<!-- AC:END -->
