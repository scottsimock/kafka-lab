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

