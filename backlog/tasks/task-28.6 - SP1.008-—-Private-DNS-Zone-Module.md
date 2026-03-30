---
id: TASK-28.6
title: SP1.008 — Private DNS Zone Module
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
  - terraform/modules/private-dns-zone/
documentation:
  - doc-10
parent_task_id: TASK-28
priority: medium
ordinal: 1008
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable Terraform module at terraform/modules/private-dns-zone/ that provisions an Azure Private DNS Zone using azapi_resource with type Microsoft.Network/privateDnsZones and links it to a VNet via Microsoft.Network/privateDnsZones/virtualNetworkLinks. The module accepts zone_name, resource_group_id, vnet_id, and tags. Output dns_zone_id and dns_zone_name.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Module exists at terraform/modules/private-dns-zone/
- [ ] #2 Uses azapi_resource with Microsoft.Network/privateDnsZones
- [ ] #3 Creates VNet link via Microsoft.Network/privateDnsZones/virtualNetworkLinks
- [ ] #4 Outputs dns_zone_id and dns_zone_name
- [ ] #5 terraform validate passes
<!-- AC:END -->
