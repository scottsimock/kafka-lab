---
id: TASK-36.2
title: SP7.002 — Configure Playwright Test Framework
status: To Do
assignee: []
created_date: '2026-03-31 22:00'
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
- [ ] #1 Playwright installed as dev dependency in webapp/package.json
- [ ] #2 playwright.config.ts configured with dev environment base URL
- [ ] #3 Browser contexts configured (Chromium at minimum, Firefox and WebKit optional)
- [ ] #4 Timeouts set appropriately for remote Azure testing (network latency)
- [ ] #5 Test directory structure created: webapp/tests/e2e/
- [ ] #6 npx playwright test runs successfully (even if no tests yet)
- [ ] #7 Playwright HTML reporter configured for CI output
<!-- AC:END -->
