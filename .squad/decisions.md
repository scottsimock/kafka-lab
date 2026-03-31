# Squad Decisions

## Active Decisions

### Function App Module Wired into Dev Environment

**Author:** Drexl  
**Date:** 2026-03-31  
**Task:** SP7.001  
**Status:** Implemented

The Function App module (`terraform/modules/function-app/`) defined in SP5 was instantiated in the dev environment's Terraform config:

- Module call added as `klc-func-kafkalab-scus` with Premium EP1 plan
- Private endpoint `klc-pe-func-scus` routes traffic through `snet-private-endpoints`
- DNS zone `privatelink.azurewebsites.net` resolves Function App hostname privately
- Schema Registry URL configured as `http://sr-01.kafkalab.internal:8081` (internal DNS)
- All Kafka secrets injected via `@Microsoft.KeyVault()` references from Key Vault

**Impact:** Function App deployable for Smiley (Frontend). Integration tests can target Function App private endpoint. Dev verification uses PLAINTEXT (not SASL_SSL).

---

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

---

# Architecture Review: SP6 — CI/CD Pipeline

**Reviewer:** Drexl (Lead/Architect)
**Date:** 2026-04-01T10:30:00 ET
**Sprint:** SP6 — CI/CD Pipeline (TASK-33)
**Files reviewed:** 6 workflows, 4 config files, 2 docs

## Verdict: APPROVE WITH CONDITIONS

Four required changes before these workflows are production-ready. The architectural bones are sound — reusable workflow pattern, OIDC auth, concurrency controls, environment gating — but there are wiring bugs that prevent core workflows from functioning at runtime.

---

## Security Posture

**Grade: B+**

**Strengths:**

- Least-privilege permissions per job (`id-token: write`, `contents: read`). No `write-all` anywhere.
- OIDC throughout — no long-lived secrets stored. `ARM_USE_OIDC: "true"` set correctly.
- `azure/login@v2` with explicit `client-id`, `tenant-id`, `subscription-id` on all Azure steps.
- Ansible workflow masks secrets with `::add-mask::` for both SSH key and Vault password.
- Ansible cleanup step runs under `if: always()` — sensitive files removed even on failure.
- Environment-scoped secrets prevent cross-environment credential leakage.

**Concerns:**

- **Action versions pinned by major tag, not SHA.** `actions/checkout@v4`, `hashicorp/setup-terraform@v3`, `azure/login@v2`, etc. Major tags can be force-pushed. For production-grade pipelines, actions should be pinned to commit SHA with version comment. Not blocking for SP6 but must be addressed before prod runs.
- **webapp-deploy.yml copies `local.settings.json` into deploy package.** This file is gitignored and may contain local secrets. If it accidentally gets committed, it ships to Azure. The copy should be conditional or the file should be generated from a template during build.
- **Ansible Key Vault name hardcoded** (`klc-kv-kafkalab-scus`). If prod uses a different vault, secrets retrieval fails silently or returns wrong secrets. Should be parameterized via input or env-derived.

---

## Architectural Coherence

**Grade: B**

**Strengths:**

- Clean `workflow_call` signatures on all three reusable workflows. Inputs are well-typed with sensible descriptions.
- deploy-all.yml correctly chains terraform → ansible → webapp with component selection and dry-run mode.
- `always() && !failure()` pattern correctly handles skipped upstream jobs (e.g., `ansible-only` skips terraform but ansible still runs).
- Concurrency group `deploy-${{ github.event.inputs.environment }}` prevents parallel deploys to the same environment.
- PR validation runs all three checks (terraform validate, webapp build, ansible syntax) in parallel.

**Issues:**

- **Terraform workflows don't use the tfvars files.** `terraform plan` runs without `-var-file` and without `-var` flags. The `subscription_id` and `ssh_public_key` variables in `variables.tf` are required (no defaults) and have no source. Every `terraform plan` invocation across terraform-deploy.yml, drift-detection.yml, and pr-validation.yml will fail at runtime with "No value for required variable." The environment configs (TASK-33.1) were delivered but never wired into the workflows. **This is a CRITICAL bug — the Terraform workflows are non-functional.**
- **terraform-deploy.yml doesn't declare secrets explicitly.** Uses `${{ secrets.* }}` directly in the workflow-level `env:` block, while ansible-deploy.yml and webapp-deploy.yml properly declare `secrets:` in their `workflow_call` definition. Should be consistent — explicit declarations serve as documentation and enable validation.
- **Display names inconsistent.** "Terraform Deploy" vs. "Deploy Web Application" vs. "Deploy All". Minor, but use a consistent pattern: either `{Component} Deploy` or `Deploy {Component}`.

---

## Production Readiness

**Grade: B-**

**Strengths:**

- Concurrency control on deploy-all prevents double-deploys.
- `cancel-in-progress: false` — correct, never cancel a running deployment.
- Terraform plan artifacts uploaded for audit trail (7-day retention).
- Terraform apply uses saved plan file — no drift between plan and apply.
- Ansible output captured and uploaded (30-day retention) for debugging.

**Issues:**

- **drift-detection.yml uses `environment: prod` but checks dev directory.** Two compounding problems:
  1. `environment: prod` triggers the 2-reviewer approval gate on every scheduled run. Nightly drift detection will sit in "waiting for review" indefinitely. Non-starter.
  2. The OIDC token subject claim will be `repo:org/kafka-lab:environment:prod`, but the federated credential documented for drift detection uses `repo:org/kafka-lab:ref:refs/heads/main`. Claim mismatch → `AADSTS70021` authentication failure.
- **webapp-deploy.yml `function_app_name` default is broken.** The default `klc-func-kafkalab-${{ inputs.environment }}-scus` uses `${{ inputs.environment }}` in an input default definition, where other input contexts are not available. Resolves to `klc-func-kafkalab--scus` (empty environment). deploy-all.yml doesn't pass this input explicitly, so it hits the broken default.
- **webapp-deploy.yml copies gitignored `local.settings.json`.** The file is in `.gitignore` and not tracked in git. In CI (clean checkout), `cp local.settings.json deploy-package/` fails because the file doesn't exist. Deployment broken on first run.
- **No health check after webapp deployment.** The workflow deploys but never verifies the app is responding. A simple `az functionapp show --query state` or HTTP probe would catch deployment failures.
- **No path filters on pr-validation.yml.** Every PR to main triggers Azure login and terraform plan, even for docs-only changes. Wastes CI minutes and creates unnecessary OIDC token exchanges.

---

## Cross-Cutting Consistency

**Grade: B+**

**Strengths:**

- Action versions consistent across all 6 workflows: `checkout@v4`, `setup-terraform@v3`, `cache@v4`, `upload-artifact@v4`, `download-artifact@v4`, `azure/login@v2`, `github-script@v7`, `setup-node@v4`.
- OIDC env var pattern (`ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`, `ARM_USE_OIDC`, `ARM_USE_AZUREAD`) consistent across terraform-deploy.yml, drift-detection.yml, and pr-validation.yml.
- Backend config key pattern `kafka-lab/{env}.tfstate` used consistently.
- Terraform cache key uses `.terraform.lock.hcl` hash — correct, invalidates when providers change.

**Issues:**

- **terraform-deploy.yml uses implicit secrets; ansible/webapp use explicit.** Different approaches to secret passing in reusable workflows. Not broken, but inconsistent.
- **Artifact retention varies:** terraform plan 7 days, ansible output 30 days, webapp package 5 days. Should have a documented rationale or use a consistent default.

---

## SP7 Readiness (Multi-Region)

**Grade: C+**

SP7 adds mexicocentral and canadaeast. Current state:

**What works:**

- deploy-all.yml parameterizes `working_directory: terraform/environments/${{ inputs.environment }}` — supports separate environment directories.
- terraform-deploy.yml accepts arbitrary `working_directory` — can point at per-region directories.
- Ansible uses dynamic Azure RM inventory — should discover VMs in new regions automatically.

**What blocks SP7:**

- **No region parameter.** None of the workflows accept a region input. The naming convention hardcodes `scus` (southcentralus): `klc-rg-kafkalab-${{ inputs.environment }}-scus`, `klc-kv-kafkalab-scus`, `klc-func-kafkalab-${{ inputs.environment }}-scus`. Multi-region requires either a `region` input or a matrix strategy.
- **No matrix strategy in deploy-all.yml.** Today it deploys one environment. SP7 needs to deploy one environment across 3 regions (or at minimum primary + secondary).
- **drift-detection.yml is single-environment, single-directory.** Needs a matrix over environments × regions.
- **Ansible self-hosted runner labels assume single region.** `[self-hosted, linux, azure, ansible]` — may need region-specific labels if runners are region-local.
- **terraform-deploy.yml defaults `working_directory` to `terraform/environments/dev`.** Harmless when callers always pass it explicitly, but the default is misleading.

**SP7 recommendation:** Add `region` as an input to all reusable workflows. In deploy-all.yml, either add a matrix strategy or accept comma-separated regions and fan-out. The architecture is extensible — no fundamental redesign needed, just parameterization.

---

## Sid's Warnings Assessment

### 1. webapp-deploy.yml default input cross-referencing another input

**Assessment: CONFIRMED BUG — Severity HIGH**

`${{ inputs.environment }}` in a `workflow_call` input `default` does not resolve. The default evaluates to `klc-func-kafkalab--scus`. Since deploy-all.yml doesn't pass `function_app_name` explicitly, every webapp deployment through the orchestrator hits this broken default. **Required fix.**

### 2. drift-detection using environment:prod but checking dev directory

**Assessment: CONFIRMED BUG — Severity CRITICAL**

Two failures compound: (a) `environment: prod` triggers mandatory 2-reviewer approval on every scheduled run, blocking nightly automation; (b) OIDC subject claim mismatch against the federated credential configured for `ref:refs/heads/main`. **Required fix.**

### 3. drift-detection needs matrix for multi-env

**Assessment: AGREE — Severity MEDIUM (SP7 scope)**

Correct observation. For SP6 with only dev environment, single-directory is acceptable. Must be a matrix when prod directory is created. Track as SP7 requirement.

### 4. terraform.prod.tfvars in dev directory

**Assessment: AGREE — Severity LOW**

The file is a forward placeholder. Since `terraform/environments/prod/` doesn't exist yet, having it in `dev/` is tolerable. Relocate when the prod directory is created in SP7. **Non-blocking.**

---

## Required Changes

These must be addressed before the workflows are considered production-ready:

1. **Wire tfvars files into Terraform commands.** Add `-var-file=terraform.${{ inputs.environment }}.tfvars` to all `terraform plan` invocations in terraform-deploy.yml, drift-detection.yml, and pr-validation.yml. Add `-var="subscription_id=${{ secrets.AZURE_SUBSCRIPTION_ID }}"` and `-var="ssh_public_key=${{ secrets.SSH_PUBLIC_KEY }}"` (or equivalent TF_VAR_ env vars) for required variables without defaults. Without this, **every Terraform workflow fails at runtime.**

2. **Fix drift-detection.yml environment.** Remove `environment: prod` and either (a) use `environment: dev` (since it checks the dev directory anyway), or (b) remove the `environment:` key entirely and add a federated credential for `ref:refs/heads/main` (as documented in github-environments.md). Option (a) is simpler for SP6.

3. **Fix webapp-deploy.yml function_app_name default.** Either make `function_app_name` required (`required: true`) and pass it explicitly from deploy-all.yml, or use a static default like `klc-func-kafkalab-dev-scus` with override from callers. Do not cross-reference `inputs.environment` in the default.

4. **Fix webapp-deploy.yml local.settings.json copy.** The file is gitignored and won't exist in CI. Either make the copy conditional (`if [ -f local.settings.json ]; then cp ...`), generate a minimal version during the build step, or remove it entirely (Azure Functions in production reads settings from App Service configuration, not this file).

---

## Recommended Improvements (Non-Blocking)

Address in SP7 or as cleanup:

1. **Pin actions by SHA.** Replace `@v4` tags with `@{sha} # v4.x.x` for all third-party actions. Start with `actions/checkout`, `azure/login`, `hashicorp/setup-terraform`.
2. **Add path filters to pr-validation.yml.** Run terraform validation only when `terraform/**` changes. Run webapp build only when `webapp/**` changes. Run ansible check only when `ansible/**` changes.
3. **Parameterize Ansible Key Vault name.** Add a `keyvault_name` input to ansible-deploy.yml instead of hardcoding `klc-kv-kafkalab-scus`.
4. **Add region input to reusable workflows.** Prepare for SP7 multi-region by adding `region` parameter to terraform-deploy.yml, ansible-deploy.yml, and webapp-deploy.yml.
5. **Add post-deploy health check** to webapp-deploy.yml — verify Function App state after deployment.
6. **Standardize artifact retention** across workflows (7 days for ephemeral build artifacts, 30 days for audit-relevant logs).
7. **Standardize workflow display names** to a consistent pattern (`Terraform Deploy`, `Ansible Deploy`, `Webapp Deploy`, `Deploy All`).
8. **Add explicit `secrets:` declaration to terraform-deploy.yml** for consistency with the other reusable workflows.

---

## Decision

**APPROVE WITH CONDITIONS.** The CI/CD pipeline architecture is well-designed — reusable workflows, OIDC auth, environment gating, concurrency controls, and clean separation of concerns. The structural decisions are right.

However, there are 4 wiring bugs that prevent the workflows from functioning at runtime, most critically the missing `-var-file`/`-var` flags on Terraform commands (every TF workflow fails) and the drift detection environment/OIDC mismatch (nightly runs blocked). These are straightforward fixes that don't require rearchitecting anything.

**Required:** All 4 items in the Required Changes section must be fixed. Per lockout rules, the fixes should NOT be done by the original author — assign to a different implementor. No re-review needed if fixes are limited to the 4 listed items; Sid can verify.

---

## Decision: Inject SP7 — Dev Environment Deployment & Integration Testing

**Author:** Zorg  
**Date:** 2026-03-31  
**Status:** Accepted  

### Context

SP0–SP6 are complete (foundation through CI/CD). The original roadmap went straight from CI/CD (SP6) to multi-region expansion (SP7). The user identified a gap: we should deploy and validate the single-region dev environment before adding multi-region complexity. This is sound engineering — prove it works in dev, then scale.

### Decision

Inject a new SP7 between the existing sprints. Rename the former SP7 (Multi-Region) to SP8, and the former SP8 (Resiliency) to SP9.

#### New Sprint Structure

| Sprint | Name | Status |
|--------|------|--------|
| SP0–SP6 | Foundation through CI/CD | Done |
| **SP7** | **Dev Environment Deployment & Integration Testing** | **New — To Do** |
| SP8 | Multi-Region Expansion (was SP7) | To Do |
| SP9 | Resiliency and Production Hardening (was SP8) | To Do |

#### SP7 Scope (10 stories)

1. **SP7.001** — Deploy Dev Environment to Azure (Terraform apply + Ansible provisioning)
2. **SP7.002** — Configure Playwright Test Framework
3. **SP7.003** — Configure Playwright MCP Integration (AI-assisted testing)
4. **SP7.004** — Write Smoke Tests for Web Application
5. **SP7.005** — Write Integration Tests for Kafka Dashboard
6. **SP7.006** — Write Integration Tests for Kafka Operations
7. **SP7.007** — Write Integration Tests for Schema Registry UI
8. **SP7.008** — End-to-End Environment Validation
9. **SP7.009** — CI/CD Pipeline for Integration Tests
10. **SP7.010** — Dev Environment Teardown & Cost Management

### Rationale

- Validates the full stack works before adding multi-region (reduces debugging surface)
- Playwright + Playwright MCP gives us automated and AI-assisted testing capabilities
- Integration tests against a live environment catch issues that unit tests miss
- Teardown/recreate scripts manage Azure costs during development
- Aligns with REQUIREMENTS.md: "start with a single region and single AZ for development"

### Impact

- All SP7 task titles and milestone references renamed to SP8
- All SP8 task titles and milestone references renamed to SP9
- Milestone files renamed accordingly
- team.md updated to reflect new sprint structure
- No code changes — this is a backlog restructuring only
- Internal task IDs (TASK-34, TASK-35) unchanged — only titles and milestones shifted

### Alternatives Considered

1. **Add testing to SP6 scope** — Rejected. SP6 is Done and focused on CI/CD pipeline, not environment deployment.
2. **Test in SP8 alongside multi-region** — Rejected. Testing multi-region without validating single-region first is reckless.
3. **Skip formal integration tests** — Rejected. Manual testing doesn't scale and won't survive team changes.

---

## Directive: Sprint Closeout Process

**Author:** simock (via Copilot)  
**Date:** 2026-03-31T17:40:04-04:00 (ET)  
**Status:** Captured  

### Content

At the end of every sprint, commit the code and create a git pull request. This ensures sprint work is packaged into a reviewable PR before moving on.

### Rationale

User request — maintains ceremony enforcement and ensures sprint completeness before moving to the next phase.
