---
id: TASK-27.4
title: SP0.006 — Azure Virtual Networks and Private Networking
status: Done
assignee:
  - tester-9
created_date: '2026-03-30 15:20'
updated_date: '2026-03-30 16:01'
labels:
  - research
milestone: m-0
dependencies: []
references:
  - >-
    https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview
parent_task_id: TASK-27
priority: high
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Objective:** Research Azure VNet design for the kafka-lab multi-region deployment across southcentralus (primary), mexicocentral (secondary), and canadaeast (DR). Cover VNet peering, NSG rules, private endpoints, private DNS zones, and subnet design to support Kafka VMs, PaaS services, and the web application.\n\n**Sources:**\n- https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview\n- https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview\n- https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview\n- https://learn.microsoft.com/en-us/azure/dns/private-dns-overview\n- Azure Well-Architected Framework — networking pillar\n\n**Output:** A backlog document created via `backlog-document_create` containing:\n- Executive summary of networking architecture\n- VNet CIDR planning for 3 regions (non-overlapping address spaces)\n- Subnet design (Kafka brokers, ZooKeeper, Schema Registry, Connect, web app, private endpoints)\n- VNet peering configuration (global peering across regions)\n- NSG rules (inter-component traffic, deny-all-else default)\n- Private endpoint architecture for PaaS services (Storage, Key Vault)\n- Private DNS zone design (canonical Azure zone names, VNet links)\n- Network flow diagrams (broker-to-broker, client-to-broker, cross-region)\n- Example Terraform AzAPI resource definitions\n- References with URLs\n\n**Scope:**\n- Include: VNet CIDR planning, subnets, peering, NSGs, private endpoints, private DNS, network flows\n- Exclude: VM deployment details (SP0.007), Terraform provider setup (SP0.008), application-layer networking
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Document covers VNet CIDR planning for 3 regions with non-overlapping address spaces
- [x] #2 Document covers subnet design for all Kafka components and supporting services
- [x] #3 Document covers VNet peering configuration for cross-region connectivity
- [x] #4 Document covers NSG rules for inter-component and cross-region traffic
- [x] #5 Document covers private endpoint architecture for Azure PaaS services
- [x] #6 Document covers private DNS zone design with canonical Azure zone names and VNet links
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Coder] 2026-03-30T15:47:00Z
- Completed research for SP0.006 — Azure Virtual Networks and Private Networking
- Created backlog document: doc-10
- Sources consulted:
  - https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview
  - https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview
  - https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview
  - https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns
  - https://learn.microsoft.com/en-us/azure/dns/private-dns-overview
  - https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/Microsoft.Network_virtualNetworks
  - https://docs.confluent.io/operator/current/co-networking-overview.html
  - https://kafka.apache.org/documentation/#brokerconfigs_listeners
- Score self-assessment: Addressed all 6 AC items
  - AC1 ✅ VNet CIDR planning: 3 non-overlapping /16 address spaces (10.1/16, 10.2/16, 10.3/16)
  - AC2 ✅ Subnet design: 7 subnets per region covering all Kafka components and supporting services
  - AC3 ✅ VNet peering: full mesh, global peering, transitivity limitations documented
  - AC4 ✅ NSG rules: per-component NSGs with Kafka port tables (9092, 9093, 2181, 2888, 3888, 8081, 8083, 8089, 8090)
  - AC5 ✅ Private endpoint architecture: one PE per service, NIC IP assignment, DNS resolution flow
  - AC6 ✅ Private DNS zone design: canonical zone names, VNet links for all 3 regions, A record setup

## [Tester] 2026-03-30T16:00:00Z
- FAIL — Score: 93.65%
- Accuracy: 88/100 (30%) — Two factual errors: (1) The document (executive summary line, NSG note at end of NSG section, and Terraform code comment) states that `privateLinkServiceNetworkPolicies = "Disabled"` permits NSG enforcement on private endpoint NICs. This is incorrect. NSG enforcement on PE NICs is controlled by `privateEndpointNetworkPolicies`, and enabling it requires the value `"Enabled"` (or `"NetworkSecurityGroupEnabled"` in newer API versions). Setting `privateEndpointNetworkPolicies = "Disabled"` (the current code) means NSGs do NOT apply to PE NICs — the opposite of what the comment claims. (2) The HCL examples section contains a duplicate `resource "azapi_resource" "vnet_scus"` block (a leftover placeholder comment) which would cause `terraform validate` to fail with a duplicate resource error.
- Completeness: 95/100 (25%) — All 6 AC items fully addressed with tables, explanations, and cross-region coverage. No meaningful gaps.
- Sources: 98/100 (20%) — 10 primary references with full URLs; official Microsoft Learn, AzAPI Terraform registry, Confluent operator docs, Apache Kafka docs. Excellent sourcing.
- Documentation Quality: 96/100 (15%) — Strong executive summary, well-structured with clear headings, comprehensive tables throughout, and AzAPI HCL code examples. Minor deduction for the invalid duplicate resource block in the HCL section.
- Actionability: 95/100 (10%) — Project-specific CIDRs (10.1/16, 10.2/16, 10.3/16), project resource naming convention (klc-*), static private IP assignments per region per PE, per-component NSG port tables with exact Kafka/ZooKeeper/Schema Registry/Connect port numbers.
- Required improvements:
  1. **[Critical — Accuracy]** Replace the `privateLinkServiceNetworkPolicies = "Disabled"` claim with the correct guidance: to enable NSG rule enforcement on private endpoint NICs, set `privateEndpointNetworkPolicies = "Enabled"` (or `"NetworkSecurityGroupEnabled"` for API version 2023-05-01+) on the `snet-private-endpoints` subnet. Remove or correct the incorrect reference to `privateLinkServiceNetworkPolicies` (that property governs Private Link *service* provider resources, not endpoint consumers). Update the note in the NSG section, the executive summary sentence, and the Terraform code comment and value accordingly.
  2. **[Minor — Code Quality]** Remove the duplicate empty `resource "azapi_resource" "vnet_scus"` placeholder block in the peering section (currently at the second occurrence). Replace it with a plain comment like `// klc-vnet-mxc is declared in a separate file/module` if a reference note is desired.

## [TL] Cycle 2 guidance — tester FAIL 93.65%
- CRITICAL FIX: Replace `privateLinkServiceNetworkPolicies = "Disabled"` with `privateEndpointNetworkPolicies = "Enabled"` (or `"NetworkSecurityGroupEnabled"` for AzAPI 2023-05-01+). The current code disables NSG enforcement instead of enabling it. This is a security-critical fix.
- Remove the duplicate/empty `resource "azapi_resource" "vnet_scus"` placeholder block in the peering section — it would fail terraform validate.

## [Coder] 2026-03-30T16:15:00Z — Cycle 2
- Applied tester feedback: fixed privateEndpointNetworkPolicies (was incorrectly privateLinkServiceNetworkPolicies), removed duplicate HCL block
- Updated backlog document: doc-10
- Security-critical fix applied
- Changes made:
  1. Executive summary (line 15): replaced `privateLinkServiceNetworkPolicies: Disabled` → `privateEndpointNetworkPolicies: NetworkSecurityGroupEnabled`
  2. NSG section note (line 176): corrected to reference `privateEndpointNetworkPolicies = "NetworkSecurityGroupEnabled"` (or `"Enabled"` for older APIs); clarified `privateLinkServiceNetworkPolicies` governs Private Link service providers only
  3. Terraform code block: removed `privateLinkServiceNetworkPolicies = "Disabled"`, updated `privateEndpointNetworkPolicies` to `"NetworkSecurityGroupEnabled"`, fixed comment
  4. Peering section: removed duplicate `resource "azapi_resource" "vnet_scus"` placeholder block, replaced with plain comment `// klc-vnet-mxc is declared in a separate module`

## [Tester] 2026-03-30T16:30:00Z — Cycle 2 Review
- PASS — Score: 97.05%
- Accuracy: 97/100 (30%) — Both cycle 1 critical fixes confirmed:
  1. `privateEndpointNetworkPolicies = "NetworkSecurityGroupEnabled"` correctly set in executive summary (line 15), NSG note (line 176), and Terraform code (line 413). No remaining `privateLinkServiceNetworkPolicies` in any PE subnet context.
  2. Duplicate `resource "azapi_resource" "vnet_scus"` block removed; replaced with plain comment `// klc-vnet-mxc is declared in a separate module` as instructed. Only one `vnet_scus` declaration remains. All other technical facts remain correct: ZK ports (2181/2888/3888), Kafka ports (9092/9093), SR port (8081), Connect ports (8083/8089/8090), canonical DNS zone names, 6-peering full mesh, Global VNet peering Standard SKU limitation, non-transitive peering.
- Completeness: 97/100 (25%) — All 6 AC items fully addressed with tables, DNS resolution flow, per-region subnet layouts, and full NSG rule sets. No meaningful gaps in coverage.
- Sources: 98/100 (20%) — 12 primary references; official Microsoft Learn, AzAPI Terraform registry, Confluent operator docs, Apache Kafka docs, Azure CAF naming conventions.
- Documentation Quality: 96/100 (15%) — Strong executive summary, hierarchical headings, comprehensive tables, valid AzAPI HCL examples. Code is clean, no duplicate blocks.
- Actionability: 97/100 (10%) — Project-specific CIDRs, `klc-*` naming, static PE IPs per region, exact component port tables, AzAPI resource types with correct ARM types and API versions.
- Score: (97×0.30)+(97×0.25)+(98×0.20)+(96×0.15)+(97×0.10) = 29.10+24.25+19.60+14.40+9.70 = 97.05% ≥ 95% threshold → PASS
<!-- SECTION:NOTES:END -->
