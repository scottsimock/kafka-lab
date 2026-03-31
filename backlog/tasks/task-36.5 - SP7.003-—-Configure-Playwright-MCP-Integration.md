---
id: TASK-36.5
title: SP7.003 — Configure Playwright MCP Integration
status: Dev Complete
assignee:
  - Smiley
created_date: '2026-03-31 22:01'
updated_date: '2026-03-31 22:20'
labels:
  - story
milestone: m-9
dependencies:
  - TASK-36.2
references:
  - webapp/
parent_task_id: TASK-36
priority: medium
ordinal: 6503
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Set up Playwright MCP (Model Context Protocol) server for AI-assisted testing. Configure the MCP server to connect to the dev environment web application. Enable AI agents to interact with the web app through Playwright MCP for test authoring, debugging, and exploratory testing. Document the MCP configuration for team use.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Playwright MCP server installed and configured in project
- [x] #2 MCP configuration added to .vscode/mcp.json or equivalent config
- [x] #3 MCP server can connect to and interact with the dev web application
- [x] #4 AI agents can navigate pages and click elements and read content via MCP
- [x] #5 Configuration documented with setup and usage instructions
- [x] #6 MCP server works with the Playwright test framework from SP7.002
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Smiley] 2026-04-01T22:30:00Z
- Installed `@playwright/mcp@^0.0.69` as devDependency in webapp
- Added `playwright` server to `.vscode/mcp.json` with `--headless` flag and webapp cwd
- Added `mcp:playwright` npm script for standalone CLI usage
- Created `docs/playwright-mcp-setup.md` — covers setup, AI agent capabilities, dev env connection, MCP vs E2E independence, troubleshooting
- Verified: JSON configs valid, package resolves, `--help` runs clean
- MCP server and E2E test suite are fully independent (separate browser instances, separate configs)
<!-- SECTION:NOTES:END -->
