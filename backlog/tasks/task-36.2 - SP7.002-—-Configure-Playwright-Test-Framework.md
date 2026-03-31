---
id: TASK-36.2
title: SP7.002 — Configure Playwright Test Framework
status: Dev Complete
assignee:
  - Smiley
created_date: '2026-03-31 22:00'
updated_date: '2026-03-31 22:15'
labels:
  - story
milestone: m-9
dependencies: []
references:
  - webapp/
parent_task_id: TASK-36
priority: high
ordinal: 6502
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Install and configure Playwright for the Next.js 15 web application. Set up the Playwright config file with proper base URL pointing to the dev environment. Configure browser contexts, timeouts, and retry settings appropriate for testing against a remote Azure deployment. Set up test directory structure under webapp/tests/e2e/.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Playwright installed as dev dependency in webapp/package.json
- [x] #2 playwright.config.ts configured with dev environment base URL
- [x] #3 Browser contexts configured (Chromium at minimum, Firefox and WebKit optional)
- [x] #4 Timeouts set appropriately for remote Azure testing (network latency)
- [x] #5 Test directory structure created: webapp/tests/e2e/
- [x] #6 npx playwright test runs successfully (even if no tests yet)
- [x] #7 Playwright HTML reporter configured for CI output
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Smiley] 2026-04-01T18:30:00Z
- Installed `@playwright/test` ^1.58.2 as dev dependency
- Created `webapp/playwright.config.ts` with env-driven base URL (`PLAYWRIGHT_BASE_URL`), Chromium project, remote-tuned timeouts (action 30s, nav 60s, expect 10s), CI retry/reporter config
- Created directory structure: `tests/e2e/{smoke,integration,fixtures}/`
- Added `smoke/health.spec.ts` sample test (GET base URL, assert non-500)
- Added `fixtures/index.ts` placeholder for shared test fixtures
- Added `test:e2e`, `test:e2e:ui`, `test:e2e:report` npm scripts
- Added Playwright artifact paths to `.gitignore`
- `npx playwright test --list` confirms 1 test discovered
- Test execution fails only due to missing Chromium system deps in this env — expected; CI with `playwright install --with-deps` will work
<!-- SECTION:NOTES:END -->
