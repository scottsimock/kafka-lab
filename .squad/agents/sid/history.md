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
## SP7 Sprint Completion — Dev Environment & Integration Testing (2026-03-31T18:13-04:00)

**Sprint Status:** COMPLETE (10/10 tasks)

**Tasks Completed:**
- **SP7.004 (Wave 1):** 37 smoke tests (pages, nav, API, errors) — 4 spec files
- **SP7.005 (Wave 2):** 33 dashboard integration tests (topics, consumers, metrics, filters, refresh) — 5 spec files
- **SP7.006 (Wave 3):** 22 Kafka operations tests (CRUD, messaging, round-trips) — 4 spec files
- **SP7.007 (Wave 3):** 22 Schema Registry integration tests (listing, detail, compatibility, errors) — 4 spec files
- **SP7.008 (Wave 4):** E2E environment validation (bash + Ansible, JSON reports) — validation script + playbook

**Test Coverage Summary:**
- Smoke Tests: 37 (page loads, nav, health checks, error handling)
- Dashboard Tests: 33 (topic management, consumer monitoring, metrics, filtering)
- Operations Tests: 22 (topic CRUD, producer/consumer flows, message round-trips)
- Schema Registry Tests: 22 (subject listing, versions, compatibility modes, error cases)
- **Total:** 110 Playwright tests across 18 spec files

**Deliverables:**
- `webapp/e2e/pages.spec.ts` — 12 smoke tests
- `webapp/e2e/nav.spec.ts` — 8 smoke tests
- `webapp/e2e/api.spec.ts` — 10 smoke tests
- `webapp/e2e/errors.spec.ts` — 7 smoke tests
- `webapp/e2e/dashboard-topics.spec.ts` — 7 tests
- `webapp/e2e/dashboard-consumers.spec.ts` — 8 tests
- `webapp/e2e/dashboard-metrics.spec.ts` — 9 tests
- `webapp/e2e/dashboard-filters.spec.ts` — 6 tests
- `webapp/e2e/dashboard-refresh.spec.ts` — 3 tests
- `webapp/e2e/kafka-topics.spec.ts` — 6 tests
- `webapp/e2e/kafka-producers.spec.ts` — 7 tests
- `webapp/e2e/kafka-consumers.spec.ts` — 5 tests
- `webapp/e2e/kafka-roundtrip.spec.ts` — 4 tests
- `webapp/e2e/schema-registry-list.spec.ts` — 5 tests
- `webapp/e2e/schema-registry-detail.spec.ts` — 6 tests
- `webapp/e2e/schema-registry-compat.spec.ts` — 7 tests
- `webapp/e2e/schema-registry-errors.spec.ts` — 4 tests
- `scripts/validate-dev-environment.sh` — bash validation script (20+ checks)
- `ansible/playbooks/validate-e2e.yml` — Ansible E2E validation playbook
- `docs/e2e-validation.md` — validation documentation

**Test Patterns:**
- Smoke tests provide fast-fail gate (~2 min) in CI/CD pipeline
- Integration tests run in parallel after smoke gate (~8 min)
- All tests validate against dev environment with PLAINTEXT Kafka (no SASL_SSL)
- E2E validation checks infrastructure health (VNet, DNS, Function App, Kafka connectivity)

**Next Steps (SP8):** Multi-region testing — cross-region failover, cluster linking validation, disaster recovery scenarios
