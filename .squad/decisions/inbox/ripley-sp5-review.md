# SP5 — Web Application Sprint Review

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
