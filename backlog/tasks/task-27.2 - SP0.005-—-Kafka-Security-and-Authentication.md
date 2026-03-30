---
id: TASK-27.2
title: SP0.005 — Kafka Security and Authentication
status: Done
assignee:
  - tester-6
created_date: '2026-03-30 15:20'
updated_date: '2026-03-30 15:53'
labels:
  - research
milestone: m-0
dependencies: []
references:
  - 'https://docs.confluent.io/platform/current/security/index.html'
parent_task_id: TASK-27
priority: high
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Objective:** Research Kafka security models and recommend an authentication model for the kafka-lab project. The auth model was deferred to research during design sessions. Must consider the project's Azure Private Endpoint networking (no public access), UAMI integration, and multi-region Cluster Linking requirements.\n\n**Sources:**\n- https://docs.confluent.io/platform/current/security/index.html\n- https://docs.confluent.io/platform/current/security/authentication/sasl/index.html\n- https://docs.confluent.io/platform/current/security/rbac/index.html\n- https://docs.confluent.io/platform/current/security/authorization/acl/overview.html\n- Kafka security best practices for private network deployments\n\n**Output:** A backlog document created via `backlog-document_create` containing:\n- Executive summary of Kafka security layers (authentication, authorization, encryption)\n- SASL/SCRAM analysis (setup, credential management, pros/cons)\n- mTLS analysis (certificate management, CA setup, rotation, pros/cons)\n- RBAC analysis (Confluent RBAC, role definitions, integration points)\n- Comparison matrix of auth models for private network deployments\n- Recommended auth model with rationale (considering Azure Private Endpoints + UAMI)\n- ACL configuration patterns (topic-level, group-level, transactional)\n- Inter-broker and Cluster Linking authentication\n- Example security configuration\n- References with URLs\n\n**Scope:**\n- Include: SASL/SCRAM, mTLS, RBAC, ACLs, recommendation with rationale, inter-broker auth, Cluster Linking auth\n- Exclude: Azure networking details (SP0.006), Kerberos (not applicable for this project)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Document covers SASL/SCRAM authentication (setup, credential management, pros/cons)
- [ ] #2 Document covers mTLS authentication (certificate management, CA, rotation, pros/cons)
- [ ] #3 Document covers Confluent RBAC (role definitions, integration with Kafka)
- [ ] #4 Document includes comparison matrix and recommends auth model with rationale
- [ ] #5 Document covers ACL configuration patterns (topic, group, transactional)
- [ ] #6 Document covers inter-broker and Cluster Linking authentication requirements
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Coder] 2026-03-30T11:50:00 EDT
- Completed research for SP0.005 — Kafka Security and Authentication
- Created backlog document: doc-11
- Sources consulted:
  - https://docs.confluent.io/platform/current/security/authentication/sasl/scram/overview.html
  - https://docs.confluent.io/platform/current/security/authentication/mutual-tls/overview.html
  - https://docs.confluent.io/platform/current/security/rbac/index.html
  - https://docs.confluent.io/platform/current/security/rbac/rbac-predefined-roles.html
  - https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/security.html
  - https://docs.confluent.io/platform/current/security/security_tutorial.html
  - https://docs.confluent.io/platform/current/security/component/kraft-security.html
  - Web search results for SASL/SCRAM KRaft setup, mTLS config, ACL patterns, Cluster Linking security
- Score self-assessment: Addressed all 6 AC items
  - AC1: SASL/SCRAM section covers setup, KRaft credential management, rotation, pros/cons table
  - AC2: mTLS section covers CA setup, keystore/truststore generation, rotation procedure, pros/cons table
  - AC3: Confluent RBAC section covers MDS setup, all predefined roles table, role binding commands
  - AC4: Comparison matrix table across SCRAM/mTLS/RBAC/combo with recommendation and rationale
  - AC5: ACL patterns section covers topic-level, consumer group, transactional, inter-service examples
  - AC6: Inter-broker and Cluster Linking auth section covers KRaft controller SSL, broker SASL_SSL, link mTLS and SCRAM config

## [Tester] 2026-03-30T12:05:00 EDT
- PASS — Score: 96.35%
- Accuracy: 92/100 (30%) — Two minor issues: (1) MDS listener in the initial MDS Setup section uses `http://` while the complete server.properties config block correctly uses `https://` — inconsistency that could confuse implementers; (2) `confluent.authorizer.access.rule.providers=CONFLUENT,ZK_ACL` uses legacy ZooKeeper nomenclature — in KRaft-only deployments the canonical value is `CONFLUENT,KAFKAACL`; `ZK_ACL` still works in CP 7.8.x due to backward-compat aliasing but is misleading in a KRaft context. All other facts, CLI flags, version references (3.8, 7.8.x), and config key names are correct.
- Completeness: 100/100 (25%) — All 6 AC items fully addressed: SASL/SCRAM setup + credential management + pros/cons table (AC1); mTLS CA setup + cert generation + leaf rotation + CA rotation procedure + pros/cons table (AC2); Confluent RBAC MDS setup + full predefined roles table + role binding commands + RBAC/ACL coexistence (AC3); Comparison matrix across SCRAM/mTLS/RBAC/combo + layered recommendation with 5-point rationale (AC4); Topic-level, consumer group, transactional, and inter-service ACL patterns (AC5); KRaft controller-to-controller SSL config + broker-to-broker SASL_SSL config + Cluster Linking mTLS and SCRAM alternatives (AC6).
- Sources: 98/100 (20%) — 18 references, all primary official Confluent/Apache sources. Includes one version-pinned URL (platform/7.8/security/incremental-security-upgrade), two KIP specs, RFC 5802, and the Confluent security-tools GitHub repo. Strong sourcing.
- Documentation Quality: 97/100 (15%) — Executive summary is project-contextualized and covers all three security layers. Clear section hierarchy with H2/H3 headings. Extensive code blocks (bash, properties, CLI commands). Pros/cons tables in each auth section. Comparison matrix. Password externalization note. The only flaw is the http/https inconsistency in the MDS setup section.
- Actionability: 96/100 (10%) — Step-by-step setup procedures with exact CLI flags (--release-version 3.8, --add-scram syntax). Config examples use realistic FQDNs (broker1.kafkalab.internal), correct port numbers (9090/9092/9093), and ${file:...} password externalization pattern. Link naming convention matches project regions (scus-to-mxc). Admin properties bootstrap file provided. Commands are copy-paste ready.
- Summary: Exceptionally thorough research document covering all required auth topics with accurate KRaft-specific guidance, a well-reasoned layered recommendation (SCRAM + mTLS for controllers/links + RBAC), complete ACL patterns, and excellent primary sourcing. Minor deductions for an http/https MDS inconsistency and legacy ZK_ACL nomenclature in KRaft context — neither affects the correctness of the recommendation or implementation guidance materially.
<!-- SECTION:NOTES:END -->
