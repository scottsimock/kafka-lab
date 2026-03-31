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

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
