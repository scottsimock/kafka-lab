---
id: TASK-27.6
title: SP0.001 — Confluent Kafka Platform Overview
status: Done
assignee:
  - tester-10
created_date: '2026-03-30 15:20'
updated_date: '2026-03-30 16:03'
labels:
  - research
milestone: m-0
dependencies: []
references:
  - 'https://docs.confluent.io/platform/current/platform.html'
  - 'https://docs.confluent.io/kafka/introduction.html'
parent_task_id: TASK-27
priority: high
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Objective:** Research Confluent Platform 7.8.x architecture, components, and configuration to establish foundational knowledge for the kafka-lab project. This research informs broker deployment, replication strategy, tiered storage setup with Azure Blob, and self-balancing cluster configuration across the project's multi-region Azure environment (southcentralus, mexicocentral, canadaeast).\n\n**Sources:**\n- https://docs.confluent.io/platform/current/platform.html\n- https://docs.confluent.io/kafka/introduction.html\n- https://docs.confluent.io/platform/current/kafka/tiered-storage.html\n- https://docs.confluent.io/platform/current/kafka/sbc/index.html\n- Confluent Platform 7.8.x release notes\n\n**Output:** A backlog document created via `backlog-document_create` containing:\n- Executive summary of Confluent Platform 7.8.x capabilities\n- Broker configuration deep-dive (server.properties, JVM settings, log dirs)\n- ZooKeeper ensemble setup (3-node, observer patterns)\n- Replication and partitioning strategies (min.insync.replicas, rack awareness)\n- Tiered storage configuration with Azure Blob Storage (remote storage manager, segment lifecycle)\n- Self-balancing cluster configuration and constraints\n- Example configuration files for dev environment (3 brokers D4s_v5, 3 ZK D2s_v5)\n- References with URLs\n\n**Scope:**\n- Include: Core platform architecture, broker config, ZK setup, replication, tiered storage (Azure Blob), self-balancing\n- Exclude: Schema Registry (SP0.002), Kafka Connect (SP0.003), Cluster Linking (SP0.004), security/auth (SP0.005)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Document covers broker configuration (server.properties, JVM settings, log directories)
- [x] #2 Document covers ZooKeeper ensemble setup for 3-node cluster
- [x] #3 Document covers replication strategy (min.insync.replicas, rack awareness, partition assignment)
- [x] #4 Document covers tiered storage configuration with Azure Blob Storage (private endpoint + CMEK)
- [x] #5 Document covers self-balancing cluster configuration and constraints
- [x] #6 Document includes example config files suitable for dev environment sizing
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Coder] 2026-03-30T15:41:00Z
- Completed research for SP0.001 — Confluent Kafka Platform Overview
- Created backlog document: doc-8
- Sources consulted:
  - https://docs.confluent.io/platform/current/kafka/tiered-storage.html (Azure Block Blob config, segment lifecycle)
  - https://docs.confluent.io/platform/current/kafka/sbc/index.html (Self-Balancing Clusters)
  - https://docs.confluent.io/platform/7.9/kafka-metadata/zk-production.html (ZooKeeper 3-node ensemble config)
  - https://docs.confluent.io/platform/current/kafka/post-deployment.html (broker best practices)
  - https://support.confluent.io/hc/en-us/articles/33032768211220 (CP 7.8 release notes)
  - https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dsv5-series (D4s_v5 and D2s_v5 specs)
  - https://docs.confluent.io/platform/current/installation/configuration/broker-configs.html (broker config reference)
- Score self-assessment: Addressed all 6 AC items
  - AC1: Broker configuration (server.properties, JVM settings, log directories) ✓
  - AC2: ZooKeeper ensemble setup for 3-node cluster with observer pattern ✓
  - AC3: Replication strategy (min.insync.replicas=2, broker.rack, Azure AZ mapping) ✓
  - AC4: Tiered storage with Azure Blob (AzureBlockBlob backend, UAMI/CMEK, private endpoint) ✓
  - AC5: Self-balancing cluster (confluent.balancer.enable, triggers, constraints, throttle) ✓
  - AC6: Example configs for dev (3x D4s_v5 brokers, 3x D2s_v5 ZK nodes) ✓

## [Tester] 2026-03-30T15:45:32Z
- FAIL — Score: 89.15%
- Accuracy: 82/100 — UAMI credential file format is incorrect: the JSON shown uses `azureClientId` + `azureTenantId` + `azureClientSecret`, which is the **service principal** format, not UAMI. A broker VM with a UAMI attached authenticates via Azure IMDS automatically — no client secret is required. Additionally, `confluent.tier.local.hotset.ms` is described as "default 24h" but the actual default inherits from `retention.ms` (7 days); 24h is a recommendation, not the default.
- Completeness: 93/100 — All 6 AC items covered. Gap: document explicitly recommends KRaft for all new kafka-lab deployments but provides zero KRaft configuration examples.
- Sources: 88/100 — 17 references with URLs present. Most Confluent doc URLs use `/current/` rather than version-pinned `/7.8/` paths, reducing version-specific authority. One reference links to a CP 7.9 ZooKeeper doc (`platform/7.9/kafka-metadata/zk-production.html`) inside a 7.8.x-scoped research document, which is inconsistent.
- Documentation Quality: 96/100 — Executive summary, clear heading hierarchy, ASCII lifecycle diagram, sizing tables, deprecation notices — all present and well-executed.
- Actionability: 93/100 — VM-specific heap sizes, private IPs, Azure role names, dev vs. production throttle values all provided. UAMI credential inaccuracy reduces usability of the tiered storage section.
- Required improvements:
  1. Fix the UAMI credential file format: for a broker VM with UAMI attached, authentication via Azure IMDS needs no client secret. Show the correct UAMI approach (optionally `azureClientId` to disambiguate multiple UAMIs, no `azureClientSecret`). Clearly separate this from the service principal approach (which does require a secret) and label each variant accurately.
  2. Correct the `confluent.tier.local.hotset.ms` default description: the default is `retention.ms` (7 days), not 24h. Reword to make clear 86400000ms is a recommended value, not the default.
  3. Add a KRaft example configuration for Broker 1 (controller + broker combined mode) since the document recommends KRaft for all new kafka-lab clusters. Minimally show the KRaft-specific properties: `process.roles`, `node.id`, `controller.quorum.voters`, `controller.listener.names`.
  4. Replace Confluent doc URLs that use `/current/` with version-pinned `/7.8/` equivalents where available (e.g., `https://docs.confluent.io/platform/7.8/kafka/tiered-storage.html`) to ensure the document remains accurate to 7.8.x even after Confluent publishes newer versions.
  5. Replace or clarify the CP 7.9 ZooKeeper reference (`platform/7.9/kafka-metadata/zk-production.html`) — either use the 7.8 equivalent URL or note explicitly that this 7.9 doc is used because ZK production guidance did not change between 7.8 and 7.9.

## [TL] Cycle 2 guidance — tester FAIL 89.15%
- Fix UAMI credential: VM UAMI uses IMDS (no secret needed). Remove azureClientSecret from config. Use `azureClientCredential = managed_identity` approach.
- Add KRaft configuration section: process.roles, node.id, controller.quorum.voters (CP 7.8 supports KRaft GA)
- Pin all doc URLs to /7.8/ not /current/ for version accuracy
- Remove CP 7.9 ZooKeeper reference — scope is 7.8.x only
- Fix hotset default: actual default is retention.ms (7 days), not 24h

## [Coder] 2026-03-30T15:57:00Z — Cycle 2
- Applied all 5 tester issues from Cycle 1 review (score 89.15%)
- Issue 1 (UAMI credential, -8pts Accuracy): Replaced service-principal JSON (`azureClientId + azureTenantId + azureClientSecret`) with `ManagedIdentityCredentialProvider` in both the broker config section and Example Configuration. Added clear UAMI vs Service Principal comparison. Documented that UAMI on a broker VM uses Azure IMDS — no client secret required.
- Issue 2 (Hotset default, Accuracy): Changed `confluent.tier.local.hotset.ms` comment from "default 24h" to "Default: inherits from retention.ms (7 days). Recommended dev value: 86400000 (24 h)" in both the config section and the segment lifecycle diagram.
- Issue 3 (Missing KRaft config, -7pts Completeness): Added new `## KRaft Configuration` section between ZooKeeper and Replication Strategy. Includes `process.roles=broker,controller`, `node.id`, `controller.quorum.voters`, `controller.listener.names`, `listeners`, `listener.security.protocol.map`, node.id table, cluster initialisation steps, and KRaft vs ZooKeeper property comparison.
- Issue 4 (URL versioning, -12pts Sources): Replaced all `/current/` Confluent doc URLs with `/7.8/` across all 10 Confluent Platform references in the References table.
- Issue 5 (CP 7.9 ZK reference, Sources): Changed `platform/7.9/kafka-metadata/zk-production.html` to `platform/7.8/kafka-metadata/zk-production.html` and updated label to "CP 7.8".
- Updated backlog document: doc-8
- All 5 tester issues addressed

## [Tester] 2026-03-30T16:05:00Z — Cycle 2 Review
- PASS — Score: 96.30%
- Accuracy: 96/100 — Both Cycle 1 accuracy issues resolved cleanly. UAMI fix: `ManagedIdentityCredentialProvider` used throughout; optional disambiguation file shows only `azureClientId` with explicit note that `azureClientSecret` is incorrect in UAMI context. Hotset default fix: property now reads "Default: inherits from retention.ms (7 days). Recommended dev value: 86400000 (24 h)" in both the config section and segment lifecycle diagram. One minor residual: line 16 body text still reads "fully documented in the 7.9 branch of the docs" (reference to ZK docs branch) but does not affect config accuracy. Dev SBC trigger (`EMPTY_BROKER`) is appropriate for dev; Production guidance (`ANY_UNEVEN_LOAD`) is present in the SBC section.
- Completeness: 97/100 — All 6 AC items fully addressed. KRaft section added with `process.roles`, `node.id`, `controller.quorum.voters`, `controller.listener.names`, `listeners`, `listener.security.protocol.map`, node.id table, initialisation commands, and KRaft vs ZooKeeper comparison table. Minor: the Example Configuration section shows only ZooKeeper-mode broker config with a note to "replace with KRaft for new clusters" — a full KRaft server.properties equivalent would be ideal, but the KRaft section provides all the necessary properties and is actionable.
- Sources: 97/100 — All 10 Confluent Platform URLs now version-pinned to `/7.8/`. CP 7.9 ZooKeeper reference corrected to `platform/7.8/kafka-metadata/zk-production.html`. 17 total references. Blog and third-party URLs (Confluent blog, ZooKeeper Apache docs, Microsoft Learn) are not version-pinnable — acceptable.
- Documentation Quality: 95/100 — Executive summary, clear heading hierarchy, ASCII segment lifecycle diagram, sizing tables, deprecation notices, KRaft vs ZooKeeper comparison table, and inline config comments all present and well-executed. 762 lines.
- Actionability: 96/100 — VM-specific heap sizes, private IPs, Azure RBAC role names (`Storage Blob Data Contributor`, `Key Vault Crypto User`), dev vs. production throttle values, KRaft initialisation commands, CMEK + private endpoint setup steps, and topic-level tiered storage override example are all concrete and deployable.
- Score computation: (96×0.30) + (97×0.25) + (97×0.20) + (95×0.15) + (96×0.10) = 28.80 + 24.25 + 19.40 + 14.25 + 9.60 = **96.30%** ≥ 95% threshold — PASS
<!-- SECTION:NOTES:END -->
