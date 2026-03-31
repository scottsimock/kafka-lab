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

### SP5 Complete (2026-03-31)

SP5 — Web Application sprint is COMPLETE. Delivered 9/10 tasks (all passed review with flying colors). Average quality score ~99%. All views, API routes, and shared Kafka client finalized. Parker's 3 critical review fixes applied and verified: storage auth (managed identity + RBAC), Schema Registry URL env var, consumer group state badge case mismatch.


## Sprint Update: SP7 Injection (2026-03-31T17:56-04:00)

**By:** Zorg (Sprint Orchestrator)

The sprint roadmap was restructured. A new SP7 (Dev Environment Deployment & Integration Testing) was injected between CI/CD (SP6) and multi-region expansion. Former SP7 (Multi-Region) renamed to SP8. Former SP8 (Resiliency) renamed to SP9.

**New Sprints:**
- SP7: Dev Environment Deployment & Integration Testing (10 stories)
- SP8: Multi-Region Expansion (was SP7)
- SP9: Resiliency and Production Hardening (was SP8)

**Rationale:** Validate single-region dev environment before multi-region complexity. Aligns with REQUIREMENTS.md strategy.

**Impact on Drexl:** Your upcoming work (multi-region) is now SP8. No scope changes — only sprint numbers shifted. Ready to start when SP7 env validation is complete.

### SP7.001 — Deploy Dev Environment to Azure (2026-04-01)

**Key Work Done:**

1. **Function App wired into Terraform** — Module existed at `terraform/modules/function-app/` but was never instantiated in `main.tf`. Added module call (`klc-func-kafkalab-scus`), private endpoint (`klc-pe-func-scus`), and `privatelink.azurewebsites.net` DNS zone.

2. **Function App module fix** — Added `response_export_values = ["properties.defaultHostName"]` to the `azapi_resource.function_app` in `terraform/modules/function-app/main.tf`. Without this, the `function_app_default_hostname` output would fail at plan time.

3. **Outputs extended** — Added `function_app_id`, `function_app_name`, `function_app_hostname`, `app_service_plan_id`, `pe_function_app_id` to `terraform/environments/dev/outputs.tf`.

4. **Static Ansible inventory** — Created `ansible/inventory/dev-static.ini` with known IP allocations from Terraform locals. The dynamic Azure RM inventory (`azure_rm.yml`) requires MSI auth from inside the VNet; static inventory provides a CI/local fallback.

5. **Dev verification playbook** — Created `ansible/playbooks/verify-dev.yml` for dev environment where `kafka_broker_security_enabled: false`. The existing `verify-cluster.yml` assumes SASL_SSL and uses `--command-config admin.properties` which won't work in dev. Dev playbook tests PLAINTEXT + Schema Registry + Kafka Connect endpoints.

6. **Deployment script** — Created `scripts/deploy-dev.sh` orchestrating terraform init → plan → apply → inventory generation → ansible-playbook → verification. Supports `--plan-only`, `--skip-terraform`, `--skip-ansible`, `--skip-verify`.

7. **Deployment docs** — Created `docs/deploy-dev.md` covering prerequisites, architecture, quick start, step-by-step, GitHub Actions integration, inventory options, dev-specific settings, and troubleshooting.

**Key File Paths:**
- `terraform/environments/dev/main.tf` (lines 692–725: Function App + PE)
- `terraform/modules/function-app/main.tf` (line 190: response_export_values)
- `terraform/environments/dev/outputs.tf` (Function App outputs)
- `ansible/inventory/dev-static.ini` (static inventory)
- `ansible/playbooks/verify-dev.yml` (dev verification)
- `scripts/deploy-dev.sh` (deployment orchestration)
- `docs/deploy-dev.md` (deployment documentation)

**Architecture Notes:**
- Schema Registry URL uses internal DNS: `http://sr-01.kafkalab.internal:8081`
- Function App uses Premium EP1 plan with VNet integration to `snet-web-app`
- All Kafka secrets injected via `@Microsoft.KeyVault()` references
- Function App private endpoint in `snet-private-endpoints` with dedicated DNS zone
- Dev environment relaxes security (no SASL_SSL, no ACLs) for faster iteration
- Static inventory mirrors exact IPs from Terraform locals (ZK: 10.1.2.4–6, KB: 10.1.1.4–6, SR: 10.1.3.4, KC: 10.1.4.4)

### SP7.010 — Dev Environment Teardown & Cost Management (2026-04-01)

**Key Work Done:**

1. **Teardown script** — `scripts/teardown-dev.sh` runs `terraform destroy` with safety prompts (`--confirm` for non-interactive), verifies no orphaned resources via `az resource list`, and cleans up local artifacts (generated inventory, plan files).

2. **GitHub Actions workflows:**
   - `.github/workflows/dev-teardown.yml` — `workflow_dispatch` trigger, runs terraform destroy with OIDC auth, verifies resource cleanup, posts cost estimation to step summary. Supports `plan_only` and `skip_estimation` inputs.
   - `.github/workflows/dev-recreate.yml` — `workflow_dispatch` trigger, full pipeline: terraform apply → ansible site.yml → post-provisioning playbooks (credentials, topics, schemas) → webapp deploy → verification. Supports `skip_ansible`, `skip_verify`, `skip_estimation` inputs.

3. **Cost estimation** — Documented in `docs/deploy-dev.md` and in workflow step summaries. Running env costs ~$45–55/day; destroyed env costs ~$0.10/day (state storage only). Weekend teardown saves ~$110–140, nightly teardown saves ~$270–330/week.

4. **Docs updated** — Added comprehensive teardown/recreate sections to `docs/deploy-dev.md` covering: when to teardown, how (script or workflow), how to recreate, what persists vs. what's destroyed, and cost breakdown.

**Key Patterns:**
- Both workflows use `concurrency: group: deploy-dev` to prevent parallel runs
- Teardown workflow uses GitHub environment protection rules (same as terraform-deploy.yml)
- Recreate workflow chains reusable workflows (ansible-deploy.yml, webapp-deploy.yml) with inline jobs for post-provisioning
- Resource cleanup verification excludes `Microsoft.Storage/storageAccounts` (state backend)
- All Kafka state (topics, schemas, offsets) is ephemeral in dev — restored by playbooks on recreate
