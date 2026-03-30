---
id: TASK-27.11
title: SP0.012 — Azure Chaos Studio for Kafka Resiliency
status: Done
assignee:
  - tester-14
created_date: '2026-03-30 15:22'
updated_date: '2026-03-30 16:11'
labels:
  - research
milestone: m-0
dependencies: []
references:
  - 'https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-overview'
parent_task_id: TASK-27
priority: low
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Objective:** Research Azure Chaos Studio for testing Kafka cluster resiliency. While Chaos Studio experiments are planned for later sprints (SP3/SP4+), this research establishes the foundation for experiment design, target resource configuration, and monitoring integration.\n\n**Sources:**\n- https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-overview\n- https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-fault-library\n- https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-tutorial-agent-based-portal\n- Azure Chaos Studio best practices and experiment design\n\n**Output:** A backlog document created via `backlog-document_create` containing:\n- Executive summary of Chaos Studio for Kafka resiliency testing\n- Experiment types for Kafka scenarios:\n  - VM shutdown faults (broker failure, ZK node loss)\n  - Network faults (partition between regions, latency injection)\n  - Disk faults (I/O pressure, disk full simulation)\n- Target resource configuration (onboarding VMs, VNets, capabilities)\n- Experiment design for the project's topology:\n  - Single broker failure in scus\n  - ZooKeeper quorum loss\n  - Cross-region network partition (scus ↔ mexicocentral)\n  - Full region failure (trigger Cluster Linking failover)\n- Monitoring during chaos (JMX metrics, Prometheus alerts, dashboard indicators)\n- Abort conditions and safety mechanisms (automatic stop, blast radius limits)\n- Integration with the web app dashboard for visualization\n- Example experiment JSON definitions\n- References with URLs\n\n**Scope:**\n- Include: Experiment types, target config, fault scenarios, monitoring, abort conditions\n- Exclude: Actual experiment execution (SP3/SP4+), Cluster Linking failover procedures (SP0.004), infrastructure provisioning
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Document covers Chaos Studio experiment types relevant to Kafka (VM shutdown, network disconnect, disk pressure)
- [x] #2 Document covers target resource configuration for Azure VMs and VNets
- [x] #3 Document covers fault injection scenarios for single-region and cross-region failures
- [x] #4 Document covers monitoring integration during chaos experiments (metrics, alerts, dashboards)
- [x] #5 Document covers abort conditions and safety mechanisms
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Coder] 2026-03-30T16:08:00Z
- Researched Azure Chaos Studio via official Microsoft Learn docs (overview, fault library, targets & capabilities, agent-based tutorial)
- Verified all fault URNs, capability names, and parameters for VM-relevant faults: VM Shutdown, Network Disconnect/Latency/PacketLoss/Isolation, CPU Pressure, Physical Memory Pressure, Linux Disk IO Pressure, Kill Process, Stop Service, DNS Failure
- Documented Linux-specific limitations: outbound-only for network agent faults; networkIsolation cannot be cancelled mid-run
- Researched experiment JSON structure including identity (SystemAssigned), selectors, steps, branches, and action URNs
- Researched JMX metrics relevant to Kafka chaos monitoring: UnderReplicatedPartitions, ActiveControllerCount, OfflinePartitionsCount, ISR shrink rate, consumer lag, Cluster Linking lag
- Documented abort conditions via Azure Monitor alert → Chaos Cancel API webhook pattern
- Created backlog document doc-15: SP0.012 — Azure Chaos Studio for Kafka Resiliency
- Document covers all 5 AC items: experiment types, target config, fault scenarios, monitoring, abort conditions
- All 4 chaos scenarios scoped to kafka-lab topology (scus/mexicocentral/canadaeast)
- Quality target: 95% (research task)

## [Tester] 2026-03-30T16:15:00Z

### Research Rubric Score — PASS ✅

| Category | Weight | Score | Weighted |
|---|---|---|---|
| Accuracy | 30% | 95% | 28.5 |
| Completeness | 25% | 99% | 24.75 |
| Sources | 20% | 97% | 19.4 |
| Documentation Quality | 15% | 98% | 14.7 |
| Actionability | 10% | 98% | 9.8 |
| **Total** | | | **97.15%** |

**Threshold:** 95% · **Result:** PASS (97.15%)

#### Accuracy (95%)
- All 13 fault capability URNs verified and correctly formatted (`urn:csci:microsoft:...`).
- Target types (`Microsoft-VirtualMachine`, `Microsoft-Agent`, `Microsoft-NetworkSecurityGroup`) are accurate.
- ARM experiment JSON structure is correct: `identity.type: SystemAssigned`, `selectors` with `List` type, `steps/branches/actions` hierarchy, ISO 8601 durations.
- Minor uncertainty: `urn:csci:microsoft:azureLoadTesting:startLoad/1.0` used in the parallel load branch is not a documented standard Chaos Studio fault; appears to be an extrapolation. Impact is low — it is illustrative and clearly labelled, not central to any scenario design.
- Linux-specific network fault limitations (outbound-only, `networkIsolation` non-cancellable) correctly documented.

#### Completeness (99%)
- All 5 AC items fully satisfied: experiment types ✓, target resource config ✓, fault scenarios ✓, monitoring ✓, abort conditions ✓.
- All 4 required fault scenarios present: single broker failure (scus), ZooKeeper quorum loss, cross-region partition (scus↔mexicocentral), full region failure (Cluster Linking failover).
- Additional scope from description fully covered: web app dashboard integration, example JSON, references.

#### Sources (97%)
- 13 references with full URLs; 9 from official Microsoft Learn, 1 from Confluent Platform docs, 1 from Azure AKS docs, 2 from community/blog.
- Primary authoritative sources used for all core claims (overview, fault library, targets & capabilities, permissions).

#### Documentation Quality (98%)
- Executive summary is clear and explicitly ties Chaos Studio value to kafka-lab architecture.
- Well-structured with H2/H3 headings, comparison tables, numbered scenario sections.
- Complete ARM JSON example with bash role-assignment commands; code blocks include language identifiers.
- Prometheus YAML scrape config, JMX MBean paths, and alert tables all properly formatted.

#### Actionability (98%)
- All 4 scenarios scoped to exact kafka-lab topology (3 regions, 6 brokers + 3 ZK in scus).
- Uses real names: `klc-rg-kafkalab-scus`, `kafka-broker-scus-01`, correct region identifiers throughout.
- Hypotheses include measurable success criteria (consumer lag < 50,000 messages, recovery within 60s, etc.).
- Blast radius table and duration limits are directly usable as SP3/SP4 experiment guard-rails.
- Placeholder values (`{subscriptionId}`) are appropriate and expected for a design document.
<!-- SECTION:NOTES:END -->
