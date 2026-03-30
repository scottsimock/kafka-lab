---
id: doc-18
title: Sprint Report
type: other
created_date: '2026-03-30 17:26'
updated_date: '2026-03-30 23:54'
---
# Sprint Report

## Project Summary

| Metric | Value |
|---|---|
| Total sprints completed | 5 (SP0, SP1, SP2, SP3, SP4) |
| Total stories completed | 50 |
| Total stories blocked | 0 |
| Overall completion rate | 100% |

## Backlog Overview

| Sprint | Goal | Stories | Status |
|---|---|---|---|
| SP0 | Research and Planning | 12 | Complete |
| SP1 | Foundation Infrastructure | 11 | Complete |
| SP2 | Compute and Base Configuration | 10 | Complete |
| SP3 | Kafka Platform Deployment | 10 | Complete |
| SP4 | Kafka Ecosystem Services | 7 | Complete |
| SP5 | Web Application | 10 | To Do |
| SP6 | CI/CD Pipeline | 8 | To Do |
| SP7 | Multi-Region Expansion | 8 | To Do |
| SP8 | Resiliency and Production Hardening | 8 | To Do |

---

## SP0 — Research and Planning

**Status:** Complete
**Date:** 2026-03-30

### Metrics

| Metric | Value |
|---|---|
| Stories completed | 12/12 |
| Stories blocked | 0 |
| Completion rate | 100% |
| Average score | 96.76% |
| PO↔SM iterations | 2 |

### SP0P1 — Research Phase

| Task | Title | Score | Cycles |
|---|---|---|---|
| TASK-27.6 | SP0.001 — Confluent Kafka Platform Overview | 96.30% | 2 |
| TASK-27.3 | SP0.002 — Confluent Schema Registry | 96.60% | 1 |
| TASK-27.1 | SP0.003 — Confluent Kafka Connect | 95.80% | 1 |
| TASK-27.5 | SP0.004 — Confluent Cluster Linking | 96.65% | 2 |
| TASK-27.2 | SP0.005 — Kafka Security and Authentication | 96.35% | 1 |
| TASK-27.4 | SP0.006 — Azure Virtual Networks and Private Networking | 97.05% | 2 |
| TASK-27.12 | SP0.007 — Azure Virtual Machines for Kafka | 99.40% | 2 |
| TASK-27.7 | SP0.008 — Terraform AzAPI Provider | 96.25% | 1 |
| TASK-27.9 | SP0.009 — Ansible for Confluent Platform | 96.95% | 2 |
| TASK-27.10 | SP0.010 — GitHub Actions CI/CD for Azure | 96.95% | 1 |
| TASK-27.8 | SP0.011 — Next.js 15 on Azure Function Apps | 95.70% | 2 |
| TASK-27.11 | SP0.012 — Azure Chaos Studio for Kafka Resiliency | 97.15% | 1 |

### SP0P2 — Backlog Planning Phase

The PO reviewed all 12 research documents and REQUIREMENTS.md to create the full project backlog:

- **8 sprints** (SP1–SP8) with **72 story tasks** covering the complete project build-out
- Progressive approach: single-region dev (SP1–SP5) → CI/CD (SP6) → multi-region (SP7) → production hardening (SP8)
- SM validated all tasks in 2 iterations

### Research Documents Produced

| Doc ID | Title |
|---|---|
| doc-8 | SP0.001 — Confluent Kafka Platform Overview |
| doc-6 | SP0.002 — Confluent Schema Registry |
| doc-7 | SP0.003 — Confluent Kafka Connect |
| doc-9 | SP0.004 — Confluent Cluster Linking |
| doc-11 | SP0.005 — Kafka Security and Authentication |
| doc-10 | SP0.006 — Azure Virtual Networks and Private Networking |
| doc-12 | SP0.007 — Azure Virtual Machines for Kafka |
| doc-14 | SP0.008 — Terraform AzAPI Provider |
| doc-13 | SP0.009 — Ansible for Confluent Platform |
| doc-17 | SP0.010 — GitHub Actions CI/CD for Azure |
| doc-16 | SP0.011 — Next.js 15 on Azure Function Apps |
| doc-15 | SP0.012 — Azure Chaos Studio for Kafka Resiliency |

### Key Decisions / Notes

- Authentication model: SASL/SCRAM (client auth) + mTLS (inter-broker, Cluster Linking) + Confluent RBAC
- Hub-spoke topology for Cluster Linking: scus (primary) → mexicocentral (secondary), scus → canadaeast (DR)
- VNet CIDR plan: 10.1.0.0/16 (scus), 10.2.0.0/16 (mexicocentral), 10.3.0.0/16 (canadaeast)
- VM sizing: D4s_v5 for brokers, D2s_v5 for ZooKeeper/Schema Registry/Connect
- Next.js 15 on Azure Function Apps with VNet integration for private Kafka access
- All research tasks passed first or second cycle with 95%+ scores

---

## SP1 — Foundation Infrastructure

**Status:** Complete
**Date:** 2026-03-30
**Branch:** sprint/SP1-foundation-infrastructure

### Metrics

| Metric | Value |
|---|---|
| Stories completed | 11/11 |
| Stories blocked | 0 |
| Completion rate | 100% |
| Average score | 99.8% |

### Completed Tasks

| # | Task | Summary | Score |
|---|------|---------|-------|
| SP1.001 | Terraform Project Structure and Provider Configuration | Created terraform/environments/dev/ with AzAPI provider, versions.tf (>=1.6.0), data source for existing resource group | 100% |
| SP1.002 | Terraform State Backend Configuration | Azure backend with OIDC auth, partial config pattern for init without storage account | 100% |
| SP1.003 | User Assigned Managed Identity Module | UAMI module (Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31), instantiated as klc-id-kafkalab-scus | 100% |
| SP1.004 | Key Vault Module with CMEK | Key Vault with RBAC auth, purge protection, CMEK RSA-2048 key, Crypto Officer role assignment | 100% |
| SP1.005 | Virtual Network Module with Subnets | VNet klc-vnet-scus (10.1.0.0/16) with 7 inline subnets for all components | 100% |
| SP1.006 | Network Security Group Module | NSG module with configurable rules, auto-appended DenyAllInbound at P4096, subnet association | 100% |
| SP1.007 | NSG Instances for All Subnets | 7 NSG instances via for_each with full security rules per doc-10 specifications | 100% |
| SP1.008 | Private DNS Zone Module | Private DNS zone module with multi-VNet link support via for_each, autoregistration disabled | 100% |
| SP1.009 | Private DNS Zone Instances | privatelink.blob.core.windows.net and privatelink.vaultcore.azure.net zones linked to VNet | 100% |
| SP1.010 | Private Endpoint Module | PE module with privateLinkServiceConnections and DNS zone group for auto A record registration | 100% |
| SP1.011 | Storage Account and Private Endpoints | Storage account klcstgkafkalabscus with CMEK, UAMI, PEs for blob and Key Vault | 98% |

### Key Deliverables

- Complete Terraform project structure with AzAPI provider
- VNet with 7 subnets, 7 NSGs with full security rules
- Key Vault with CMEK encryption key
- UAMI for cross-resource authentication
- Private DNS zones and private endpoints for storage and Key Vault
- All infrastructure modules reusable for multi-region expansion

### Key Decisions

- AzAPI provider (not AzureRM) for full ARM API control and preview feature support
- RBAC authorization on Key Vault instead of access policies
- Inline subnets within VNet resource body per ARM API expectations
- DenyAllInbound auto-appended by NSG module at priority 4096

---

## SP2 — Compute and Base Configuration

**Status:** Complete
**Date:** 2026-03-30
**Branch:** sprint/SP2-compute-and-base-configuration

### Metrics

| Metric | Value |
|---|---|
| Stories completed | 10/10 |
| Stories blocked | 0 |
| Completion rate | 100% |
| Average score | 99.3% |

### Completed Tasks

| # | Task | Summary | Score |
|---|------|---------|-------|
| SP2.001 | Virtual Machine Terraform Module | Reusable VM module with NIC, conditional data disk, conditional DNS A record, UAMI, zone placement | 100% |
| SP2.002 | ZooKeeper VM Instances | 3 ZK VMs (D2s_v5, Zone 1) with 64GB data disks, static IPs 10.1.2.4-6, kafkalab.internal DNS zone | 100% |
| SP2.003 | Kafka Broker VM Instances | 3 broker VMs (D4s_v5, Zone 1) with 256GB data disks, static IPs 10.1.1.4-6 | 100% |
| SP2.004 | Ansible Project Structure and Dynamic Inventory | ansible/ with azure_rm dynamic inventory, group_vars, requirements.yml | 100% |
| SP2.005 | Ansible Common OS Configuration Role | Base packages, kafka user/group, sysctl tuning, ulimits | 100% |
| SP2.006 | Ansible Data Disk Setup Role | XFS format, UUID-based mount, component subdirectories via group_vars | 92% |
| SP2.007 | Ansible Java Installation Role | OpenJDK 17 headless, JAVA_HOME via profile.d, version verification | 100% |
| SP2.008 | Ansible Confluent Platform Installation Role | Confluent 7.9.0 download, extract, symlink /opt/confluent/current, PATH setup | 100% |
| SP2.009 | Schema Registry and Kafka Connect VM Instances | SR (D2s_v5, 10.1.3.4) and Connect (D2s_v5, 10.1.4.4) VMs, no data disks | 100% |
| SP2.010 | Ansible Site Playbook | Master playbook with 4 plays, rolling deployment (serial:1) for ZK/brokers, role ordering | 100% |

### Key Deliverables

- 8 VMs provisioned: 3 ZooKeeper, 3 Kafka brokers, 1 Schema Registry, 1 Kafka Connect
- kafkalab.internal private DNS zone with A records for all VMs
- Complete Ansible project with dynamic Azure inventory
- 4 base roles: common, disk-setup, java, confluent-common
- Site playbook orchestrating all component groups

### Key Decisions

- Confluent 7.9.0 (corrected from 7.8.0) requiring Java 17 (corrected from 11)
- for_each over count for VM instances — stable resource addresses
- serial:1 rolling deployment for ZK and broker plays
- XFS with noatime,nodiratime mount options for Kafka data disks
- 64GB data disks for ZK, 256GB for brokers (dev sizing)

### Risks / Carry-Forward

- ansible-lint flagged disk-setup role name (hyphen vs underscore) and community.general.filesystem FQCN — both originated from task spec, not coder error. Recommended fix in future sprint.

---

## SP3 — Kafka Platform Deployment

**Status:** Complete
**Date:** 2026-03-30 — 2026-03-31
**Branch:** sprint/SP3-kafka-platform-deployment

### Metrics

| Metric | Value |
|---|---|
| Stories completed | 10/10 |
| Stories blocked | 0 |
| Completion rate | 100% |
| PO↔SM iterations | 1 |

### Completed Tasks

| # | Task | Summary |
|---|------|---------|
| SP3.001 | Ansible ZooKeeper Role | Full ZK role with zookeeper.properties template (ensemble server lines via hostvars loop), myid file, JVM env (1g heap, G1GC), systemd unit, handler chain with ruok health check (6 retries/10s delay) |
| SP3.002 | Ansible Kafka Broker Role | Kafka broker role with sectioned server.properties.j2 using {% if %} guards for PLAINTEXT vs SASL_SSL, TLS, tiered storage, and self-balancing. 6g heap with G1GC. Systemd unit with ZK ordering. SCRAM bootstrap via --zookeeper flag. admin.properties for CLI ops |
| SP3.003 | Ansible Group and Host Variables | Created host_vars/ for all 6 nodes (zk-01..03, kb-01..03) with per-host myid/broker.id/rack. Extended group_vars with ZK ensemble config and broker defaults plus boolean feature flags |
| SP3.004 | TLS Certificate Generation Role | CA generation (delegate_to: localhost, run_once), per-node certs with SAN (serverAuth+clientAuth), JKS keystores/truststores, distribution to /etc/kafka/ssl/ (0750/0640, kafka:kafka) |
| SP3.005 | Kafka SASL/SCRAM Security Configuration | Dual SASL_SSL listeners (CLIENT:9092, INTERNAL:9093), SCRAM-SHA-512 mechanism, per-listener JAAS config, SSL keystore/truststore, AclAuthorizer with super.users, SCRAM credential bootstrap in ZooKeeper |
| SP3.006 | Kafka Client Credentials | kafka-client-creds role with SCRAM user creation (web-app, schema-registry, connect-worker) via --bootstrap-server, per-service client.properties files (0640, kafka:kafka) to /etc/kafka/client/ |
| SP3.007 | Kafka Tiered Storage Configuration | Tiered storage in server.properties.j2 with {% if %} guard — Azure Blob Storage backend, UAMI credentials, metadata RF=3, hotset 24h, archiver/fetcher threads |
| SP3.008 | Kafka Self-Balancing Configuration | Self-balancing in server.properties.j2 with {% if %} guard — ANY_UNEVEN_LOAD trigger, 10MB/s throttle, 5-min failure threshold. No Auto Data Balancer conflict |
| SP3.009 | Cluster Verification Playbook | verify-cluster.yml with ZK play (ruok+stat on all nodes) and Kafka play (API connectivity, topic create RF=3/6p, produce 3 msgs, consume 3 msgs via SASL_SSL, idempotent) |
| SP3.010 | Kafka ACL Configuration | Least-privilege ACLs for all principals — web-app (kafkalab.* prefixed), schema-registry (_schemas), connect-worker (connect-* prefixed), admin (cluster-wide). Verification via kafka-acls --list with assertions |

### Key Deliverables

- ZooKeeper ensemble role with health checking and ensemble membership
- Kafka broker role with extensible template supporting SASL_SSL, TLS, tiered storage, and self-balancing
- TLS certificate generation and distribution pipeline (private CA, per-node certs, JKS stores)
- SASL/SCRAM-SHA-512 authentication with dual listeners (CLIENT + INTERNAL)
- Client credential management for web-app, schema-registry, and connect-worker
- Tiered storage with Azure Blob Storage backend (UAMI auth)
- Self-balancing cluster with continuous load rebalancing
- Kafka ACLs enforcing least-privilege access per service principal
- End-to-end cluster verification playbook (ZK health + message flow through SASL_SSL)

### Key Decisions

- SCRAM credentials bootstrapped via --zookeeper flag (ZK mode) before broker SASL startup
- server.properties.j2 uses sectioned {% if %} guards for feature modularity — each feature independently toggleable
- TLS certificates generated on Ansible controller and distributed to targets (not generated on each node)
- extendedKeyUsage includes both serverAuth and clientAuth for inter-broker mTLS
- Tiered storage uses UAMI authentication via Azure IMDS (no credential files)
- Self-balancing trigger set to ANY_UNEVEN_LOAD (production-recommended) with 10MB/s dev throttle
- ACLs use prefixed resource patterns for namespace isolation (kafkalab.*, connect-*, webapp-*)
- admin.properties created once in SP3.005 and reused by SP3.006, SP3.009, SP3.010

### Risks / Carry-Forward

- TLS passwords use default 'changeit' values — must be replaced with vault-managed secrets before production deployment
- File contention on server.properties.j2 required serialized task execution (SP3.005 → SP3.007 → SP3.008)
- ansible-lint unavailable in build environment — manual YAML validation performed
- TASK-28.9 (SP1.011) remains at Dev Complete status (tester scored 98% but status not advanced to Done)

---

## SP4 — Kafka Ecosystem Services

**Status:** Complete
**Date:** 2026-03-30
**Branch:** sprint/SP4-kafka-ecosystem-services

### Metrics

| Metric | Value |
|---|---|
| Stories completed | 7/7 |
| Stories blocked | 0 |
| Completion rate | 100% |
| Average score | 100% |
| Total retries | 1 |
| Files added/changed | 38 (29 new Ansible files) |
| Lines added | 1,279 |
| Commits | 9 |

### Completed Tasks

| # | Task | Summary | Score |
|---|------|---------|-------|
| SP4.001 | Ansible Schema Registry Role | Full role with properties template, systemd service, health check handler, JVM heap config | 10/10 (100%) |
| SP4.002 | Ansible Kafka Connect Role | Distributed mode role with properties template, connector install tasks, systemd service, REST API health check | 12/12 (100%) |
| SP4.003 | Schema Registry and Connect Group Variables | Populated schema_registry.yml and kafka_connect.yml with bootstrap servers, SASL_SSL security, JVM heaps, vault credential references | 8/8 (100%) |
| SP4.004 | Azure Blob Storage Sink Connector | Confluent Hub install task, connector JSON config template with UAMI auth, DLQ setup | 8/8 (100%) |
| SP4.005 | Application Topic Creation | Playbook creating 4 topics (app-messages/12p, app-events/6p, app-metrics/6p, app-state/compacted/6p), all RF=3, min.insync=2 | 8/8 (100%) |
| SP4.006 | Schema Registration | 3 Avro schemas (messages, events, metrics) with REST API registration playbook | 6/6 (100%) |
| SP4.007 | Ecosystem Verification Playbook | Comprehensive playbook verifying SR, Connect, topics, schemas, Blob sink connector, and E2E Avro produce→consume→sink test | 9/9 (100%) |

### Execution Waves

- **Wave 1** (parallel): SP4.001, SP4.002, SP4.005 — all first-pass success
- **Wave 2** (parallel): SP4.003, SP4.004 — all first-pass success
- **Wave 3**: SP4.006 — first-pass success
- **Wave 4**: SP4.007 — 1 retry (Avro tooling fix for E2E test)

### Key Deliverables

- **Schema Registry Role** (`ansible/roles/schema-registry/`) — Full role with properties template, systemd service, health check handler, JVM heap config
- **Kafka Connect Role** (`ansible/roles/kafka-connect/`) — Distributed mode role with properties template, connector install tasks, systemd service, REST API health check
- **Group Variables** — Populated `schema_registry.yml` and `kafka_connect.yml` with bootstrap servers, SASL_SSL security, JVM heaps, vault credential references
- **Azure Blob Storage Sink Connector** — Confluent Hub install task, connector JSON config template with UAMI auth, DLQ setup
- **Application Topics** — Playbook creating 4 topics (app-messages/12p, app-events/6p, app-metrics/6p, app-state/compacted/6p), all RF=3, min.insync=2
- **Schema Registration** — 3 Avro schemas (messages, events, metrics) with REST API registration playbook
- **Ecosystem Verification** — Comprehensive playbook verifying SR, Connect, topics, schemas, Blob sink connector, and E2E Avro produce→consume→sink test

### Key Decisions

- Schema Registry and Kafka Connect deployed as single-node instances (dev sizing) on dedicated VMs from SP2.009
- SASL_SSL security configuration inherited from SP3 broker setup via group variables
- Avro chosen as the primary schema format for all application topics
- Compacted cleanup policy applied to app-state topic for stateful consumers
- DLQ (dead letter queue) configured on Blob sink connector for poison pill handling
- UAMI authentication for Azure Blob Storage sink (consistent with tiered storage auth from SP3)

---
