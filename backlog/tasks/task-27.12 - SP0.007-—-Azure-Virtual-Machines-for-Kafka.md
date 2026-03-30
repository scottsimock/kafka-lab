---
id: TASK-27.12
title: SP0.007 — Azure Virtual Machines for Kafka
status: Done
assignee:
  - tester-13
created_date: '2026-03-30 15:22'
updated_date: '2026-03-30 16:07'
labels:
  - research
milestone: m-0
dependencies: []
references:
  - 'https://learn.microsoft.com/en-us/azure/virtual-machines/overview'
parent_task_id: TASK-27
priority: high
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Objective:** Research Azure VM deployment patterns for Kafka workloads, covering VM sizing, disk configuration, availability zone placement, and accelerated networking. This research informs the Terraform modules that provision Kafka infrastructure VMs across the project's regions and availability zones.\n\n**Sources:**\n- https://learn.microsoft.com/en-us/azure/virtual-machines/overview\n- https://learn.microsoft.com/en-us/azure/virtual-machines/dv5-dsv5-series\n- https://learn.microsoft.com/en-us/azure/virtual-machines/disks-types\n- https://learn.microsoft.com/en-us/azure/virtual-machines/accelerated-networking-overview\n- Confluent Platform system requirements and recommendations\n\n**Output:** A backlog document created via `backlog-document_create` containing:\n- Executive summary of VM strategy for Kafka workloads\n- VM sizing rationale per component (brokers D4s_v5: 4 vCPU/16 GB, ZK/SR/Connect D2s_v5: 2 vCPU/8 GB)\n- Disk configuration (OS disk, data disks for Kafka logs, Premium SSD vs Ultra Disk)\n- Availability zone placement (scus Zone 1 primary, Zone 2 HA, mexicocentral Zone 1, canadaeast Zone 1)\n- Accelerated networking configuration\n- NIC configuration (single NIC, private IP, DNS settings)\n- OS hardening (Ubuntu 22.04 LTS, kernel tuning: vm.swappiness, net.core.somaxconn, file descriptors)\n- Cloud-init or custom data for initial VM setup\n- Example Terraform AzAPI resource definitions\n- References with URLs\n\n**Scope:**\n- Include: VM sizing, disk config, AZ placement, accelerated networking, OS hardening, NIC config\n- Exclude: VNet/subnet design (SP0.006), Ansible configuration (SP0.009), application deployment
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Document covers VM sizing rationale for each component (D4s_v5 brokers, D2s_v5 ZK/SR/Connect)
- [ ] #2 Document covers disk types and sizing recommendations (Premium SSD, Ultra Disk, data vs OS vs log disks)
- [ ] #3 Document covers availability zone placement strategy across scus Zone 1/2
- [ ] #4 Document covers accelerated networking configuration and NIC settings
- [ ] #5 Document covers OS hardening baseline (Ubuntu 22.04 LTS, kernel tuning for Kafka)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Coder] 2026-03-30T11:53:00 EDT
- Completed research for SP0.007 — Azure Virtual Machines for Kafka
- Created backlog document: doc-12
- Sources consulted:
  - https://learn.microsoft.com/en-us/azure/virtual-machines/dv5-dsv5-series
  - https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dsv5-series
  - https://learn.microsoft.com/en-us/azure/virtual-machines/disks-types
  - https://learn.microsoft.com/en-us/azure/virtual-network/accelerated-networking-overview
  - https://docs.confluent.io/platform/current/kafka/deployment.html
  - https://axonops.com/docs/data-platforms/kafka/cloud/azure/
  - https://learn.microsoft.com/en-us/azure/virtual-machines/premium-storage-performance
- Score self-assessment: Addressed all 5 AC items
  - AC#1: VM sizing rationale table (D4s_v5 brokers, D2s_v5 ZK/SR/Connect) ✓
  - AC#2: Disk types and sizing (Premium SSD P30/P40, Ultra Disk, Premium SSD v2, OS vs data disks) ✓
  - AC#3: AZ placement strategy (scus Zone 1 primary, Zone 2 HA, mexicocentral Zone 1, canadaeast Zone 1) ✓
  - AC#4: Accelerated Networking (SR-IOV, requirements, NIC config, latency impact) ✓
  - AC#5: OS hardening baseline (Ubuntu 22.04 LTS, kernel tuning, file descriptors, THP, disk scheduler, chrony) ✓

## [Tester] 2026-03-30T12:10:00 EDT
- FAIL — Score: 94.5%
- Accuracy: 92/100 (30%) — One clear inconsistency between documented recommendation and Terraform example: the NIC section text states "Private IP assigned statically from the subnet address space (set `privateIPAllocationMethod: Static` in the Terraform resource)" but the AzAPI NIC code block uses `privateIPAllocationMethod = "Dynamic"`. For Kafka brokers, static private IPs are production-critical; this contradiction would confuse implementers and could result in IP churn on VM restart.
- Completeness: 98/100 (25%) — All 5 AC items fully addressed with additional bonus content (cloud-init YAML, full Terraform AzAPI example, Java setup). ZooKeeper quorum distribution and rack-awareness configuration are included beyond what was required.
- Sources: 90/100 (20%) — 7 of 9 references are official Microsoft Azure or Confluent primary sources. Two supplementary sources (axonops.com vendor docs and NetApp's Confluent sizing guide) are not primary/authoritative. No critical claims depend solely on these non-primary sources, but replacing or supplementing them with official Microsoft or Confluent documentation would strengthen the reference set.
- Documentation Quality: 98/100 (15%) — Excellent: executive summary present, clear heading hierarchy, effective use of tables throughout, full code examples (sysctl, limits.d, udev rules, cloud-init YAML, Terraform HCL), and inline explanatory notes on each block.
- Actionability: 97/100 (10%) — Highly specific: exact VM SKUs, disk tier and size, IOPS/throughput figures, JVM heap values (-Xms6g/-Xmx6g), all kernel parameter values, complete cloud-init YAML ready for use, and broker.rack configuration included. Minor deduction only because the Static/Dynamic NIC issue (see Accuracy) affects direct usability of the Terraform example.
- Required improvements:
  1. Fix the NIC Terraform example: change `privateIPAllocationMethod = "Dynamic"` to `privateIPAllocationMethod = "Static"` to match the stated recommendation in the NIC Configuration prose section. Optionally add a `privateIPAddress` variable to show how to pin the IP.
  2. Replace or supplement axonops.com and the NetApp Confluent sizing guide with primary Microsoft or Confluent sources (e.g., the official Confluent Platform sizing docs at https://docs.confluent.io/platform/current/kafka/sizing.html, or the Azure premium-storage-performance page already cited elsewhere in the document).

## [TL] Cycle 2 guidance — tester FAIL 94.5%
- Fix NIC static IP: prose says privateIPAllocationMethod: Static but code uses Dynamic. Change the AzAPI NIC code block to use `"Static"` and include a `privateIPAddress` variable.
- Replace non-primary sources: replace axonops.com and NetApp references with official Confluent or Microsoft primary docs (e.g., https://docs.confluent.io/platform/current/kafka/sizing.html).

## [Coder] 2026-03-30T12:20:00 EDT — Cycle 2
- Fixed NIC static IP allocation in AzAPI example: changed `privateIPAllocationMethod = "Dynamic"` to `"Static"` and added `privateIPAddress = var.broker_private_ip` to pin the IP
- Replaced non-primary sources (axonops.com, NetApp) with official primary sources:
  - Confluent Platform Sizing Guide: https://docs.confluent.io/platform/current/kafka/sizing.html
  - Azure VM Networking — NIC reference: https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-network-interface
- Updated doc-12 directly on disk (file-based backlog)

## [Tester] 2026-03-30T12:35:00 EDT — Cycle 2 Review
- PASS — Score: 99.4%
- **Accuracy: 99/100 (×0.30 = 29.7)** — Both cycle 2 fixes verified in document:
  1. NIC code block line 427: `privateIPAllocationMethod = "Static"` — now consistent with prose at line 129. `privateIPAddress = var.broker_private_ip` also added to demonstrate IP pinning. ✓
  2. Non-primary sources replaced: axonops.com → `https://docs.confluent.io/platform/current/kafka/sizing.html`; NetApp → `https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-network-interface`. ✓
  Minor: last references-table entry label reads "Azure VM Networking — Accelerated Networking" but URL targets the NIC overview page (`virtual-network-network-interface`); accelerated networking is already separately cited at line 548. Trivial labeling mismatch only, no material inaccuracy.
- **Completeness: 100/100 (×0.25 = 25.0)** — All 5 AC items fully met plus bonus content (cloud-init YAML, full Terraform AzAPI example, ZooKeeper quorum distribution, rack-awareness config).
- **Sources: 100/100 (×0.20 = 20.0)** — All 9 references are now official Microsoft Azure or Confluent primary sources. Zero non-authoritative sources remain.
- **Documentation Quality: 98/100 (×0.15 = 14.7)** — Executive summary present, clear heading hierarchy, effective tables, full code examples (sysctl, limits.d, udev, cloud-init YAML, Terraform HCL). Minor: reference label/URL mismatch noted above.
- **Actionability: 100/100 (×0.10 = 10.0)** — Exact VM SKUs, disk tiers, IOPS/throughput figures, JVM heap values, all kernel parameters, complete cloud-init YAML ready for use. Static IP fix resolves prior Terraform usability deduction.
- **Total: 99.4% — PASS (threshold 95%)**
<!-- SECTION:NOTES:END -->
