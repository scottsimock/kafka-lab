---
id: TASK-36.6
title: SP7.009 — CI/CD Pipeline for Integration Tests
status: Dev Complete
assignee:
  - Drexl
created_date: '2026-03-31 22:01'
updated_date: '2026-03-31 22:32'
labels:
  - story
milestone: m-9
dependencies:
  - TASK-36.10
  - TASK-36.9
  - TASK-36.3
  - TASK-36.8
references:
  - .github/workflows/
parent_task_id: TASK-36
priority: medium
ordinal: 6509
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a GitHub Actions workflow that runs the Playwright integration tests against the dev environment. Workflow should trigger on push to relevant branches, run smoke tests first (fast fail), then full integration suite. Publish test results as artifacts. Configure appropriate secrets for Azure authentication.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 GitHub Actions workflow runs Playwright tests on push to sprint/SP7-* branches
- [ ] #2 Workflow runs smoke tests first with fast-fail on failure
- [ ] #3 Full integration test suite runs after smoke tests pass
- [ ] #4 Test results published as GitHub Actions artifacts (HTML report)
- [ ] #5 Azure authentication configured via OIDC federated credentials
- [ ] #6 Workflow uses Playwright GitHub Actions caching for fast startup
- [ ] #7 Pipeline completes within reasonable time (under 15 min for full suite)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Drexl] 2026-04-01T02:33:00Z
- Created `.github/workflows/integration-tests.yml`
- Two-job pipeline: smoke (fast-fail gate, 10m timeout) → integration (full suite, 15m timeout)
- Triggers: push to `sprint/SP7-*` branches + `workflow_dispatch`
- workflow_dispatch inputs: base_url override, test_suite selector (all/smoke/dashboard/operations/schema-registry/integration)
- Azure OIDC auth matching existing workflow patterns
- Playwright browser cache via `actions/cache` on `~/.cache/ms-playwright`
- HTML report artifact (14d retention), test-results artifact on failure (7d retention)
- Concurrency group prevents parallel runs on same branch
- YAML syntax validated; actionlint not available in env
- Commit: feat(SP7.009) on main
<!-- SECTION:NOTES:END -->
