---
id: TASK-28.5
title: SP1.005 — Virtual Network Module with Subnets
status: To Do
assignee: []
created_date: '2026-03-30 16:40'
updated_date: '2026-03-30 16:40'
labels:
  - story
milestone: m-1
dependencies:
  - TASK-28.1
references:
  - terraform/modules/virtual-network/
documentation:
  - doc-10
parent_task_id: TASK-28
priority: high
ordinal: 1005
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable Terraform module at terraform/modules/virtual-network/ that provisions an Azure VNet using azapi_resource with type Microsoft.Network/virtualNetworks. For the dev environment, create the southcentralus VNet (klc-vnet-scus, 10.1.0.0/16) with 7 subnets per the research doc: snet-kafka-brokers (10.1.1.0/24), snet-zookeeper (10.1.2.0/24), snet-schema-registry (10.1.3.0/24), snet-connect (10.1.4.0/24), snet-web-app (10.1.5.0/24), snet-private-endpoints (10.1.6.0/24), snet-management (10.1.7.0/24). Enable private endpoint network policies on snet-private-endpoints.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Module exists at terraform/modules/virtual-network/
- [ ] #2 Uses azapi_resource with Microsoft.Network/virtualNetworks
- [ ] #3 Creates VNet klc-vnet-scus with 10.1.0.0/16 address space
- [ ] #4 Creates 7 subnets: snet-kafka-brokers, snet-zookeeper, snet-schema-registry, snet-connect, snet-web-app, snet-private-endpoints, snet-management
- [ ] #5 Subnet CIDRs match research doc-10 specifications
- [ ] #6 privateEndpointNetworkPolicies set to NetworkSecurityGroupEnabled on snet-private-endpoints
- [ ] #7 Outputs vnet_id, vnet_name, and subnet_ids map
- [ ] #8 terraform validate passes
<!-- AC:END -->
