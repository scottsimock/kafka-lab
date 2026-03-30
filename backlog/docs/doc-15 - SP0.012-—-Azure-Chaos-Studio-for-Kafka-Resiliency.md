---
id: doc-15
title: SP0.012 — Azure Chaos Studio for Kafka Resiliency
type: other
created_date: '2026-03-30 16:08'
---
# SP0.012 — Azure Chaos Studio for Kafka Resiliency

**Research task:** TASK-27.11
**Sprint:** SP0 — Research and Planning
**Milestone:** SP0
**Applies to:** SP3/SP4+ implementation

---

## Executive Summary

Azure Chaos Studio is a managed chaos engineering service that enables controlled fault injection against Azure resources to validate and improve application resiliency. For the kafka-lab project — a three-region Confluent Kafka Platform deployment spanning `southcentralus` (primary), `mexicocentral` (secondary), and `canadaeast` (DR) — Chaos Studio is the primary mechanism for validating the resiliency claims made by the architecture.

Chaos engineering follows the scientific method applied to distributed systems: define a steady-state hypothesis (the system behaves normally with these measurable indicators), introduce a real-world fault, observe whether the hypothesis holds, and act on deviations. Azure Chaos Studio operationalizes this loop with a managed control plane, deep integration with Azure Monitor, and a fault library that covers the exact failure modes that threaten a Kafka cluster: VM failures, network partitions, disk I/O saturation, and CPU/memory pressure.

**Key value for kafka-lab:**

- Validates Confluent Cluster Linking failover paths before a real regional outage occurs.
- Confirms ZooKeeper quorum recovery with `N-1` nodes alive.
- Quantifies consumer lag recovery time under controlled broker failure.
- Produces evidence-backed SLO targets and abort thresholds for the operations playbook.

Chaos Studio experiments are planned for SP3 (single-region scenarios) and SP4 (cross-region and full failover scenarios). This document provides the design foundation.

---

## Experiment Types for Kafka

Azure Chaos Studio supports two fundamentally different fault injection mechanisms. Choosing the right type for each Kafka scenario is critical.

### Service-Direct vs Agent-Based

| Dimension | Service-Direct | Agent-Based |
|---|---|---|
| **How it works** | Calls Azure Resource Manager (ARM) APIs against the resource | Installs a lightweight agent (VM extension) inside the guest OS |
| **Installation required** | None | Yes — Chaos Agent VM extension + managed identity |
| **Scope** | Azure control-plane actions (shutdown, redeploy) | In-guest OS actions (CPU pressure, kill process, network tc rules) |
| **Linux support** | Full | Full (with limitations on inbound network faults) |
| **Best for Kafka** | Broker VM shutdown, regional failover simulation | JVM process kill, CPU/memory pressure, network partition by port range |

### Kafka-Relevant Fault Catalogue

| Fault Name | Type | Target Type | Capability URN | Kafka Use Case |
|---|---|---|---|---|
| VM Shutdown | Service-Direct | `Microsoft-VirtualMachine` | `urn:csci:microsoft:virtualMachine:shutdown/1.0` | Broker failure, ZK node loss |
| VM Redeploy | Service-Direct | `Microsoft-VirtualMachine` | `urn:csci:microsoft:virtualMachine:redeploy/1.0` | Maintenance event simulation |
| NSG Security Rule | Service-Direct | `Microsoft-NetworkSecurityGroup` | `urn:csci:microsoft:networkSecurityGroup:securityRule/1.0` | Cross-region network partition |
| Network Disconnect | Agent-Based | `Microsoft-Agent` | `urn:csci:microsoft:agent:networkDisconnect/1.2` | Kafka inter-broker disconnect |
| Network Latency | Agent-Based | `Microsoft-Agent` | `urn:csci:microsoft:agent:networkLatency/1.2` | Replication lag simulation |
| Network Packet Loss | Agent-Based | `Microsoft-Agent` | `urn:csci:microsoft:agent:networkPacketLoss/1.2` | Degraded WAN link |
| Network Isolation | Agent-Based | `Microsoft-Agent` | `urn:csci:microsoft:agent:networkIsolation/1.0` | Full broker network split (cannot be cancelled mid-run) |
| CPU Pressure | Agent-Based | `Microsoft-Agent` | `urn:csci:microsoft:agent:cpuPressure/1.0` | Noisy-neighbour CPU contention on broker |
| Physical Memory Pressure | Agent-Based | `Microsoft-Agent` | `urn:csci:microsoft:agent:physicalMemoryPressure/1.0` | JVM heap pressure / GC thrashing |
| Linux Disk IO Pressure | Agent-Based | `Microsoft-Agent` | `urn:csci:microsoft:agent:linuxDiskIOPressure/1.1` | Log segment I/O saturation |
| Kill Process | Agent-Based | `Microsoft-Agent` | `urn:csci:microsoft:agent:killProcess/1.0` | Hard kill of `kafka` or `zookeeper` JVM process |
| Stop Service | Agent-Based | `Microsoft-Agent` | `urn:csci:microsoft:agent:stopService/1.0` | Graceful stop of Kafka systemd service |
| DNS Failure | Agent-Based | `Microsoft-Agent` | `urn:csci:microsoft:agent:dnsFailure/1.0` | DNS-based service discovery disruption (Windows only) |

**Important limitations for Linux VMs (all Kafka nodes):**

- `networkDisconnect`, `networkLatency`, `networkPacketLoss`: affect **outbound** traffic only on Linux. To block inter-broker inbound traffic on a Linux broker, use an NSG security rule (service-direct) targeting the VNet subnet instead.
- `networkIsolation`: cannot be cancelled once started; it runs to its configured duration.
- Agent-based network faults only work on new connections; existing TCP sessions persist until restarted.

---

## Target Resource Configuration

Before Chaos Studio can inject faults, each VM must be **onboarded** by creating chaos target and capability child resources. This is a one-time provisioning step per VM.

### Onboarding Steps

**1. Register the Chaos Studio resource provider** (subscription level, once):

```bash
az provider register --namespace Microsoft.Chaos
```

**2. Enable targets on each VM:**

Each VM requires up to two target types depending on the fault categories needed:

| Target Type | Fault Category | Resource Path Pattern |
|---|---|---|
| `Microsoft-VirtualMachine` | Service-direct (shutdown, redeploy) | `{vm_id}/providers/Microsoft.Chaos/targets/Microsoft-VirtualMachine` |
| `Microsoft-Agent` | Agent-based (CPU, memory, network, kill) | `{vm_id}/providers/Microsoft.Chaos/targets/Microsoft-Agent` |

```bash
# Service-direct target
az rest --method PUT \
  --url "https://management.azure.com/{vm_id}/providers/Microsoft.Chaos/targets/Microsoft-VirtualMachine?api-version=2023-11-01" \
  --body '{}'

# Agent-based target (requires managed identity parameter)
az rest --method PUT \
  --url "https://management.azure.com/{vm_id}/providers/Microsoft.Chaos/targets/Microsoft-Agent?api-version=2023-11-01" \
  --body '{"properties": {"identityClientId": "<uami-client-id>"}}'
```

**3. Enable capabilities per target** (one capability per fault to allow):

```bash
# Example: enable VM shutdown capability
az rest --method PUT \
  --url "https://management.azure.com/{vm_id}/providers/Microsoft.Chaos/targets/Microsoft-VirtualMachine/capabilities/shutdown-1.0?api-version=2023-11-01" \
  --body '{}'
```

**4. Install the Chaos Agent VM extension** (agent-based faults only):

The agent is installed as a VM extension. The portal handles this automatically when enabling agent-based targets via Chaos Studio → Targets → Enable agent-based targets. For Terraform/Ansible automation, use the `AzureChaosAgent` extension:

```bash
az vm extension set \
  --resource-group klc-rg-kafkalab-scus \
  --vm-name <vm-name> \
  --name ChaosLinuxAgent \
  --publisher Microsoft.Azure.Chaos \
  --version 1.0 \
  --settings '{"profile": "https://management.azure.com/..."}'
```

### System-Assigned vs User-Assigned Managed Identity

| Identity | Used By | Purpose |
|---|---|---|
| **System-assigned (experiment)** | The chaos experiment resource itself | Grants experiment permission to invoke faults against target VMs. Created automatically when an experiment is created. Must be given Reader (agent-based) or Virtual Machine Contributor (service-direct) role on target VMs. |
| **User-assigned (agent)** | The Chaos Agent running inside the VM | Allows the agent to communicate with the Chaos Studio control plane. A dedicated UAMI must be created and assigned to the VM before enabling agent-based targets. |

**Role assignments required:**

| Scenario | Role | Scope |
|---|---|---|
| Agent-based faults | `Reader` | Target VM |
| Service-direct VM shutdown | `Virtual Machine Contributor` | Target VM |
| NSG security rule faults | `Network Contributor` | Target NSG |

### VNet Onboarding for NSG Faults

Network Security Groups used for cross-region partition experiments must also be registered as chaos targets:

```bash
az rest --method PUT \
  --url "https://management.azure.com/{nsg_id}/providers/Microsoft.Chaos/targets/Microsoft-NetworkSecurityGroup?api-version=2023-11-01" \
  --body '{}'

az rest --method PUT \
  --url "https://management.azure.com/{nsg_id}/providers/Microsoft.Chaos/targets/Microsoft-NetworkSecurityGroup/capabilities/securityRule-1.0?api-version=2023-11-01" \
  --body '{}'
```

---

## Fault Scenarios for the Project

The kafka-lab topology (3-region, 6 Kafka brokers + 3 ZooKeeper nodes in `southcentralus`, mirrored via Cluster Linking to `mexicocentral`, DR in `canadaeast`) drives four primary chaos scenarios.

### Scenario 1 — Single Broker Failure (scus)

**Hypothesis:** When one of the three `southcentralus` Kafka brokers is shut down abruptly, under-replicated partitions recover to zero within 60 seconds, consumer lag does not exceed 50,000 messages, and no messages are permanently lost.

**Fault:** VM Shutdown (service-direct) against one broker VM in `southcentralus`.

**Parameters:**

```json
{
  "abruptShutdown": true,
  "restartWhenComplete": true
}
```

**Duration:** 5 minutes (allows for leader election + catch-up replication).

**Experiment structure:**

- Step 1: Delay 30 seconds (steady-state window for baseline metrics capture).
- Step 2 (Branch A): VM Shutdown on `kafka-broker-scus-01`.
- Step 2 (Branch B, parallel): Start Azure Load Testing run to maintain producer/consumer load.
- Step 3: Delay 10 minutes (observe recovery).

**Success criteria:** Under-replicated partitions = 0, consumer lag < 50,000 messages, no offset resets required.

---

### Scenario 2 — ZooKeeper Quorum Loss

**Hypothesis:** When two of the three ZooKeeper nodes are shut down simultaneously, the Kafka cluster becomes unavailable for new leader elections but existing partition leaders continue serving reads/writes. When the ZK nodes recover, the cluster regains full quorum within 2 minutes.

**Fault:** VM Shutdown (service-direct) against two of three ZK VMs simultaneously (parallel branches within one step).

**Parameters:**

```json
{
  "abruptShutdown": false,
  "restartWhenComplete": true
}
```

**Duration:** 3 minutes (minimum time to validate quorum-less behavior).

**Note:** With KRaft-mode Confluent (if adopted), replace with Kill Process targeting `kafka` JVM on controller nodes.

---

### Scenario 3 — Cross-Region Network Partition (scus ↔ mexicocentral)

**Hypothesis:** When the network path between `southcentralus` and `mexicocentral` is severed, Cluster Linking replication lag increases monotonically but no data is lost. When connectivity is restored, replication catch-up completes within 5 minutes.

**Fault:** NSG Security Rule (service-direct) — deny all TCP traffic on port 9092 between `southcentralus` broker subnet and `mexicocentral` broker subnet.

**NSG rule injected:**

```json
{
  "name": "chaos-block-cluster-link",
  "priority": 100,
  "direction": "Outbound",
  "access": "Deny",
  "protocol": "TCP",
  "sourceAddressPrefix": "<scus-broker-subnet-cidr>",
  "destinationAddressPrefix": "<mexicocentral-broker-subnet-cidr>",
  "destinationPortRange": "9092"
}
```

**Duration:** 10 minutes.

**Alternative (agent-based):** Use `networkDisconnect/1.2` on each `southcentralus` broker with `destinationFilters` targeting `mexicocentral` broker IPs on ports 9092–9093. Note this only blocks outbound; inbound blocking requires NSG.

**Success criteria:** Cluster Linking lag metric increases during fault, replication resumes and catches up within 5 minutes post-fault, no topic offset gaps.

---

### Scenario 4 — Full Region Failure (southcentralus → Cluster Linking Failover)

**Hypothesis:** When all VMs in `southcentralus` are shut down simultaneously, Cluster Linking promotion to `mexicocentral` can be completed within the RTO defined in the architecture, and producers can reconnect to the `mexicocentral` cluster within 10 minutes.

**Fault:** VM Shutdown (service-direct) against all broker and ZK VMs in `southcentralus` (parallel branches).

**Duration:** 20 minutes (allows full failover drill without extended downtime).

**Experiment structure:**

- Step 1: Delay 1 minute (pre-fault steady-state capture).
- Step 2 (Branches A–F in parallel): VM Shutdown on all 6 brokers + 3 ZK nodes in `southcentralus`.
- Step 3: Delay 15 minutes (manual Cluster Linking promotion + producer reconnection window).
- Step 4: Verify `mexicocentral` cluster health via Azure Monitor dashboard.

**Scope guard:** `canadaeast` DR cluster is excluded from this experiment — it is not targeted and continues running as fallback.

---

## Monitoring During Chaos

### JMX Metrics (Critical During Experiments)

These Kafka JMX metrics must be actively scraped via Prometheus JMX Exporter during every experiment:

| JMX Metric | MBean Path | Alert Threshold | Chaos Relevance |
|---|---|---|---|
| Under-Replicated Partitions | `kafka.server:type=ReplicaManager,name=UnderReplicatedPartitions` | > 0 for > 60s | Broker failure recovery |
| Active Controller Count | `kafka.controller:type=KafkaController,name=ActiveControllerCount` | ≠ 1 | ZK quorum, split-brain |
| Offline Partitions Count | `kafka.controller:type=KafkaController,name=OfflinePartitionsCount` | > 0 | Data availability |
| Consumer Group Lag | `kafka.consumer_group:type=ConsumerLag,*` | > 50,000 messages | Throughput recovery |
| Request Handler Idle % | `kafka.server:type=KafkaRequestHandlerPool,name=RequestHandlerAvgIdlePercent` | < 30% | CPU/memory pressure |
| Produce Request Rate | `kafka.server:type=BrokerTopicMetrics,name=MessagesInPerSec` | Drop > 50% baseline | Network/broker fault |
| Bytes Out Per Sec | `kafka.server:type=BrokerTopicMetrics,name=BytesOutPerSec` | Drop > 50% baseline | Cluster Linking replication |
| ISR Shrink Rate | `kafka.server:type=ReplicaManager,name=IsrShrinkRate` | > 0 during steady state | Replication health |
| Cluster Linking Lag | `confluent.server:type=cluster-link-metrics,*` | > 100,000 messages | Cross-region partition test |

### Azure Monitor Alerts

Configure Azure Monitor metric alerts that fire and are visible on the web app dashboard:

| Alert | Metric Source | Condition | Severity |
|---|---|---|---|
| Under-replicated partitions elevated | Prometheus → Azure Monitor | Value > 0 for 2 minutes | Sev 1 |
| Kafka broker VM offline | Azure VM Health | VM status = stopped | Sev 1 |
| Consumer lag spike | Custom metric from JMX exporter | Lag > 50,000 messages | Sev 2 |
| Cross-region replication lag | Cluster Linking metrics | Lag > 100,000 messages | Sev 2 |
| Active controller count anomaly | JMX → Prometheus | Count ≠ 1 | Sev 1 |

### Prometheus Scraping Configuration

All broker VMs must expose JMX Exporter on port `7071`. Prometheus scrape interval during chaos experiments: 15 seconds (vs 60 seconds in steady state) to capture transient failures.

```yaml
scrape_configs:
  - job_name: kafka_chaos
    scrape_interval: 15s
    static_configs:
      - targets:
          - kafka-broker-scus-01:7071
          - kafka-broker-scus-02:7071
          - kafka-broker-scus-03:7071
          - kafka-broker-mxc-01:7071
          - kafka-broker-mxc-02:7071
          - kafka-broker-mxc-03:7071
```

### Expected Cluster Linking Indicators

During Scenario 3 (cross-region partition) and Scenario 4 (full region failure):

- `confluent.cluster-link.mirror.lag.messages` increases monotonically during partition.
- `confluent.cluster-link.mirror.state` transitions from `ACTIVE` to `PAUSED`.
- After fault ends, `confluent.cluster-link.mirror.state` returns to `ACTIVE` and lag converges to 0.
- Cluster Linking auto-resumes without manual intervention if the link is still in `ACTIVE` mode; only a Cluster Linking **promotion** (for Scenario 4) requires operator action.

---

## Abort Conditions and Safety Mechanisms

### Automatic Abort via Azure Monitor

Chaos Studio integrates with Azure Monitor Alerts via the Chaos Studio Cancel API. Configure the following alert → action group → webhook chain:

1. **Alert rule:** `ActiveControllerCount ≠ 1 for 3 minutes` (catastrophic ZK/controller state).
2. **Action group:** Calls the Chaos Studio REST endpoint `POST .../experiments/{name}/cancel`.
3. **Effect:** All running fault actions are immediately terminated; VM Shutdown faults with `restartWhenComplete: true` automatically restart the VM.

### Stop-on-Error Behaviour

By default, Chaos Studio does not stop an experiment when a fault action fails. For production and pre-production experiments:

- Use the experiment `stopOnCriticalFailure` property (available via ARM/REST API) to halt all remaining steps when any fault action returns an error.
- Log all experiment events to Azure Log Analytics workspace for post-experiment review.

### Blast Radius Limits

| Limit Type | Rule | Rationale |
|---|---|---|
| Maximum concurrent VM shutdowns | ≤ 50% of broker count per region | Maintains quorum (3 of 6 brokers minimum) |
| ZooKeeper nodes targeted simultaneously | ≤ 1 (for non-quorum-loss scenarios) | Prevents total cluster unavailability |
| Regions affected simultaneously | 1 (Scenario 4 is the exception with explicit human approval) | Protects DR path |
| Experiment duration cap | 30 minutes maximum per run | Prevents extended production impact |
| `networkIsolation` fault | Never used in production — pre-prod only | Cannot be cancelled mid-run |

### Duration Limits

| Scenario | Recommended Duration | Maximum Allowed |
|---|---|---|
| Single broker shutdown | 5 minutes | 10 minutes |
| ZK quorum loss | 3 minutes | 5 minutes |
| Cross-region partition | 10 minutes | 15 minutes |
| Full region failure drill | 20 minutes | 30 minutes |
| CPU/memory pressure | 10 minutes | 20 minutes |
| Disk IO pressure | 10 minutes | 15 minutes |

### Manual Abort

All experiments can be cancelled at any time via:

```bash
az rest --method POST \
  --url "https://management.azure.com/subscriptions/{sub}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.Chaos/experiments/{experiment-name}/cancel?api-version=2023-11-01"
```

Or via the Azure Portal: Chaos Studio → Experiments → select experiment → Cancel.

### Safe Stopping Procedures

After any experiment — whether completed or aborted:

1. Verify all VM Shutdown targets have restarted (check VM health in Azure Monitor).
2. Confirm `ActiveControllerCount = 1` in Kafka JMX metrics.
3. Verify `UnderReplicatedPartitions = 0`.
4. Confirm Cluster Linking state = `ACTIVE` for all links.
5. Remove any manually injected NSG rules if not automatically cleaned up (NSG fault auto-reverts on experiment end).

---

## Integration with Web App Dashboard

The kafka-lab Next.js web application dashboard should display chaos experiment status alongside cluster health metrics.

### Dashboard View: Cluster Health Panel

The primary cluster health panel should expose:

| Indicator | Source | Visual Treatment |
|---|---|---|
| Chaos experiment active | Chaos Studio REST API | Red banner: "CHAOS EXPERIMENT ACTIVE — [experiment name]" |
| Under-replicated partitions | Prometheus / JMX | Gauge: 0 = green, > 0 = red |
| Active controller count | Prometheus / JMX | Badge: 1 = green, 0 or > 1 = red |
| Cluster Linking lag (scus→mxc) | Confluent metrics | Line chart, threshold line at 100,000 messages |
| Cluster Linking lag (mxc→cae) | Confluent metrics | Line chart, threshold line at 100,000 messages |
| VM health per region | Azure Monitor | Traffic-light indicators per region |

### Alert Thresholds for Visual Feedback

The dashboard should apply the following visual thresholds (green / amber / red):

| Metric | Green | Amber | Red |
|---|---|---|---|
| Under-replicated partitions | 0 | 1–5 | > 5 |
| Consumer lag | < 10,000 | 10,000–50,000 | > 50,000 |
| Cluster Linking lag | < 10,000 | 10,000–100,000 | > 100,000 |
| Request handler idle % | > 70% | 30–70% | < 30% |
| Broker VMs online (per region) | All | N-1 | N-2 or fewer |

### Chaos Event Timeline

A timeline overlay on all metric charts should annotate:

- Experiment start time (vertical dashed line, labelled with experiment name).
- Experiment end/abort time (vertical dashed line).
- Individual fault start/end events from Chaos Studio event log.

This enables direct visual correlation of metric deviations to injected faults.

---

## Example Experiment JSON

Complete experiment ARM JSON for **Scenario 1: Single Broker Failure** targeting `kafka-broker-scus-01`.

Replace `{subscriptionId}` and `{vmTargetResourceId}` with actual values.

```json
{
  "type": "Microsoft.Chaos/experiments",
  "apiVersion": "2023-11-01",
  "name": "kafka-broker-scus-single-failure",
  "location": "southcentralus",
  "identity": {
    "type": "SystemAssigned"
  },
  "properties": {
    "selectors": [
      {
        "type": "List",
        "id": "broker-scus-01",
        "targets": [
          {
            "id": "/subscriptions/{subscriptionId}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.Compute/virtualMachines/kafka-broker-scus-01/providers/Microsoft.Chaos/targets/Microsoft-VirtualMachine",
            "type": "ChaosTarget"
          }
        ]
      },
      {
        "type": "List",
        "id": "load-test-selector",
        "targets": [
          {
            "id": "/subscriptions/{subscriptionId}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.LoadTestService/loadTests/kafka-steady-state-load",
            "type": "ChaosTarget"
          }
        ]
      }
    ],
    "steps": [
      {
        "name": "Steady State Baseline",
        "branches": [
          {
            "name": "Delay",
            "actions": [
              {
                "type": "delay",
                "name": "urn:csci:microsoft:chaosStudio:timedDelay/1.0",
                "duration": "PT30S"
              }
            ]
          }
        ]
      },
      {
        "name": "Broker Failure",
        "branches": [
          {
            "name": "Shutdown broker-scus-01",
            "actions": [
              {
                "type": "continuous",
                "name": "urn:csci:microsoft:virtualMachine:shutdown/1.0",
                "parameters": [
                  { "key": "abruptShutdown", "value": "true" },
                  { "key": "restartWhenComplete", "value": "true" }
                ],
                "duration": "PT5M",
                "selectorId": "broker-scus-01"
              }
            ]
          },
          {
            "name": "Maintain load",
            "actions": [
              {
                "type": "continuous",
                "name": "urn:csci:microsoft:azureLoadTesting:startLoad/1.0",
                "parameters": [
                  { "key": "testRunId", "value": "chaos-broker-failure-run-01" }
                ],
                "duration": "PT7M",
                "selectorId": "load-test-selector"
              }
            ]
          }
        ]
      },
      {
        "name": "Recovery Observation",
        "branches": [
          {
            "name": "Wait for recovery",
            "actions": [
              {
                "type": "delay",
                "name": "urn:csci:microsoft:chaosStudio:timedDelay/1.0",
                "duration": "PT5M"
              }
            ]
          }
        ]
      }
    ]
  }
}
```

**Required role assignments for the experiment's system-assigned identity:**

```bash
# Get the experiment's system-assigned identity principal ID
PRINCIPAL_ID=$(az rest --method GET \
  --url "https://management.azure.com/subscriptions/{sub}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.Chaos/experiments/kafka-broker-scus-single-failure?api-version=2023-11-01" \
  --query "identity.principalId" --output tsv)

# Assign Virtual Machine Contributor to the target VM
az role assignment create \
  --assignee "$PRINCIPAL_ID" \
  --role "Virtual Machine Contributor" \
  --scope "/subscriptions/{sub}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.Compute/virtualMachines/kafka-broker-scus-01"
```

---

## References

1. Azure Chaos Studio Overview — <https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-overview>
2. Azure Chaos Studio Fault Library — <https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-fault-library>
3. Targets and Capabilities in Azure Chaos Studio — <https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-targets-capabilities>
4. Create an Agent-Based Experiment (Portal) — <https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-tutorial-agent-based-portal>
5. Create an Agent-Based Experiment (CLI) — <https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-tutorial-agent-based-cli>
6. Chaos Studio Supported Resource Types and Role Assignments — <https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-fault-providers>
7. Chaos Studio Permissions and Security — <https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-permissions-security>
8. Chaos Studio Fault Metrics and Dashboard (Workbook) — <https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-fault-metrics-and-dashboard>
9. Azure Chaos Studio Example Experiments — <https://learn.microsoft.com/en-us/azure/chaos-studio/experiment-examples>
10. Confluent Kafka Monitoring with JMX — <https://docs.confluent.io/platform/current/kafka/monitoring.html>
11. Configure Monitoring for Kafka on Azure AKS — <https://learn.microsoft.com/en-us/azure/aks/kafka-configure>
12. Chaos Engineering for Kafka: Testing Resilience — <https://klogic.io/blog/kafka-chaos-engineering-guide/>
13. Resilience Testing with Azure Chaos Studio: Compute Failures — <https://techcommunity.microsoft.com/blog/azuretoolsblog/resilience-testing-with-azure-chaos-studio-compute-failures/4389664>
