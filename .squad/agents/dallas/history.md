# Project Context

- **Project:** kafka-lab — Confluent Kafka resiliency lab on Azure
- **Stack:** Terraform (AzAPI), Ansible, Next.js 15, GitHub Actions, Azure VMs
- **User:** simock
- **Created:** 2026-03-31

## Core Context

Frontend and full-stack developer for kafka-lab. SP0–SP4 complete (infrastructure and Kafka platform). My domain is the web application and Azure Functions.

### Upcoming Work (SP5)

- Next.js 15 project scaffolding with App Router
- Shared Kafka client module (confluent-kafka)
- Kafka API route handlers (topics, partitions, brokers, consumer groups)
- Message produce and consume API routes
- Dashboard views: cluster overview, topic detail, consumer groups, message browser
- Schema browser view and API routes
- Azure Function App infrastructure (Terraform + Python functions)

### Architecture Notes

- Web app runs in same regions and AZs as Kafka clusters
- All connections via private endpoints — no public access
- southcentralus (primary), mexicocentral (secondary), canadaeast (DR)
- Must be easy to use — one-click topic creation, message reading from any topic

## Recent Updates

📌 Team initialized on 2026-03-31

## Learnings

Initial setup complete. Replacing Ruby sprint orchestrator with Squad workflow.

### SP5.001 — Next.js 15 Project Scaffolding (2026-03-31)

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

