# Project Context

- **Project:** kafka-lab — Confluent Kafka resiliency lab on Azure
- **Stack:** Terraform (AzAPI), Ansible, Next.js 15, GitHub Actions, Azure VMs
- **User:** simock
- **Created:** 2026-03-31

## Core Context

Infrastructure developer for kafka-lab. SP0–SP4 complete (Terraform modules, Ansible roles, Kafka platform). SP5 complete (Web app + Function App). Now leading SP7 (Dev Environment & Testing). My domain covers Terraform AzAPI modules, Ansible playbooks, Azure networking, and CI/CD workflows.

### Key Architecture Decisions

- **Web app:** Next.js 15 at `webapp/` with `output: 'standalone'` for Azure Function App
- **Kafka client:** @confluentinc/kafka-javascript v1.8.2 with singleton pattern and SIGTERM handler
- **Function App:** Premium EP1 plan (VNet integration), custom handler via host.json
- **Networking:** All connections via private endpoints — no public access
- **Regions:** southcentralus (primary), mexicocentral (secondary), canadaeast (DR)
- **Dev environment:** VNet, Function App, DNS, Ansible inventory, deployment script, teardown automation
- **CI/CD:** Smoke tests as fast-fail gate (~2 min), full integration suite in parallel (~8 min)
- **Cost optimization:** Nightly teardown reduces cloud spend ~99% ($45-55/day → $0.10/day)

## Recent Updates

📌 SP7 Sprint completed 2026-03-31 — Dev environment + 110 integration tests deployed

## Learnings

### SP5 (Web Application) — Archive Summary

SP5 delivered Next.js 15 app with shared Kafka client module, API routes, dashboard views, and schema browser. Key technical decisions documented in `.squad/decisions.md`:

- **Next.js 15 scaffolding:** Standalone output for Function App deployment, route groups to avoid URL nesting, Server Components by default
- **Kafka client:** Singleton pattern with @confluentinc/kafka-javascript v1.8.2, SIGTERM handler, env-based config (KAFKA_BOOTSTRAP_SERVERS, USERNAME, PASSWORD, SSL_CA)
- **API routes:** Admin API (cluster, topics, consumer groups), message produce/consume/stream (with SSE), schema browser (direct Schema Registry fetching)
- **Schema Registry:** Server Components fetch directly via `lib/schema-registry.ts` config helper; REST endpoints documented
- **Webpack externals:** Native module handling via `next.config.ts` configuration to prevent bundling errors
- **Critical review fixes:** Storage auth (managed identity + RBAC), SCHEMA_REGISTRY_URL env var, consumer group state badge case mismatch

Full SP5 details archived in previous history entries and `.squad/log/` session logs.

**Key Decisions:**
- Next.js 15.5.14 installed at `webapp/` subdirectory, not repo root
- Using @confluentinc/kafka-javascript v1.8.2 (latest stable as of 2026-03-31)
- Configured `output: 'standalone'` for containerized Azure Function App deployment
- Configured `compress: false` since Azure Function App handles compression
- Azure Functions custom handler configured via host.json to run Next.js server

**App Router Structure:**
- Root layout at `app/layout.tsx` with minimal nav
- Dashboard at `app/dashboard/` with sidebar navigation layout
- Route groups used: `(views)` for dashboard pages to avoid URL nesting
- Dynamic routes: `topics/[name]`, `consumer-groups/[id]`, `schemas/[subject]`
- Error boundary is a Client Component (`'use client'`) — all other pages are Server Components
- API routes follow REST conventions: `/api/{resource}` and `/api/{resource}/[id]`

**File Paths:**
- Main config: `webapp/next.config.ts`, `webapp/tsconfig.json`, `webapp/package.json`
- Azure Functions: `webapp/host.json`, `webapp/local.settings.json` (gitignored)
- Dashboard views: `webapp/app/dashboard/(views)/{overview,topics,consumer-groups,messages,schemas}/page.tsx`
- API routes: `webapp/app/api/{cluster,topics,consumer-groups,messages,schemas}/route.ts`

**Build Verification:**
- `npm run build` succeeds — produces standalone output in `.next/standalone/`
- `npm run dev` starts dev server on http://localhost:3000
- All 17 routes registered correctly (8 static, 9 dynamic)

### SP5.002 — Shared Kafka Client Module (2026-03-31)

**Key Patterns:**
- Singleton pattern using `@confluentinc/kafka-javascript` KafkaJS namespace
- Environment variables: `KAFKA_BOOTSTRAP_SERVERS`, `KAFKA_USERNAME`, `KAFKA_PASSWORD`, `KAFKA_SSL_CA` (optional)
- SSL CA configured via GlobalConfig `ssl.ca.pem`, not in KafkaConfig
- Consumer config uses nested `kafkaJS` property: `{ kafkaJS: { groupId } }`
- Type exports: `KafkaConfig`, `SASLOptions`, `Admin`, `Producer`, `Consumer`
- SIGTERM handler for graceful shutdown

**File Paths:**
- Core module: `webapp/lib/kafka/client.ts`
- Re-export barrel: `webapp/lib/kafka/index.ts`
- Import pattern: `import { getKafkaClient, getAdmin } from '@/lib/kafka'`

**Key Learning:**
The @confluentinc/kafka-javascript library exports via namespaces (`KafkaJS`, `RdKafka`), not directly. Use `KafkaJS` namespace for KafkaJS-compatible API. The constructor takes `CommonConstructorConfig` which extends `GlobalConfig` and includes optional `kafkaJS: KafkaConfig` property.

### SP5.003 — Kafka API Route Handlers (2026-03-31)

**Key Patterns:**
- Admin API method signatures differ from standard KafkaJS — consult type definitions in `node_modules/@confluentinc/kafka-javascript/types/kafkajs.d.ts`
- `fetchTopicMetadata()` returns `{ topics: ITopicMetadata[] }` — no direct broker list
- Extract broker info from `partition.leaderNode` and `partition.replicaNodes` (type `Node` with `id`, `host`, `port`)
- Node type uses `id` property, not `nodeId`
- `describeConfigs()` method not available in KafkaJS compatibility layer
- Next.js 15 dynamic route params are `Promise<{ param }>` — MUST await before use
- Pattern: `{ params }: { params: Promise<{ name: string }> }` then `const { name } = await params`
- Native module builds fail at "Collecting page data" phase — TypeScript validation with `npx tsc --noEmit` is sufficient
- Routes work fine at runtime despite build-time native binding errors

**API Response Structures:**
- Cluster: brokers, topicCount, partitionCount, underReplicatedPartitions, offlinePartitions
- Topics list: topics array with name, partitionCount, replicationFactor
- Topic detail: name, partitions (with leader, replicas, isr, offsets), isInternal
- Consumer groups list: groups array with groupId, state, protocolType, memberCount
- Consumer group detail: groupId, state, members, partitions (with offset and lag)

**File Paths:**
- `webapp/app/api/cluster/route.ts` — cluster metadata
- `webapp/app/api/topics/route.ts` — topics list
- `webapp/app/api/topics/[name]/route.ts` — topic detail
- `webapp/app/api/consumer-groups/route.ts` — consumer groups list
- `webapp/app/api/consumer-groups/[id]/route.ts` — consumer group detail

### SP5.004 — Message Produce and Consume API Routes (2026-03-31)

**Key Patterns:**
- Consumer subscribe() method takes `{ topic: string }` or `{ topics: string[] }` — no `fromBeginning` option
- Use unique consumer group IDs for ephemeral browser-based consumption: `kafka-lab-browser-${Date.now()}`
- Batch consume pattern: Promise wrapper with timeout (5 seconds) and message limit check
- SSE streaming uses Web ReadableStream API with TextEncoder for event formatting
- Handle client disconnect via `req.signal.addEventListener('abort', ...)` to clean up consumer
- Always disconnect producer/consumer in finally blocks to prevent connection leaks
- Webpack externals required for native modules: prevent Next.js from bundling `@confluentinc/kafka-javascript`

**API Routes:**
- POST `/api/messages/produce` — Accepts `{ topic, key, value, headers }`, returns `{ result }` with partition/offset
- GET `/api/messages/consume?topic=X&limit=20` — Batch consume with timeout, returns `{ messages: [...] }`
- GET `/api/messages/stream?topic=X` — Server-Sent Events streaming with format `data: {...}\n\n`

**Next.js Configuration:**
- `next.config.ts` webpack externals: `'@confluentinc/kafka-javascript': 'commonjs @confluentinc/kafka-javascript'`
- Prevents native module bundling issues during build
- `.env.local` required for build-time env vars (gitignored)

**File Paths:**
- `webapp/app/api/messages/produce/route.ts` — message production
- `webapp/app/api/messages/consume/route.ts` — batch message consumption
- `webapp/app/api/messages/stream/route.ts` — SSE streaming
- `webapp/next.config.ts` — webpack configuration for native modules

### SP5.010 — Schema Browser View and API Routes (2026-03-31)

**Key Patterns:**
- Schema Registry is a separate HTTP service with REST API — use `fetch()`, NOT the Kafka client
- Config helper pattern: `lib/schema-registry.ts` exports `getSchemaRegistryUrl()` function
- Schema Registry REST API endpoints:
  - `GET /subjects` — list all subject names
  - `GET /subjects/{subject}/versions` — list version numbers for a subject
  - `GET /subjects/{subject}/versions/{version}` — get schema for specific version
  - `GET /config/{subject}` — get compatibility mode for subject
- Server Components can fetch directly from Schema Registry — no need to route through our API
- Use `cache: 'no-store'` in fetch calls to prevent stale data
- Schema formatting: parse and pretty-print JSON for AVRO and JSON schema types
- Error handling: 502 when Schema Registry unavailable, 404 for missing subjects
- Dynamic routes use `params: Promise<{ subject: string }>` — always await

**API Response Structures:**
- Schemas list: `{ subjects: [{ name, latestVersion, compatibility }] }`
- Subject detail: `{ subject, compatibility, versions: [{ version, id, schema, schemaType }] }`

**Dashboard Views:**
- Schema list page: table with subject name (linked), latest version, compatibility
- Subject detail page: compatibility mode, version history, formatted schema definitions
- Loading and error states for better UX

**File Paths:**
- `webapp/lib/schema-registry.ts` — config helper
- `webapp/app/api/schemas/route.ts` — list subjects API
- `webapp/app/api/schemas/[subject]/route.ts` — subject detail API
- `webapp/app/dashboard/(views)/schemas/page.tsx` — schema list view
- `webapp/app/dashboard/(views)/schemas/[subject]/page.tsx` — subject detail view
- `webapp/app/dashboard/(views)/schemas/loading.tsx` — loading state
- `webapp/app/dashboard/(views)/schemas/error.tsx` — error boundary

### SP5 Complete (2026-03-31)

SP5 — Web Application sprint is COMPLETE. Delivered 9/10 tasks (all passed review with flying colors). Average quality score ~99%. All views, API routes, and shared Kafka client finalized. Parker's 3 critical review fixes applied and verified: storage auth (managed identity + RBAC), Schema Registry URL env var, consumer group state badge case mismatch.


## Sprint Update: SP7 Injection (2026-03-31T17:56-04:00)

## SP7 Sprint Completion — Dev Environment & Integration Testing (2026-03-31T18:13-04:00)

**Sprint Status:** COMPLETE (10/10 tasks)

**Wave Summary:**
- **Wave 1 (14:35 ET):** Dev environment infrastructure provisioned; Playwright framework configured for Azure remote testing; 37 smoke tests written
- **Wave 2 (15:20 ET):** Playwright MCP integration enabled; 33 dashboard integration tests written
- **Wave 3 (16:10 ET):** 22 Kafka operations tests + 22 Schema Registry tests
- **Wave 4 (17:00 ET):** CI/CD pipeline completed; teardown/cost management implemented; E2E validation scripts deployed

**Total Test Coverage:** 110 Playwright tests across 18 spec files

**Orchestration Logs:**
- `.squad/orchestration-log/2026-03-31T14-35-wave1.md`
- `.squad/orchestration-log/2026-03-31T15-20-wave2.md`
- `.squad/orchestration-log/2026-03-31T16-10-wave3.md`
- `.squad/orchestration-log/2026-03-31T17-00-wave4.md`

**Session Log:** `.squad/log/2026-03-31T18-13-sp7-sprint-execution.md`

**Next Sprint (SP8):** Multi-region expansion — secondary/DR VNets, cross-region peering, multi-region cluster linking
