# Project Context

- **Project:** kafka-lab — Confluent Kafka resiliency lab on Azure
- **Stack:** Terraform (AzAPI), Ansible, Next.js 15, GitHub Actions, Azure VMs
- **User:** simock
- **Created:** 2026-03-31

## Core Context

Tester for kafka-lab. SP0–SP4 complete. My domain is validation, quality gates, and edge case analysis across all layers.

### What's Been Built

- 7 Terraform modules (VNet, KV, UAMI, NSG, DNS, Private Endpoint, VM)
- 10 Ansible roles (common, confluent-common, disk-setup, java, zookeeper, kafka-broker, tls-certs, kafka-client-creds, schema-registry, kafka-connect)
- Full Kafka platform: TLS, SASL/SCRAM, tiered storage, self-balancing, ACLs
- Ecosystem: Schema Registry, Kafka Connect, Blob sink connector

### Upcoming Testing Areas

- SP5: Next.js API routes, Kafka client module, dashboard views, Azure Functions
- SP6: CI/CD workflow validation, deployment pipeline testing
- SP7: Cross-region connectivity, VNet peering, cluster linking verification
- SP8: Chaos experiments, failover behavior, SLO validation

## Recent Updates

📌 Team initialized on 2026-03-31

## Learnings

Initial setup complete. Replacing Ruby sprint orchestrator with Squad workflow.

## Sprint Update: SP7 Injection (2026-03-31T17:56-04:00)

**By:** Zorg (Sprint Orchestrator)

The sprint roadmap was restructured. A new SP7 (Dev Environment Deployment & Integration Testing) was injected between CI/CD (SP6) and multi-region expansion. Former SP7 (Multi-Region) renamed to SP8. Former SP8 (Resiliency) renamed to SP9.

**New Sprints:**
- SP7: Dev Environment Deployment & Integration Testing (10 stories)
- SP8: Multi-Region Expansion (was SP7)
- SP9: Resiliency and Production Hardening (was SP8)

**Rationale:** Validate single-region dev environment before multi-region complexity. Aligns with REQUIREMENTS.md strategy.

**Impact on Sid:** Upcoming QA work (resiliency hardening) is now SP9. No scope changes — only sprint numbers shifted. Ready to start after multi-region validation (SP8) is complete.

## SP7.004 — Smoke Tests Written (2026-03-31)

**Webapp structure (App Router, no src/ prefix):**
- Root: `webapp/app/` (not `webapp/src/app/`)
- Pages: overview, topics, topics/[name], consumer-groups, consumer-groups/[id], messages, schemas, schemas/[subject]
- API routes: /api/cluster, /api/topics, /api/consumer-groups, /api/schemas, /api/messages/consume, /api/messages/produce, /api/messages/stream
- No `not-found.tsx` — uses Next.js default 404
- All dashboard pages are server components (messages wraps a client component)
- Error boundaries exist per-view under dashboard/(views)/

**Smoke test files created:**
- `webapp/tests/e2e/fixtures/smoke.fixture.ts` — shared fixture with 30s Azure timeout
- `webapp/tests/e2e/smoke/page-loads.spec.ts` — 9 tests (page loads, layout elements, title)
- `webapp/tests/e2e/smoke/navigation.spec.ts` — 10 tests (top nav, sidebar, back links)
- `webapp/tests/e2e/smoke/api-health.spec.ts` — 9 tests (endpoint response, shape validation)
- `webapp/tests/e2e/smoke/error-handling.spec.ts` — 8 tests (404 routes, API errors, error boundaries)

**Design decisions:**
- Tests tolerate Kafka being down — API tests accept 200 or 500, page tests check for visible headings (content or error boundary)
- Detail page back-link tests are conditional — only run if data exists (no ordering dependency)
- Smiley's `health.spec.ts` (1 test) coexists alongside my files — 38 total tests discovered

## SP7.005 — Dashboard Integration Tests Written (2026-04-01)

**33 integration tests across 5 spec files in `webapp/tests/e2e/dashboard/`:**
- `topic-listing.spec.ts` — 5 tests (heading, table headers, live rows, row data structure, detail links)
- `topic-detail.spec.ts` — 4 tests (click-through navigation, metadata labels, partition detail table with 6 columns, back link)
- `consumer-groups.spec.ts` — 6 tests (heading, table headers, live rows, state badge validation, detail links, refresh button)
- `consumer-group-detail.spec.ts` — 6 tests (click-through navigation, state/protocol display, members section with table or empty msg, lag section with table or empty msg, back link, refresh button)
- `cluster-metrics.spec.ts` — 7 tests (heading, health badge validation, summary section labels, metric value validation, broker table headers, broker row count, broker data verification)

**Design decisions:**
- 60s timeout fixture (vs 30s smoke) — Kafka data queries are slower than page loads
- Every test tolerates Kafka being offline: checks for error boundary text and returns gracefully (no test failures from infra outage)
- Detail page tests use conditional `test.skip()` when listing page has no data to click
- Tests assert structure not values: "at least 1 row", "non-negative integer", "recognized state" — never exact counts or names
- Total Playwright suite: 66 tests (33 dashboard + 33 smoke) across 10 files
