---
id: TASK-27.5
title: SP0.004 — Confluent Cluster Linking
status: Done
assignee:
  - tester-8
created_date: '2026-03-30 15:20'
updated_date: '2026-03-30 16:00'
labels:
  - research
milestone: m-0
dependencies: []
references:
  - >-
    https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/overview.html
parent_task_id: TASK-27
priority: high
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Objective:** Research Confluent Cluster Linking for multi-region replication, topology options, and failover patterns. Cluster Linking is central to the kafka-lab project's resiliency testing — it connects the 3-region deployment (southcentralus primary, mexicocentral secondary, canadaeast DR) and enables failover scenarios the web app dashboard will visualize.\n\n**Sources:**\n- https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/overview.html\n- https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/configs.html\n- https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/mirror-topics-cp.html\n- Confluent Cluster Linking tutorials and best practices\n\n**Output:** A backlog document created via `backlog-document_create` containing:\n- Executive summary of Cluster Linking vs MirrorMaker 2\n- Link creation and configuration (cluster.link.prefix, bootstrap servers)\n- Mirror topics (auto-create, sync offsets, consumer group migration)\n- Topology options for 3-region setup (hub-spoke, mesh, chain)\n- Failover and failback procedures (promote mirror topic, reverse link)\n- Performance considerations (bandwidth, latency, compression)\n- Recommended topology for scus→mexicocentral→canadaeast\n- Example configuration and CLI commands\n- References with URLs\n\n**Scope:**\n- Include: Link creation, mirror topics, failover/failback, topology for 3 regions, performance\n- Exclude: MirrorMaker 2 deep-dive, Confluent Cloud cluster linking, security config (SP0.005)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Document covers cluster link creation and configuration
- [x] #2 Document covers mirror topics (auto-create, offset sync, consumer group migration)
- [x] #3 Document covers failover and failback procedures with step-by-step instructions
- [x] #4 Document covers topology options and recommends topology for scus/mexicocentral/canadaeast
- [x] #5 Document includes example CLI commands for link and mirror topic management
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Coder] 2026-03-30T11:46:00 EDT
- Completed research for SP0.004 — Confluent Cluster Linking
- Created backlog document: doc-9
- Sources consulted:
  - https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/index.html
  - https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/configs.html
  - https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/mirror-topics-cp.html
  - https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/commands.html
  - https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/faqs-cp.html
  - https://docs.confluent.io/cloud/current/multi-cloud/cluster-linking/dr-failover.html
  - https://docs.confluent.io/platform/current/multi-dc-deployments/multi-region-architectures.html
  - https://developer.confluent.io/courses/hybrid-cloud/cluster-linking/
- Score self-assessment: Addressed all 5 AC items
  - AC1: Link creation and configuration covered with full properties reference and CLI commands
  - AC2: Mirror topics covered — auto-create, offset sync, consumer group migration, lifecycle commands
  - AC3: Failover and failback covered with step-by-step CLI procedures for scus→mexicocentral and reverse
  - AC4: Topology options (hub-spoke, mesh, chain) with comparison table and explicit recommendation for scus/mexicocentral/canadaeast
  - AC5: Example CLI commands throughout — kafka-cluster-links, kafka-mirrors, kafka-consumer-groups, kafka-configs

## [Tester] 2026-03-30T11:50:05 EDT
- FAIL — Score: 93.15%
- Accuracy: 85/100 — Factual error: document states Cluster Linking was "introduced in Confluent Platform 5.4"; the correct version is CP 6.0 (GA in CP 6.1). CP 5.4 introduced Multi-Region Clusters (MRC), a different feature. Secondary: `--replication-factor` flag on `kafka-mirrors --create` (line ~470) is not a documented parameter for that subcommand in CP 7.8.x — needs verification.
- Completeness: 98/100 — All 5 AC items thoroughly addressed. Minor gap: prerequisites mention UAMI and SASL/OAUTHBEARER but no concrete OAUTHBEARER JAAS config example is provided; all auth examples use SASL/PLAIN only.
- Sources: 95/100 — 10 references cited with URLs, all from official Confluent sources. The DR failover reference (https://docs.confluent.io/cloud/current/multi-cloud/cluster-linking/dr-failover.html) is a Confluent Cloud doc, not a Confluent Platform doc; a Platform-specific DR reference would be stronger.
- Documentation Quality: 97/100 — Executive summary present and detailed, excellent sectioning, ASCII topology diagrams, comparison tables, latency estimates, step-by-step failover/failback procedures.
- Actionability: 96/100 — Private IP addresses, actual byte values, complete `.properties` files, and 3-region CLI setup commands are directly usable by engineers.
- Required improvements:
  1. Fix version history: change "introduced in Confluent Platform 5.4" to "introduced in Confluent Platform 6.0 (GA in CP 6.1)". CP 5.4 introduced Multi-Region Clusters, not Cluster Linking.
  2. Verify or remove the `--replication-factor` flag on `kafka-mirrors --create`. If it is not a valid flag in CP 7.8.x, replace with the equivalent `kafka-configs --alter` command to set replication factor post-creation.
  3. Add a SASL/OAUTHBEARER JAAS config example for Azure UAMI authentication to align with the project's "UAMI per cluster" prerequisite stated at the top of the section.
  4. Replace or supplement the Confluent Cloud DR failover reference with a Confluent Platform equivalent (e.g., https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/disaster-recovery.html) for better Platform-specificity.

## [TL] Cycle 2 guidance — tester FAIL 93.15%
- Fix version history: Cluster Linking was introduced in CP 6.0 (GA in 6.1), NOT 5.4. CP 5.4 introduced Multi-Region Clusters.
- Remove/fix the `--replication-factor` flag on `kafka-mirrors --create` — not documented in 7.8.x; use kafka-configs post-creation instead.
- Add OAUTHBEARER/UAMI auth example: if docs say UAMI is supported, show the JAAS config or note the feature requires specific Confluent Platform configuration.
- Replace the Confluent Cloud DR failover link with a Platform-equivalent URL for the failover reference.

## [Coder] 2026-03-30T11:56:00 EDT — Cycle 2
- Applied tester feedback: fixed version history (6.0 not 5.4), removed invalid --replication-factor flag, added OAUTHBEARER/UAMI note, replaced Cloud DR reference with Platform reference
- Updated backlog document: doc-9
- All 4 tester issues addressed:
  1. Executive summary now states CP 6.0 (GA in CP 6.1); clarifies CP 5.4 introduced MRC, not Cluster Linking
  2. Removed --replication-factor from kafka-mirrors --create; replaced with kafka-configs --alter post-creation pattern
  3. Added UAMI/OAUTHBEARER note in Prerequisites explaining CP 7.8.x limitation and kafka-lab workaround (SASL/PLAIN credentials per UAMI stored in Key Vault)
  4. Replaced Confluent Cloud DR reference with Platform-specific URL: https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/disaster-recovery.html
<!-- SECTION:NOTES:END -->

## [Tester] 2026-03-30T12:05:00 EDT — Cycle 2 Review
- **PASS — Score: 96.65%**

### Category Scores

| Category | Weight | Score | Weighted |
|---|---|---|---|
| Accuracy | 30% | 95/100 | 28.50 |
| Completeness | 25% | 98/100 | 24.50 |
| Sources | 20% | 97/100 | 19.40 |
| Documentation Quality | 15% | 97/100 | 14.55 |
| Actionability | 10% | 97/100 | 9.70 |
| **Total** | **100%** | — | **96.65** |

### Findings

**Accuracy (95/100):** All four cycle-1 issues resolved correctly.
1. Version history fixed — executive summary now reads "introduced in Confluent Platform 6.0 and reaching general availability (GA) in CP 6.1"; CP 5.4 / MRC distinction explicitly called out.
2. `--replication-factor` flag removed from `kafka-mirrors --create`; document explicitly states CP 7.8.x does not accept this flag and provides the correct `kafka-configs --alter` post-creation pattern.
3. UAMI/OAUTHBEARER note added with accurate explanation: CP 7.8.x lacks native Azure MSI integration, requiring a custom `OAuthBearerLoginCallbackHandler`; kafka-lab workaround (SASL/PLAIN credentials per UAMI stored in Key Vault) correctly specified.
4. All core facts (offset fidelity, broker-native pull model, `confluent.cluster.link.enable=true` default in CP 7.x, `cluster.link.prefix` immutability, `consumer.byte.rate` quota) remain accurate.

**Completeness (98/100):** All 5 AC items fully addressed. OAUTHBEARER note adds depth beyond what was required.

**Sources (97/100):** 10 references; Confluent Cloud DR reference replaced with Platform-specific `disaster-recovery.html`. One Cloud reference remains (`cluster-links-cc.html`) but is clearly labeled as Confluent Cloud and does not substitute for any Platform doc.

**Documentation Quality (97/100):** Executive summary, topology ASCII diagrams, comparison table, step-by-step failover/failback, latency estimates, and complete `.properties` file all present and well-structured.

**Actionability (97/100):** Private IPs, exact byte values, file-based secret references, full 3-region CLI setup, and post-creation replication factor pattern are directly usable by engineers.

Threshold: 95% | Result: **PASS (96.65%)**
