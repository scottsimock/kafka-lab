# Squad Decisions

## Active Decisions

### Consolidate Ansible instructions into SKILL.md

**Author:** Parker (Infra Dev)  
**Date:** 2025-07-23  
**Status:** Accepted

Merged all content from `.github/instructions/coding-standards/ansible.instructions.md` into `.github/skills/ansible/SKILL.md`. Ansible guidance is now unified in a single reference file covering conventions, project structure, and best practices.

### Consolidate Terraform instructions into SKILL.md

**Author:** Parker (Infra Dev)  
**Date:** 2025-07-23  
**Status:** Accepted

Merged all content from `.github/instructions/coding-standards/terraform.instructions.md` into `.github/skills/terraform-azapi/SKILL.md`. Terraform and AzAPI guidance is now unified in a single reference file.

### Consolidate Azure Environment into REQUIREMENTS.md

**Author:** Ripley  
**Date:** 2026-03-31  
**Status:** Decided

Merged `azure-environment.instructions.md` content into REQUIREMENTS.md as a new top-level section. Azure environment guidance (regions, zones, compliance, networking, DNS) is now co-located with project scope and references.

### Sprint Workflow Instructions Rewrite

**Author:** Ripley  
**Date:** 2026-03-31  
**Status:** Implemented

Rewrote `.github/instructions/sprint-workflow.instructions.md` to focus on stable conventions (naming, branching, quality rubrics) and removed obsolete Ruby orchestrator content. Squad handles orchestration rules separately.

### Next.js 15 Scaffolding Conventions

**Author:** Dallas  
**Date:** 2026-03-31  
**Status:** Accepted

Use the following conventions for the Next.js 15 web application:

1. **Project location:** `webapp/` subdirectory (not repo root)
2. **Output mode:** `output: 'standalone'` for containerized Azure Function App deployment
3. **Compression:** `compress: false` — Azure Function App handles it
4. **Kafka library:** @confluentinc/kafka-javascript v1.8.2
5. **TypeScript:** strict mode enabled
6. **App Router structure:**
   - Route groups `(views)` to avoid URL nesting in dashboard
   - Server Components by default
   - Client Components only for interactivity (error boundaries, forms, etc.)
7. **Azure Functions integration:** Custom handler via host.json pointing to `.next/standalone/server.js`

**Rationale:** Standalone output required for Azure Function App custom handler deployment. No compression at Next.js level—Azure handles it. Subdirectory structure separates webapp from infrastructure. Route groups enable clean URLs. Server Components reduce client-side JavaScript and keep credentials server-side.

**Team Impact:** Parker creates Function App module referencing webapp build. Lambert runs tests from webapp/ directory. Ripley's architecture depends on standalone output for multi-region deployment.

### Schema Browser Architecture

**Author:** Dallas  
**Date:** 2026-03-31  
**Status:** Accepted

Server Components in Schema Browser fetch directly from Schema Registry, not through our API endpoints.

**Rationale:** Eliminates HTTP hop (browser → Next.js server → Schema Registry becomes Next.js server → Schema Registry). No duplicate proxying routes. Schema Registry API is stable. Server Components run server-side anyway.

**Implementation:** Created `lib/schema-registry.ts` for env-based config. Server Components use `fetch()` with `cache: 'no-store'`. API routes remain optional for future client-side needs. Error handling for Registry unavailability.

**Impact:** Faster page loads. Simpler codebase. API routes available for future expansion.

### Webpack Externals for Native Kafka Module

**Author:** Dallas  
**Date:** 2026-03-31  
**Status:** Accepted

Configure Next.js webpack to treat `@confluentinc/kafka-javascript` as external to prevent bundling native binary addon.

**Context:** Native Node.js addon (`confluent-kafka-javascript.node`) cannot be bundled by webpack. Attempted bundling caused build failures during page data collection.

**Implementation:** Added webpack config in `next.config.ts` to require native module at runtime rather than bundle during build.

**Impact:** Builds succeed. Standalone output includes native module. All API routes compile and run. No route handler changes needed.

**Alternatives considered:** Dynamic imports (adds complexity), lazy initialization (unnecessary delays), build-time mocks (doesn't catch real issues).

### Function App Module Architecture

**Author:** Parker  
**Date:** 2026-03-31  
**Status:** Accepted

Terraform module decisions for Azure Function App hosting Next.js 15 web application with VNet integration and Key Vault secret references.

**Key Decisions:**

1. **Plan:** Premium EP1 (ElasticPremium). Rationale: VNet integration required for private Kafka connectivity. Premium plans mature for VNet scenarios, more documented.
2. **Worker Runtime:** Custom. Rationale: Next.js 15 requires custom hosting. Preserves App Router without restructuring.
3. **Key Vault Pattern:** @Microsoft.KeyVault references in appSettings. Rationale: Secrets fetched at runtime, never in state. RBAC assignment (Key Vault Secrets User) enables audit trail.
4. **Storage:** Private network only, TLS 1.2 minimum. Aligns with project security baseline. Requires VNet integration.
5. **Variables:** Accept pre-existing subnet ID, UAMI IDs, Key Vault name. Module focuses solely on Function App. Other modules handle networking/identity.

**Implementation Notes:** Storage connection uses property reference syntax. RBAC uses random UUID. Module doesn't modify subnet delegation. App settings as array format (AzAPI requirement).

**Open Questions:** Subnet delegation for Premium plan validation pending (SP5.010). Storage access may need UAMI-based migration in future sprints.

## SP5 Complete — 2026-03-31T15:57:14 EDT

**Sprint:** SP5 — Web Application  
**Status:** COMPLETE

**Results:**
- 10/10 tasks Done (100%)
- Average quality score: ~99%
- All acceptance criteria met

**Review & Fixes:**
Ripley reviewed and approved with conditions. Three critical issues identified and fixed by Parker:

1. **Storage authentication:** Replaced broken blob endpoint URL with `AzureWebJobsStorage__accountName` pattern using managed identity + RBAC roles (Storage Blob Data Owner + Storage Queue Data Contributor)
2. **Schema Registry URL:** Added missing `SCHEMA_REGISTRY_URL` environment variable to Function App appSettings
3. **Consumer group state badge:** Fixed case mismatch in `formatConsumerGroupState` (title case: Stable, Rebalancing, Empty, Dead)

**Non-blocking warnings deferred:**
- Tailwind CSS not installed
- Ephemeral consumer groups (SSE streaming)
- SSE abort handler (client disconnect edge case)
- `any` types in shared Kafka module

**Deliverables:**
- Branch: `sprint/SP5-web-application` (14 commits)
- Next.js 15 web application with App Router (9 tasks)
- Azure Function App infrastructure + Terraform module (1 task + 3 review fixes)
- All views: dashboard, topics, consumer groups, messages, schemas
- API routes: cluster metadata, topics, consumer groups, message produce/consume/stream, schemas
- Shared Kafka client library with @confluentinc/kafka-javascript

**Team Effort:**
- **Dallas:** 9 tasks (frontend, views, API routes, shared client module)
- **Parker:** 1 task (Function App Terraform) + 3 critical review fixes

---

### Sprint Report Standard

**By:** Smiley (Lead/Architect)  
**Date:** 2026-04-01  
**Status:** Accepted

Sprint reports live in `.squad/reports/SP{N}-report.md` with a consolidated summary at `.squad/reports/sprint-summary.md`. Generated at sprint completion using backlog task data.

**Structure:** Each sprint report includes:
- Summary (status, task count, average quality, branch)
- Deliverables (key artifacts created)
- Tasks (table with task ID, title, priority, status)
- Key Decisions (from decisions.md)
- Team Contributions (who worked on what)
- Notes (review issues, fixes, carryover items)

**Consolidated summary includes:**
- Progress overview table (all sprints)
- Cumulative statistics (total tasks, quality average)
- Architecture evolution narrative
- Next steps

**Rationale:** Provides historical record of sprint outcomes, team contributions, quality metrics, and architectural evolution. Supports retrospectives, progress tracking, and knowledge transfer.

**Data source:** Backlog tasks via backlog MCP tools. Parent sprint tasks (TASK-27 through TASK-35) contain sprint-level metadata and notes. Child tasks provide granular deliverable and quality data.

**Team Impact:** All agents can reference sprint reports to understand project history and architectural decisions. Squad orchestrator uses reports for progress tracking and planning.

### Task Documentation Standard

**Author:** Smiley (Lead/Architect)  
**Date:** 2026-04-01  
**Status:** Proposed

## Context

Reviewed SP0–SP4 backlog tasks (TASK-27.6, TASK-28.5, TASK-29.1, TASK-30.1, TASK-31.3) to understand how agents document work completion. Found consistent patterns:

1. **Acceptance criteria** are checked off progressively as agents complete them (`[x]`)
2. **Implementation notes** use agent-stamped log entries with ISO 8601 timestamps
3. **Artifacts are documented** — file paths, document IDs, commit messages, commands
4. **Quality scores are recorded** — structured rubric breakdowns with pass/fail verdicts
5. **Handoffs are visible** — notes show TL assignment → Coder implementation → Tester review → Done

## Decision

Formalize this documentation pattern in `.squad/templates/task-documentation.md` so all squad agents follow the same structure.

## Standard

### Core Fields

1. **Acceptance Criteria** — agents check off via `acceptanceCriteriaCheck: [N]` as work completes
2. **Implementation Notes** — agents append via `notesAppend` with format:
   ```
   ## [Agent Name] YYYY-MM-DDTHH:MM:SSZ
   - Work summary
   - Key decisions
   - Artifacts (file paths, document IDs, commits)
   - Quality metrics if applicable
   ```
3. **Implementation Plan** — optional pre-execution planning via `planSet` or `planAppend`
4. **Final Summary** — post-completion prose via `finalSummary` for PR descriptions

### Agent Responsibilities

- **Implementors:** Append notes on start, during work, and on completion. Check AC items. Set status to Dev Complete.
- **Reviewers:** Document findings with structured score breakdown. Check/uncheck AC. Set status to Done (pass) or In Progress (retry).
- **Leads:** Document assignments and handoffs. Set assignee field.

### Handoff Documentation

Critical handoff points documented in notes:
- TL → Implementor (assignment)
- Implementor → Reviewer (dev complete with artifacts)
- Reviewer → Implementor (retry with findings)
- Reviewer → Done (pass with score)

### Quality Recording

Research tasks (95% threshold):
```
- Accuracy: 82/100 — {finding}
- Completeness: 93/100 — {finding}
- Sources: 88/100 — {finding}
- Documentation Quality: 96/100
- Actionability: 93/100
```

Coding tasks (90% threshold):
```
- Acceptance Criteria: 30/30
- Tests: 25/25
- Code Quality: 20/20
- Documentation: 15/15
- Dependencies: 10/10
```

### Status Discipline

Agents MUST update status when crossing lifecycle boundaries:
- To Do → In Progress (agent starts)
- In Progress → Dev Complete (work finished)
- Dev Complete → In Review (review assigned)
- In Review → Done (review passes)
- In Review → In Progress (review fails, retry)
- Any → Blocked (cannot proceed)

### Documentation Check

Reviewers verify before marking Done:
1. All AC items checked off
2. At least 2 implementation note entries (start + completion, review verdict)
3. ISO 8601 timestamps present
4. Artifacts documented (files, commits, document IDs)
5. Status aligned with AC completion
6. Handoffs traceable

## Rationale

**Problem:** The existing pattern (SP0–SP4) works well but is undocumented. New agents or human reviewers might not know the conventions.

**Solution:** Codify the pattern so all agents follow it consistently. This creates:
- **Visible handoffs** — humans can trace work through the squad
- **Traceable artifacts** — every task links to concrete deliverables
- **Quality transparency** — review scores and pass/fail decisions are recorded
- **Status accuracy** — AC checkmarks and status field stay synchronized

## Impact

- **All squad agents** must follow this standard when editing backlog tasks
- **Reviewers** enforce documentation quality before marking tasks Done
- **Humans** can scan backlog tasks to see full work history without needing to read code diffs
- **Sprint reports** have richer source data (completion timestamps, quality scores, handoffs)

## Implementation

1. Created `.squad/templates/task-documentation.md` with full standard (12KB, 400+ lines)
2. Append to `smiley/history.md` under Learnings
3. Add "Documentation Check" section to ceremonies.md if needed (optional — already implicit in review process)

## Example

**Before:** Task shows `Status: Done` with unchecked AC and no notes.

**After:**
```markdown
Status: ✔ Done
Acceptance Criteria:
- [x] #1 Module exists
- [x] #2 terraform validate passes

Implementation Notes:
## [Coder] 2026-03-30T16:43:00Z
- Created terraform/modules/vm/ with 4 files
- terraform fmt and validate passed
- Committed: feat(SP2.001)

## [Tester] 2026-03-30T19:35:00Z
- Score: 100% — PASS
- All AC met, tests pass, clean code
```

Now humans see: who did the work, when, what was delivered, and that it passed review.

### SP5 — Web Application Sprint Review

**Reviewer:** Ripley (Lead / Architect)
**Date:** 2026-04-01
**Branch:** `sprint/SP5-web-application` vs `main`
**Scope:** 114 files, ~15K lines — Terraform Function App module + Next.js 15 webapp

---

## VERDICT: APPROVE WITH CONDITIONS

The sprint is merge-ready. Architecture is sound, patterns are consistent, build passes clean. Three issues must be addressed before merge — all are straightforward fixes that won't require rearchitecting anything.

---

## Critical Issues (must fix before merge)

### 1. AzureWebJobsStorage connection string uses wrong property reference

**File:** `terraform/modules/function-app/main.tf:119`

The storage connection string references `azapi_resource.storage.output.properties.primaryEndpoints.blob` — this is a blob endpoint URL, not an account key. The connection string format requires `AccountKey=<key>`, not a URL. This will cause the Function App to fail at runtime because Azure Functions cannot connect to its backing storage.

**Fix:** Use a connection string with `AccountKey` from `output.properties.primaryAccessKey`, or switch to UAMI-based storage auth (the modern approach). Alternatively, store the storage connection string in Key Vault. Assign to **Parker**.

### 2. `SCHEMA_REGISTRY_URL` missing from Function App app settings

**File:** `terraform/modules/function-app/main.tf` (appSettings array)

The webapp's `lib/schema-registry.ts` reads `process.env.SCHEMA_REGISTRY_URL`. The Terraform module defines app settings for `KAFKA_*` secrets but never sets `SCHEMA_REGISTRY_URL`. In production, the schema browser will always fall back to the hardcoded `http://schema-registry:8081`, which only works if DNS resolution is in place. This should be explicit — either as a Key Vault reference or a direct variable.

**Fix:** Add `SCHEMA_REGISTRY_URL` to the Function App appSettings. Add a corresponding variable to `variables.tf`. Assign to **Parker**.

### 3. `formatConsumerGroupState` doesn't actually format — just uppercases

**File:** `webapp/lib/api/consumer-groups.ts:34-38`

The function calls `String(state).toUpperCase()` but the consumer groups page checks `stateStr === 'Stable'` (mixed case). These will never match — `'STABLE' !== 'Stable'`. The state badges will always show the warning (yellow) color, never the stable (green) color.

**Fix:** Either title-case the state string properly, or compare against uppercase. Assign to **Dallas** (not the original author — fresh eyes).

---

## Warnings (should fix, not blocking)

### 1. Schema browser pages use Tailwind CSS classes without Tailwind installed

**Files:** `webapp/app/dashboard/(views)/schemas/page.tsx`, `schemas/[subject]/page.tsx`, `messages/*.tsx`

These files use `className="text-2xl font-bold mb-4"` and similar Tailwind utility classes, but `package.json` has no Tailwind dependency. The rest of the dashboard uses inline styles. The classes render as no-ops — no visual breakage, but the schema browser and message views will have no styling.

**Recommendation:** Either install Tailwind or convert to inline styles for consistency with the rest of the dashboard. Low priority since this is a lab environment.

### 2. Consumer group consume endpoint creates ephemeral consumer groups per request

**File:** `webapp/app/api/messages/consume/route.ts:31`

`groupId: \`kafka-lab-browser-${Date.now()}\`` creates a new consumer group on every request. These accumulate in the broker's group coordinator. Not a problem at lab scale, but the group metadata doesn't get cleaned up automatically (default `offsets.retention.minutes` is 7 days).

**Recommendation:** Add a comment documenting this is intentional for the lab, or implement cleanup.

### 3. SSE stream consumer may leak on error path

**File:** `webapp/app/api/messages/stream/route.ts:31-38`

The abort handler calls `consumer.disconnect()` then `controller.close()`. If the consumer is in `run()` when abort fires, `disconnect()` may throw because the consumer loop hasn't fully stopped. The `try/catch` handles it, but `controller.close()` is called unconditionally after `disconnect()` — if disconnect succeeds but the controller was already errored, this will throw unhandled.

**Recommendation:** Wrap `controller.close()` in its own try/catch.

### 4. `any` type in consumer group member assignments

**File:** `webapp/lib/api/consumer-groups.ts:14`

`assignments: any` — should be properly typed or at minimum `unknown`.

---

## Notes (observations, suggestions for future)

1. **Styling inconsistency** — The schemas/messages views use Tailwind utility classes while all other dashboard views use inline styles. Pick one approach in SP6 or SP7.

2. **Dashboard nav uses `<a>` instead of `next/link`** — `webapp/app/dashboard/layout.tsx` and `app/layout.tsx` use raw `<a>` tags for navigation. This triggers full page reloads instead of client-side navigation. Works fine but loses the SPA feel. Consider migrating to `<Link>` from `next/link`.

3. **Schema browser duplicates logic between API routes and Server Components** — Both `app/api/schemas/route.ts` and `app/dashboard/(views)/schemas/page.tsx` have identical schema-fetching logic. The architecture decision says Server Components fetch directly (good), but the API routes duplicate the same code. Consider extracting shared functions to `lib/schema-registry.ts`.

4. **`host.json` custom handler path** — Points to `.next/standalone/server.js`. This is correct for `output: 'standalone'` in Next.js 15. Verified against the decisions doc.

5. **Build produces a warning about Schema Registry fetch during static generation** — The error in build output (`Dynamic server usage: Route /dashboard/schemas couldn't be rendered statically`) is expected and handled correctly by `export const dynamic = 'force-dynamic'` which forces runtime rendering. The logged error is cosmetic.

6. **Good separation of concerns** — `lib/api/` layer abstracts Kafka admin calls away from pages. API routes for client-side use, lib functions for Server Components. Clean.

7. **SIGTERM handler in kafka client** — Good practice for graceful shutdown in Azure Functions. The implementation correctly nulls the singleton for GC.

---

## Acceptance Criteria Check

| AC Item | Status | Notes |
|---|---|---|
| Next.js 15 App Router with Server Components | ✅ Pass | All dashboard pages are Server Components; `'use client'` only on interactive components |
| Shared Kafka client with singleton pattern | ✅ Pass | `lib/kafka/client.ts` — singleton, env validation, SIGTERM handler |
| API routes with proper error handling | ✅ Pass | try/catch/finally with admin.disconnect() in all routes |
| Dashboard views (overview, topics, messages, schemas, consumer groups) | ✅ Pass | All views implemented with data fetching |
| SSE streaming for real-time messages | ✅ Pass | ReadableStream with abort signal cleanup |
| Schema browser using HTTP fetch (not Kafka client) | ✅ Pass | Server Components fetch directly from Schema Registry |
| Error boundaries with `'use client'` and reset | ✅ Pass | All route segments have error.tsx with correct pattern |
| `next.config.ts`: standalone output, compress false, webpack externals | ✅ Pass | All three configured correctly |
| `host.json`: custom handler for Next.js | ✅ Pass | Points to `.next/standalone/server.js` |
| TypeScript strict mode | ✅ Pass | `tsconfig.json` has `"strict": true` |
| Build passes | ✅ Pass | `npm run build` completes successfully |
| Terraform Function App module with AzAPI | ⚠️ Conditional | Module structure correct but storage connection string is broken (Critical #1) |
| Key Vault references for Kafka credentials | ✅ Pass | `@Microsoft.KeyVault()` syntax correct |
| Premium EP1 with VNet integration | ✅ Pass | ElasticPremium EP1, subnet ID, VNET routing enabled |
| UAMI assigned, public access disabled, TLS 1.2 | ✅ Pass | All three configured |

---

## Summary

Solid sprint. The webapp architecture follows the decisions doc precisely — Server Components default, Client Components for interactivity, direct Schema Registry fetch, webpack externals for native module. The Terraform module is structurally correct but has a runtime-breaking storage connection string issue.

Fix the three critical items and this merges clean.

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
