---
id: TASK-36
title: SP7 — Dev Environment Deployment & Integration Testing
status: To Do
assignee: []
created_date: '2026-03-31 21:59'
labels:
  - sprint
milestone: SP7
dependencies: []
priority: high
ordinal: 6500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Deploy the complete single-region development environment to Azure and validate it works end-to-end using Playwright and Playwright MCP. This sprint proves the dev environment is functional before multi-region expansion in SP8. Covers Terraform apply, Ansible provisioning, Playwright test framework setup, smoke tests, integration tests for all web app features, E2E environment validation, CI/CD for tests, and cost-management teardown scripts.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Dev environment fully deployed to Azure (Terraform + Ansible) in southcentralus single region
- [ ] #2 Playwright test framework configured and integrated with the Next.js web application
- [ ] #3 Playwright MCP configured for AI-assisted test authoring and debugging
- [ ] #4 Smoke tests pass for all web app pages and API health endpoints
- [ ] #5 Integration tests pass for Kafka dashboard, operations, and Schema Registry UI
- [ ] #6 E2E environment validation confirms full stack health (VMs, Kafka, web app, Function App)
- [ ] #7 CI/CD pipeline runs integration tests automatically on push
- [ ] #8 Teardown scripts can destroy and recreate the dev environment reliably
<!-- AC:END -->
