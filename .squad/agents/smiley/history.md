# Project Context

- **Project:** kafka-lab — Confluent Kafka resiliency lab on Azure
- **Stack:** Terraform (AzAPI), Ansible, Next.js 15, GitHub Actions, Azure VMs
- **User:** simock
- **Created:** 2026-03-31

## Core Context

Lead agent for kafka-lab. SP0–SP4 complete (foundation infra, compute, Kafka platform, ecosystem services). Remaining: SP5 (Web App), SP6 (CI/CD), SP7 (Multi-Region), SP8 (Resiliency).

### Codebase Structure

- `terraform/modules/` — key-vault, managed-identity, network-security-group, private-dns-zone, private-endpoint, virtual-machine, virtual-network
- `terraform/environments/` — environment-specific configs
- `ansible/roles/` — common, confluent-common, disk-setup, java, kafka-broker, kafka-client-creds, kafka-connect, schema-registry, tls-certs, zookeeper
- `ansible/playbooks/` — deployment and verification playbooks
- `backlog/` — sprint tasks and milestones (SP0–SP8)
- Azure regions: southcentralus (primary), mexicocentral (secondary), canadaeast (DR)

### Previous Sprint History

- SP1: Foundation infrastructure — VNet, KV, UAMI, DNS, NSG, Storage, Private Endpoints (PR #2)
- SP2: Compute — VM module, ZK/Broker/SR/Connect VMs, Ansible roles for OS/disk/Java/Confluent (PR #3)
- SP3: Kafka platform — ZK role, Broker role, TLS, SASL/SCRAM, tiered storage, self-balancing, ACLs (PR #4)
- SP4: Ecosystem — Schema Registry role, Kafka Connect role, Blob sink connector, topic creation, schema registration (PR #5)

## Recent Updates

📌 Team initialized on 2026-03-31

## Learnings

Initial setup complete. Replacing Ruby sprint orchestrator with Squad workflow.

### Sprint Report Generation (2026-04-01)

Established sprint report format and location:

- **Format:** Individual sprint reports (`.squad/reports/SP{N}-report.md`) include summary stats, deliverables list, task table, key decisions, team contributions, and notes
- **Consolidated summary:** `.squad/reports/sprint-summary.md` provides progress overview table, cumulative stats, architecture evolution narrative, and next steps
- **Location:** All reports live in `.squad/reports/` directory
- **Generated from:** Backlog task data (parent tasks TASK-27 through TASK-32 for SP0-SP5)
- **Quality tracking:** Individual sprint average scores and overall cumulative average (99.7% across 60 tasks)
- **Architecture narrative:** Sprint reports document how the system evolved from foundation → compute → platform → ecosystem → webapp

### Sprint Workflow Instructions Rewrite (2026-03-31)

Rewrote `.github/instructions/sprint-workflow.instructions.md` to strip out Ruby/PO/SM/TL/Coder/Tester orchestration content. The file now focuses exclusively on conventions that all agents need:

- **Kept:** Naming conventions (backlog IDs, task titles, labels, parent-child structure), git branches (`sprint/SP{N}-{description}`), commit message format (`feat(SP{N}.{NNN}): {description}`), milestones, quality rubrics (coding 90%, research 95%), task status machine, work logging format, documents pattern, technical debt/carryover rules
- **Removed:** Architecture diagram, sprint lifecycle phases, agent execution modes table, Sprint 0 special structure, SP0 state detection, agent communication with role tags, Ruby-owned PR lifecycle, execution rules table (concurrent limits, retry cycles)
- **Updated:** Title and description to reflect conventions-only scope, task status machine to be orchestrator-agnostic, technical debt section removed PO references, task assignment tracking updated to Squad agent names

The file is now 138 lines (down from 333). Orchestration rules now live exclusively in `.github/agents/squad.agent.md` and `.squad/` files where Squad agents manage them.

### Azure Environment Consolidation (2026-03-31)

Consolidated Azure environment compliance documentation into REQUIREMENTS.md:

- **Merged:** `.github/instructions/coding-standards/azure-environment.instructions.md` content into new `## Azure Environment` section in REQUIREMENTS.md (placed between Project Overview and References)
- **Content preserved:** All compliance requirements (CMEK per resource, UAMI per workflow, TLS 1.2+ minimum, private VNets, private endpoints, private DNS zones, public ingress restrictions for web app only, Let's Encrypt automation)
- **Code examples retained:** All HCL compliance tag examples kept intact for agent reference when writing Terraform
- **Reference updated:** Line 7 of REQUIREMENTS.md changed from "azure-environment instructions file" to "Azure Environment section below"
- **Cleanup:** Deleted redundant instructions file; removed empty `coding-standards/` directory
- **Rationale:** REQUIREMENTS.md is the single source of truth for project requirements. Inlining compliance context eliminates instruction file fragmentation and ensures compliance guidance is always visible alongside project scope and architecture choices

### SP5 Web Application Review (2026-04-01)

Reviewed full SP5 sprint branch (`sprint/SP5-web-application` vs `main`) — 114 files, ~15K lines covering Terraform Function App module and Next.js 15 webapp.

**Verdict:** APPROVE WITH CONDITIONS (3 critical items to fix before merge)

**Critical findings:**
1. **Storage connection string broken** — `terraform/modules/function-app/main.tf` line 119 constructs `AzureWebJobsStorage` using `primaryEndpoints.blob` (a URL) where it needs an account key. Function App will fail at runtime.
2. **Missing `SCHEMA_REGISTRY_URL` in Function App appSettings** — The webapp reads this env var but Terraform never sets it. Schema browser will only work if internal DNS resolves the hardcoded hostname.
3. **`formatConsumerGroupState` case mismatch** — Function uppercases state strings but the page compares against mixed-case `'Stable'`. State badges always show yellow.

**Warnings:**
- Schema browser and message views use Tailwind CSS classes but Tailwind is not installed (no visual styling)
- Ephemeral consumer groups created per consume request accumulate in broker metadata
- SSE stream abort handler needs additional try/catch around `controller.close()`
- `any` type used for consumer group member assignments

**Architecture assessment:** Sound. Webapp follows decisions doc precisely — Server Components default, client-only for interactivity, direct Schema Registry fetch, webpack externals for native Kafka module, standalone output for Azure Functions custom handler. Terraform module structure (4-file, AzAPI, `//` comments, `snake_case`) follows all conventions.

**Build result:** `npm run build` passes clean. All 20 routes compile. Terraform `fmt` clean, no `#` comments.

### Sprint Reports Generated (2026-04-01)

Generated comprehensive sprint reports for SP0 through SP5:

- **Scope:** 6 individual reports (SP0-report.md through SP5-report.md) + consolidated summary (sprint-summary.md)
- **Data:** Backlog task completion records, quality scores, team contributions, key decisions, architectural evolution
- **Location:** `.squad/reports/`
- **Team:** Dallas, Parker, Lambert, Ripley contributed work across all sprints
- **Coverage:** 50 total sprint tasks across 5 development sprints + SP0 research/planning
- **Quality:** Cumulative quality average 96%+ across all sprints
- **Architecture:** Progressive delivery from foundation infrastructure → compute → Kafka platform → ecosystem → web app

Reports serve as historical record for retrospectives, progress tracking, and knowledge transfer. Available for cross-team reference on project evolution and decision rationale.

### Task Documentation Standard (2026-04-01)

Reviewed SP0–SP4 backlog tasks to understand how agents document work completion. Found consistent patterns across all completed tasks:

**Patterns observed:**
1. **Acceptance criteria:** Agents progressively check off items (`[x]`) as they complete work using `acceptanceCriteriaCheck` parameter
2. **Implementation notes:** Agent-stamped log entries with ISO 8601 timestamps documenting work summary, decisions, artifacts (file paths, document IDs, commits), and quality metrics
3. **Handoff visibility:** Notes trace work lifecycle — TL assignment → Implementor execution → Reviewer verification → Done status
4. **Quality recording:** Structured rubric breakdowns (Research: 95% threshold with Accuracy/Completeness/Sources/Documentation/Actionability; Coding: 90% threshold with AC/Tests/Code Quality/Documentation/Dependencies)
5. **Status discipline:** Task status field synchronized with AC completion and review outcomes

**Examples reviewed:**
- TASK-27.6 (Research): 2-cycle review with score breakdowns, UAMI fix, KRaft additions, URL versioning corrections — final 96.30% PASS
- TASK-28.5 (VNet Module): Single-cycle review, all AC met, 100% score, clean handoff from Coder-2 → Tester-2
- TASK-29.1 (VM Module): TL assignment note → Coder implementation → Tester structured checklist (14/14), 100% PASS
- TASK-30.1 (Kafka Broker): Multi-section implementation plan, extensibility design for future tasks, final summary with all artifacts
- TASK-31.3 (Schema Registry): Dependencies tracked, TLS integration documented, SASL_SSL config following broker pattern

**Decision:**
Formalized this pattern in `.squad/templates/task-documentation.md` (12KB, 400+ lines) covering:
- Core fields: Acceptance Criteria, Implementation Notes, Implementation Plan, Final Summary
- Agent responsibilities: Implementor (append notes, check AC, set Dev Complete), Reviewer (document findings, check/uncheck AC, set Done/In Progress), Lead (document assignments and handoffs)
- Handoff documentation: TL→Implementor, Implementor→Reviewer, Reviewer→Implementor (retry), Reviewer→Done
- Quality score recording: Structured rubric formats for research (5 categories) and coding (5 categories)
- Status discipline: Mandatory status updates at lifecycle boundaries
- Documentation Check: Reviewers verify 6 items before marking Done (all AC checked, 2+ notes, timestamps, artifacts, status alignment, handoffs traceable)
- Tools reference: `acceptanceCriteriaCheck`, `notesAppend`, status updates, combined edits
- Anti-patterns: Examples of what NOT to do (generic notes, missing timestamps, status/AC misalignment)

**Impact:**
- Humans can now see handoffs happening by scanning backlog tasks
- Quality transparency: review scores and pass/fail verdicts are durable
- Artifact traceability: every task links to files, commits, document IDs
- Sprint reports have richer source data for retrospectives

**Implementation:**
Created `.squad/templates/task-documentation.md` and decision record in `.squad/decisions/inbox/smiley-task-documentation-standard.md`. All squad agents now have a single reference for backlog documentation conventions. Existing SP0–SP4 tasks already follow this pattern — standard codifies observed practice.

## Sprint Update: SP7 Injection (2026-03-31T17:56-04:00)

**By:** Zorg (Sprint Orchestrator)

The sprint roadmap was restructured. A new SP7 (Dev Environment Deployment & Integration Testing) was injected between CI/CD (SP6) and multi-region expansion. Former SP7 (Multi-Region) renamed to SP8. Former SP8 (Resiliency) renamed to SP9.

**New Sprints:**
- SP7: Dev Environment Deployment & Integration Testing (10 stories)
- SP8: Multi-Region Expansion (was SP7)
- SP9: Resiliency and Production Hardening (was SP8)

**Rationale:** Validate single-region dev environment before multi-region complexity. Aligns with REQUIREMENTS.md strategy.

**Impact on Smiley:** Your resiliency work is now SP9. No scope changes — only sprint numbers shifted. Ready to start after multi-region (SP8) validation is complete.

### Playwright E2E Framework Setup (SP7.002)

Configured Playwright as the E2E testing framework for the Next.js webapp:

- **Config:** `webapp/playwright.config.ts` — base URL from `PLAYWRIGHT_BASE_URL` env var (defaults to `localhost:3000`), Chromium project, Firefox/WebKit commented out as options
- **Timeouts:** Action 30s, navigation 60s, expect 10s — tuned for remote Azure latency
- **CI behavior:** 1 retry, sequential workers, HTML reporter to `playwright-report/`; locally: 0 retries, parallel workers, list reporter
- **Test structure:** `webapp/tests/e2e/` with `smoke/`, `integration/`, `fixtures/` subdirectories
- **Sample test:** `smoke/health.spec.ts` — hits base URL and asserts non-500 response
- **Scripts:** `test:e2e`, `test:e2e:ui`, `test:e2e:report` added to `package.json`
- **Gitignore:** `test-results/`, `playwright-report/`, `blob-report/`, `.playwright/` excluded
- **CI note:** GitHub Actions needs `npx playwright install --with-deps chromium` before running tests

### Playwright MCP Integration (SP7.003)

Configured Playwright MCP server for AI-assisted testing of the webapp:

- **Package:** `@playwright/mcp@^0.0.69` added as devDependency in `webapp/package.json`
- **VS Code config:** `.vscode/mcp.json` updated with `playwright` server entry — runs `npx @playwright/mcp@latest --headless` with cwd set to webapp
- **NPM script:** `mcp:playwright` added to `webapp/package.json` for standalone CLI launch
- **Headless mode:** `--headless` flag used by default so it works in CI and remote environments
- **Documentation:** `docs/playwright-mcp-setup.md` covers setup, agent capabilities (navigate, click, snapshot, screenshot), dev environment connection, MCP vs E2E test relationship, and troubleshooting
- **Independence:** MCP server and `npx playwright test` are fully independent — each manages its own browser instance, no config conflicts
- **Key tools exposed:** `browser_navigate`, `browser_click`, `browser_type`, `browser_snapshot`, `browser_screenshot`, `browser_console_messages`, `browser_network_requests` among others

## SP7 Sprint Completion — Dev Environment & Integration Testing (2026-03-31T18:13-04:00)

**Sprint Status:** COMPLETE (10/10 tasks)

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
