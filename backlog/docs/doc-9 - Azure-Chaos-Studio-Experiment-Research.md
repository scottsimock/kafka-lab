---
id: doc-9
title: Azure Chaos Studio Experiment Research
type: other
created_date: '2026-03-28 18:25'
---
## Summary

Azure Chaos Studio is a fully managed chaos engineering service that enables fault injection against Azure resources to validate application resilience. It supports two fault injection models — service-direct (control-plane) and agent-based (guest-OS-level) — both orchestrated through declarative experiment definitions. For the Kafka Lab's multi-region Confluent Platform deployment, Chaos Studio can simulate AZ failures, region failures, VM-level resource pressure, and Kafka broker process kills using a combination of VMSS zone-scoped shutdown faults and the Chaos Agent extension on Ubuntu 22.04 LTS broker VMs.

## Key Findings

### Architecture Components

- **Experiments** are the top-level orchestration unit, composed of sequential **steps**, parallel **branches** within each step, and **actions** (faults or delays) within branches.
- **Targets** represent onboarded Azure resources. Each resource can have two target types enabled: `Microsoft-VirtualMachine` (service-direct) and `Microsoft-Agent` (agent-based). Targets must be explicitly enabled before experiments can reference them.
- **Capabilities** are fine-grained permissions on a target that authorize specific fault types (e.g., `Shutdown-1.0`, `CPUPressure-1.0`). Each capability must be enabled per-target.
- **Selectors** logically group targets within an experiment so a single action can reference multiple VMs (e.g., all brokers in Zone 1).

### Service-Direct vs Agent-Based Faults

| Aspect | Service-Direct | Agent-Based |
|---|---|---|
| Execution plane | Azure control plane (ARM) | Guest OS via Chaos Agent |
| Agent required | No | Yes — `ChaosAgentLinux` VM extension |
| Fault examples | VM shutdown, VMSS zone shutdown | CPU pressure, memory pressure, network disconnect, process kill, disk I/O pressure |
| OS visibility | None — operates at infrastructure level | Full — can target processes, network stack, memory |
| Use case | Simulating infrastructure failures (power loss, AZ down) | Simulating application-level and OS-level degradation |
| Target type | `Microsoft-VirtualMachine` | `Microsoft-Agent` |

**Key distinction:** Service-direct faults cannot see inside the VM. To kill a Kafka broker process or simulate CPU pressure, the Chaos Agent must be installed. Service-direct faults are required for hard VM shutdown where the guest OS does not participate.

### Fault Provider Catalog (Kafka Lab Relevant)

| Fault | URN | Type | Key Parameters |
|---|---|---|---|
| VM Shutdown | `urn:csci:microsoft:virtualMachine:shutdown/1.0` | Service-direct (discrete) | `abruptShutdown` (bool) — `true` simulates hard power-off |
| VMSS Zone Shutdown | `urn:csci:microsoft:virtualMachineScaleSet:shutdown/1.0` | Service-direct (discrete) | `abruptShutdown`, zone selector |
| CPU Pressure | `urn:csci:microsoft:agent:cpuPressure/1.0` | Agent-based (continuous) | `pressureLevel` (int, 0–99, percentage) |
| Memory Pressure | `urn:csci:microsoft:agent:memoryPressure/1.0` | Agent-based (continuous) | `virtualMemoryInMB` (int) or percentage-based |
| Network Disconnect | `urn:csci:microsoft:agent:networkDisconnect/1.0` | Agent-based (continuous) | `destinationFilters` (optional), `direction` (outbound on Linux) |
| Kill Process | `urn:csci:microsoft:agent:killProcess/1.0` | Agent-based (continuous) | `processName` (string, required) |
| Disk I/O Pressure | `urn:csci:microsoft:agent:linuxDiskIOPressure/1.0` | Agent-based (continuous) | `workerCount`, `fileSizeInKB` |
| Network Latency | `urn:csci:microsoft:agent:networkLatency/1.0` | Agent-based (continuous) | `latencyInMilliseconds`, `destinationFilters` |
| Network Packet Loss | `urn:csci:microsoft:agent:networkPacketLoss/1.0` | Agent-based (continuous) | `lossPercentage`, `destinationFilters` |

### AZ-Level Failure Design

Chaos Studio supports **dynamic targeting** for VMSS resources, allowing zone-scoped fault injection. Using the `urn:csci:microsoft:virtualMachineScaleSet:shutdown/1.0` fault, you can target all instances in a specific Availability Zone within a VMSS.

For the Kafka Lab's individual VMs (not VMSS), AZ targeting requires **manual selector grouping**: place all VMs in Zone 1 into one selector, Zone 2 into another. The experiment step then references the zone-specific selector to shut down all VMs in that zone simultaneously.

**Recommended approach for individual VMs:**

```json
"selectors": [
  {
    "id": "zone1-brokers",
    "type": "List",
    "targets": [
      { "type": "ChaosTarget", "id": "/subscriptions/{sub}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.Compute/virtualMachines/kafka-broker-scus-z1-0/providers/Microsoft.Chaos/targets/Microsoft-VirtualMachine" },
      { "type": "ChaosTarget", "id": "/subscriptions/{sub}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.Compute/virtualMachines/kafka-broker-scus-z1-1/providers/Microsoft.Chaos/targets/Microsoft-VirtualMachine" },
      { "type": "ChaosTarget", "id": "/subscriptions/{sub}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.Compute/virtualMachines/kafka-broker-scus-z1-2/providers/Microsoft.Chaos/targets/Microsoft-VirtualMachine" }
    ]
  }
]
```

### Region-Level Failure Design

A region failure experiment shuts down **all VMs across all zones** in a target region. Two approaches:

1. **Full VM shutdown** — Create a selector containing every VM in the target region (e.g., all 3 brokers in `mexicocentral`). Use `urn:csci:microsoft:virtualMachine:shutdown/1.0` with `abruptShutdown: true`.
2. **Network isolation** — Use the agent-based `networkDisconnect` fault on all VMs in the region to sever cross-region replication traffic without powering down. This simulates a network partition rather than a full outage. On Linux, the disconnect affects outbound traffic (IPv4 only).

**For cross-region network blocking**, the `networkDisconnect` fault with `destinationFilters` can target specific IP ranges corresponding to other regions. Alternatively, NSG manipulation via Azure Policy or scripted NSG rule injection (outside Chaos Studio) provides more surgical control.

### VM-Level Fault Configurations

#### VM Shutdown (Hard Power-Off)

```json
{
  "name": "urn:csci:microsoft:virtualMachine:shutdown/1.0",
  "type": "discrete",
  "selectorId": "target-broker",
  "parameters": [
    { "key": "abruptShutdown", "value": "true" }
  ]
}
```

#### CPU Pressure (95% for 10 Minutes)

```json
{
  "name": "urn:csci:microsoft:agent:cpuPressure/1.0",
  "type": "continuous",
  "duration": "PT10M",
  "selectorId": "target-broker",
  "parameters": [
    { "key": "pressureLevel", "value": "95" }
  ]
}
```

#### Memory Pressure

```json
{
  "name": "urn:csci:microsoft:agent:memoryPressure/1.0",
  "type": "continuous",
  "duration": "PT10M",
  "selectorId": "target-broker",
  "parameters": [
    { "key": "virtualMemoryInMB", "value": "8192" }
  ]
}
```

#### Network Disconnect (Full Outbound)

```json
{
  "name": "urn:csci:microsoft:agent:networkDisconnect/1.0",
  "type": "continuous",
  "duration": "PT5M",
  "selectorId": "target-broker",
  "parameters": []
}
```

### Kafka Broker Process Kill Design

The Chaos Agent `killProcess` fault terminates processes by name. For Confluent Platform brokers running as a systemd service, the process name visible to `ps` is `java` (the Kafka broker JVM process). However, killing the `java` process may be ambiguous if other Java processes run on the same VM.

**Recommended approach:** Use `killProcess` with `processName` set to the Kafka broker's identifiable process, or combine with a custom script action. The agent runs with root privileges and can target processes by name.

```json
{
  "name": "urn:csci:microsoft:agent:killProcess/1.0",
  "type": "continuous",
  "duration": "PT1M",
  "selectorId": "kafka-broker-target",
  "parameters": [
    { "key": "processName", "value": "java" }
  ]
}
```

**Alternative approach:** Use the `linuxScript` fault capability (if available) to execute `systemctl stop confluent-kafka` for a cleaner, more targeted broker shutdown. This avoids ambiguity with multiple Java processes.

### Experiment Sequencing and Observation Strategy

#### Sequencing via Steps and Branches

- **Steps** execute sequentially — use them to chain fault injection phases (e.g., inject fault → wait → verify recovery).
- **Branches** within a step execute in parallel — use them for simultaneous multi-target faults (e.g., kill brokers in Zone 1 and Zone 2 concurrently).
- **Delay actions** (`urn:csci:microsoft:chaosStudio:timedDelay/1.0`) insert pauses between steps for observation.

#### Example: Multi-Phase Experiment

```text
Step 1: Inject AZ-1 failure (shutdown Zone 1 brokers)
Step 2: Delay 5 minutes (observe failover)
Step 3: Restore (VMs auto-restart or manual start)
Step 4: Delay 5 minutes (observe rebalance)
```

#### Observation via Azure Monitor

1. **Diagnostic Settings** — Enable diagnostic settings on the Chaos experiment resource to emit experiment lifecycle events (start, stop, fault injection, completion) to a Log Analytics workspace.
2. **Azure Workbooks** — Create a centralized workbook with parameters for subscription, resource group, and target resource. Overlay Chaos experiment events with VM metrics (CPU, memory, network I/O, disk) and Kafka-specific metrics (under-replicated partitions, ISR shrink rate, request latency).
3. **Metric Alerts** — Configure Azure Monitor alerts on steady-state SLO violations (e.g., Kafka produce latency > 500ms, consumer lag > 10,000). Use alert rules to auto-cancel experiments if blast radius exceeds expectations.
4. **Application Insights** — If producer/consumer applications are instrumented, correlate application-level errors with chaos injection timestamps.

### RBAC and UAMI Requirements

#### Experiment Identity

Every Chaos Studio experiment requires a managed identity. Per the Kafka Lab's compliance requirements, use a **User Assigned Managed Identity (UAMI)**.

#### Required RBAC Role Assignments

| Target Resource Type | Required Role | Scope |
|---|---|---|
| Virtual Machine (shutdown) | `Virtual Machine Contributor` | Target VM or resource group |
| Virtual Machine (agent faults) | `Reader` | Target VM or resource group |
| Network (NSG manipulation) | `Network Contributor` | Target NIC or NSG resource |
| Chaos experiment management | `Chaos Studio Operator` | Experiment resource or resource group |

- The UAMI must be assigned **Virtual Machine Contributor** on every target VM for service-direct shutdown faults.
- For agent-based faults (CPU, memory, process kill), the UAMI needs **Reader** on the target VM plus the Chaos Agent must be installed and running.
- Grant roles at the **resource group scope** (`klc-rg-kafkalab-scus`) for simplicity, or at individual VM scope for tighter least-privilege control.

#### Agent Onboarding

Install the Chaos Agent on every Kafka broker VM:

```bash
az vm extension set \
  --resource-group klc-rg-kafkalab-scus \
  --vm-name kafka-broker-scus-z1-0 \
  --name ChaosAgentLinux \
  --publisher Microsoft.Azure.Chaos \
  --version 1.0 \
  --settings '{"profile": {"appInsightsInstrumentationKey": ""}}' \
  --protected-settings '{"authKey": "<agent-auth-key>"}'
```

Enable both target types on each VM:

```bash
// Enable service-direct target
az rest --method put \
  --url "https://management.azure.com/subscriptions/{sub}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.Compute/virtualMachines/{vm}/providers/Microsoft.Chaos/targets/Microsoft-VirtualMachine?api-version=2024-01-01" \
  --body '{"properties": {}}'

// Enable agent-based target
az rest --method put \
  --url "https://management.azure.com/subscriptions/{sub}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.Compute/virtualMachines/{vm}/providers/Microsoft.Chaos/targets/Microsoft-Agent?api-version=2024-01-01" \
  --body '{"properties": {}}'
```

## Architecture / Design Decisions

### Decision 1: Use UAMI Per Experiment Category

**Decision:** Provision one UAMI per experiment category (AZ-failure, region-failure, VM-level, Kafka-level) rather than one shared UAMI for all experiments.

**Rationale:** Aligns with the project's compliance requirement of one UAMI per workflow. Each experiment category has different permission requirements (e.g., VM-level needs only VM Contributor; network isolation may need Network Contributor). Separate identities enable tighter least-privilege control and cleaner audit trails.

### Decision 2: Individual VMs with List Selectors (Not VMSS Dynamic Targeting)

**Decision:** Use explicit List-type selectors grouping individual VMs by zone/region rather than VMSS dynamic targeting.

**Rationale:** The Kafka Lab deploys individual VMs (not VMSS) for Confluent Platform brokers. VMSS dynamic zone targeting is unavailable for standalone VMs. List selectors with zone-based grouping achieve the same zone-scoped blast radius with explicit, auditable target lists.

### Decision 3: Dual-Mode Target Onboarding

**Decision:** Enable both `Microsoft-VirtualMachine` (service-direct) and `Microsoft-Agent` (agent-based) target types on every Kafka broker VM.

**Rationale:** The experiment catalog requires both service-direct faults (hard VM shutdown for AZ/region failure) and agent-based faults (CPU pressure, process kill for Kafka-level testing). Dual-mode onboarding avoids re-onboarding when experiment scope expands.

### Decision 4: Process Kill via `java` Process Name with Guard Rails

**Decision:** Use `killProcess` with `processName: "java"` for Kafka broker process kill experiments, constrained to single-broker VMs where Kafka is the only Java process.

**Rationale:** Confluent Kafka brokers run as JVM processes. The `killProcess` fault matches by process name. Since each Kafka broker VM runs only the Kafka JVM (no other Java services), `java` is unambiguous. If multi-process VMs are introduced later, switch to a script-based approach.

### Decision 5: Azure Monitor Integration with Auto-Cancel

**Decision:** Configure Diagnostic Settings on every experiment resource to emit to a shared Log Analytics workspace. Set up alert-driven auto-cancellation for SLO breaches.

**Rationale:** Provides the "single pane of glass" for correlating fault injection with system health. Auto-cancel is a safety net preventing runaway experiments from causing extended outages in the lab environment.

## Configuration Reference

### Full Experiment Template: AZ-1 Failure (southcentralus Zone 1)

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "resources": [
    {
      "type": "Microsoft.Chaos/experiments",
      "apiVersion": "2024-01-01",
      "name": "kafka-lab-az1-failure",
      "location": "southcentralus",
      "identity": {
        "type": "UserAssigned",
        "userAssignedIdentities": {
          "/subscriptions/{sub}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uami-chaos-az-failure": {}
        }
      },
      "properties": {
        "selectors": [
          {
            "id": "scus-zone1-brokers",
            "type": "List",
            "targets": [
              {
                "type": "ChaosTarget",
                "id": "/subscriptions/{sub}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.Compute/virtualMachines/kafka-broker-scus-z1-0/providers/Microsoft.Chaos/targets/Microsoft-VirtualMachine"
              },
              {
                "type": "ChaosTarget",
                "id": "/subscriptions/{sub}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.Compute/virtualMachines/kafka-broker-scus-z1-1/providers/Microsoft.Chaos/targets/Microsoft-VirtualMachine"
              },
              {
                "type": "ChaosTarget",
                "id": "/subscriptions/{sub}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.Compute/virtualMachines/kafka-broker-scus-z1-2/providers/Microsoft.Chaos/targets/Microsoft-VirtualMachine"
              }
            ]
          }
        ],
        "steps": [
          {
            "name": "Shutdown Zone 1 Brokers",
            "branches": [
              {
                "name": "zone1-shutdown",
                "actions": [
                  {
                    "name": "urn:csci:microsoft:virtualMachine:shutdown/1.0",
                    "type": "discrete",
                    "selectorId": "scus-zone1-brokers",
                    "parameters": [
                      { "key": "abruptShutdown", "value": "true" }
                    ]
                  }
                ]
              }
            ]
          },
          {
            "name": "Observe Failover",
            "branches": [
              {
                "name": "delay",
                "actions": [
                  {
                    "name": "urn:csci:microsoft:chaosStudio:timedDelay/1.0",
                    "type": "delay",
                    "duration": "PT5M"
                  }
                ]
              }
            ]
          }
        ]
      }
    }
  ]
}
```

### Kafka Broker Process Kill Experiment Snippet

```json
{
  "type": "Microsoft.Chaos/experiments",
  "apiVersion": "2024-01-01",
  "name": "kafka-lab-broker-kill",
  "location": "southcentralus",
  "identity": {
    "type": "UserAssigned",
    "userAssignedIdentities": {
      "/subscriptions/{sub}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uami-chaos-kafka-level": {}
    }
  },
  "properties": {
    "selectors": [
      {
        "id": "single-broker",
        "type": "List",
        "targets": [
          {
            "type": "ChaosTarget",
            "id": "/subscriptions/{sub}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.Compute/virtualMachines/kafka-broker-scus-z1-0/providers/Microsoft.Chaos/targets/Microsoft-Agent"
          }
        ]
      }
    ],
    "steps": [
      {
        "name": "Kill Kafka Broker Process",
        "branches": [
          {
            "name": "process-kill",
            "actions": [
              {
                "name": "urn:csci:microsoft:agent:killProcess/1.0",
                "type": "continuous",
                "duration": "PT1M",
                "selectorId": "single-broker",
                "parameters": [
                  { "key": "processName", "value": "java" }
                ]
              }
            ]
          }
        ]
      },
      {
        "name": "Observe Recovery",
        "branches": [
          {
            "name": "delay",
            "actions": [
              {
                "name": "urn:csci:microsoft:chaosStudio:timedDelay/1.0",
                "type": "delay",
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

### Target Onboarding ARM Template

```json
{
  "type": "Microsoft.Compute/virtualMachines/providers/targets",
  "apiVersion": "2024-01-01",
  "name": "{vmName}/Microsoft.Chaos/Microsoft-VirtualMachine",
  "location": "southcentralus",
  "properties": {},
  "resources": [
    {
      "type": "capabilities",
      "apiVersion": "2024-01-01",
      "name": "Shutdown-1.0",
      "properties": {}
    }
  ]
}
```

```json
{
  "type": "Microsoft.Compute/virtualMachines/providers/targets",
  "apiVersion": "2024-01-01",
  "name": "{vmName}/Microsoft.Chaos/Microsoft-Agent",
  "location": "southcentralus",
  "properties": {
    "agentProfileId": "/subscriptions/{sub}/resourceGroups/klc-rg-kafkalab-scus/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uami-chaos-agent"
  },
  "resources": [
    {
      "type": "capabilities",
      "apiVersion": "2024-01-01",
      "name": "CPUPressure-1.0",
      "properties": {}
    },
    {
      "type": "capabilities",
      "apiVersion": "2024-01-01",
      "name": "MemoryPressure-1.0",
      "properties": {}
    },
    {
      "type": "capabilities",
      "apiVersion": "2024-01-01",
      "name": "NetworkDisconnect-1.0",
      "properties": {}
    },
    {
      "type": "capabilities",
      "apiVersion": "2024-01-01",
      "name": "KillProcess-1.0",
      "properties": {}
    }
  ]
}
```

## Risks and Open Questions

### Risks

1. **Process name ambiguity** — The `killProcess` fault matches by process name (`java`). If any non-Kafka Java process is introduced on broker VMs, this fault would kill it too. Mitigation: enforce single-purpose VMs or investigate script-based alternatives.
2. **Network disconnect scope on Linux** — The agent-based `networkDisconnect` fault only affects outbound IPv4 traffic on Linux. Inbound connections already established may persist. This may not fully simulate a network partition for Kafka inter-broker replication (which uses bidirectional TCP). Mitigation: combine with NSG rule injection for complete isolation.
3. **No native cross-region network fault** — Chaos Studio does not provide a built-in fault for blocking traffic between specific Azure regions. Simulating a region-level network partition requires either full VM shutdown or external NSG manipulation. Mitigation: use VM shutdown for region failure experiments; consider Azure Policy or automation runbooks for surgical network partitioning.
4. **Agent availability during fault** — The Chaos Agent itself runs on the target VM. If the VM is shut down via service-direct fault, the agent cannot report status. Observation must rely on Azure Monitor metrics and external health probes rather than agent telemetry.
5. **Experiment blast radius control** — Without proper selector scoping, an experiment could inadvertently target VMs outside the intended blast radius. Mitigation: use explicit List selectors, tag-based validation, and pre-flight dry-run reviews.

### Open Questions

1. **Can `killProcess` accept a systemd service name instead of a process name?** — Documentation indicates process name matching via `ps`. Need to test whether `confluent-kafka` (the systemd unit) or `java` (the actual process) is the correct value. Verify in a sandbox.
2. **Does Chaos Studio support experiment scheduling (cron-like)?** — Useful for running resilience experiments on a recurring schedule (e.g., weekly AZ failure test). Need to investigate if native scheduling exists or if Azure Logic Apps / Azure Automation must orchestrate experiment starts.
3. **What is the maximum experiment duration?** — Documentation does not clearly state upper limits. Long-running experiments (e.g., multi-hour region failure simulation) may have timeout constraints.
4. **How does VMSS dynamic targeting interact with individual VMs?** — The lab uses individual VMs. If a future migration to VMSS occurs, experiment definitions will need restructuring.
5. **Can multiple experiments run concurrently against the same target?** — Need to verify whether Chaos Studio enforces single-experiment-per-target or allows stacking faults (e.g., CPU pressure + network latency on the same VM).
6. **What are the costs?** — Chaos Studio pricing for experiment execution and agent usage should be evaluated for the lab's budget.

## References

- [Azure Chaos Studio Overview](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-overview)
- [Chaos Studio Fault and Action Library](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-fault-library)
- [Chaos Experiments in Azure Chaos Studio](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-chaos-experiments)
- [Targets and Capabilities in Azure Chaos Studio](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-targets-capabilities)
- [Faults and Actions in Azure Chaos Studio](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-faults-actions)
- [Permissions and Security in Azure Chaos Studio](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-permissions-security)
- [Assigning Experiment Permissions](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-assign-experiment-permissions)
- [Set Up Azure Monitor for a Chaos Studio Experiment](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-set-up-azure-monitor)
- [Measure Fault Impact with an Azure Workbook](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-fault-metrics-and-dashboard)
- [ARM Template Samples for Chaos Studio Experiments](https://learn.microsoft.com/en-us/azure/chaos-studio/sample-template-experiment)
- [Create an Agent-Based Fault Experiment (Portal)](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-tutorial-agent-based-portal)
- [Create an Agent-Based Fault Experiment (CLI)](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-tutorial-agent-based-cli)
- [Dynamic Targeting: Shut Down All Targets in a Zone](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-tutorial-dynamic-target-portal)
- [AZ Down Experiment Template](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-tutorial-availability-zone-down-portal)
- [Target Selection in Azure Chaos Studio](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-target-selection)
- [Efficient Identity Management in Azure Chaos Studio](https://techcommunity.microsoft.com/blog/azuregovernanceandmanagementblog/efficient-identity-management-in-azure-chaos-studio-for-secure-fault-injection/3935575)
