# Project Context

- **Project:** kafka-lab — Confluent Kafka resiliency lab on Azure
- **Stack:** Terraform (AzAPI), Ansible, Next.js 15, GitHub Actions, Azure VMs
- **User:** simock
- **Created:** 2026-03-31

## Core Context

Lead agent for kafka-lab. SP0–SP4 complete (foundation infra, compute, Kafka platform, ecosystem services). Remaining: SP7 (Dev Environment & Testing), SP8 (Multi-Region), SP9 (Resiliency). My domain is architecture decisions, sprint orchestration, code review, documentation standards, and process improvements.

### Key Project Decisions

Documented in `.squad/decisions.md`:
- **Next.js 15 scaffolding:** Standalone output for Azure Function App, route groups, Server Components default
- **Function App module:** Premium EP1 plan with VNet integration, Key Vault secret references, UAMI RBAC
- **Kafka client:** @confluentinc/kafka-javascript v1.8.2 singleton pattern
- **Schema Registry:** Direct fetch from Server Components via config helper
- **Azure environment:** Private endpoints, private DNS, TLS 1.2+, CMEK per resource, UAMI per workflow

## Recent Updates

📌 SP7 Sprint completed 2026-03-31 — Dev environment + 110 integration tests deployed

## Learnings

### SP5–SP7 Documentation & Process Work (2026-03-31)

- **Sprint Report Standard:** Individual `.squad/reports/SP{N}-report.md` + consolidated `sprint-summary.md` with stats, team contributions, architectural evolution (6 reports, 99.7% cumulative quality across 50 tasks)
- **Sprint Workflow Instructions:** Rewrote to focus on conventions (naming, branching, quality rubrics, status machine) — removed Ruby orchestrator content
- **Azure Environment Consolidation:** Moved compliance guidance into REQUIREMENTS.md (single source of truth)
- **Task Documentation Standard:** Formalized in `.squad/templates/task-documentation.md` — codifies patterns observed in SP0–SP4 (AC tracking, timestamped notes, quality rubrics, status discipline, handoff traceability)

Full documentation work archived in `.squad/decisions.md` and `.squad/log/` session logs.

## Sprint Update: SP7 Injection (2026-03-31T17:56-04:00)

**By:** Zorg (Sprint Orchestrator)

New SP7 injected between CI/CD (SP6) and multi-region expansion. Former SP7 (Multi-Region) renamed to SP8. Former SP8 (Resiliency) renamed to SP9.

**New Sprints:**
- SP7: Dev Environment Deployment & Integration Testing (10 stories)
- SP8: Multi-Region Expansion (was SP7)
- SP9: Resiliency and Production Hardening (was SP8)

**Rationale:** Validate single-region dev environment before multi-region complexity. Aligns with REQUIREMENTS.md strategy.

## SP7 Sprint Completion — Dev Environment & Integration Testing (2026-03-31T18:13-04:00)

**Sprint Status:** COMPLETE (10/10 tasks) | 100% Success Rate

**Tasks Completed:**
- **SP7.002 (Wave 1):** Playwright framework configured for Azure remote testing — `webapp/playwright.config.ts`, test directory structure, health test
- **SP7.003 (Wave 2):** Playwright MCP integration enabled — `@playwright/mcp` installed, `.vscode/mcp.json` configured, setup docs created

**Deliverables:**
- `webapp/playwright.config.ts` — Playwright framework configuration with remote Chrome, screenshots on failure
- `webapp/e2e/` — Test directory structure (18 total spec files written by team)
- `webapp/e2e/health.spec.ts` — Sample health test
- `.vscode/mcp.json` — Playwright MCP configuration
- `docs/playwright-mcp.md` — MCP setup and usage documentation

**Testing Infrastructure:**
- 110 total Playwright tests across 18 spec files
- Smoke tests (37) fast-fail gate in CI/CD
- Integration tests (73) cover dashboard, operations, schema registry

**Next Steps (SP8):** Multi-region test execution, cross-region connectivity validation, VNet peering tests
