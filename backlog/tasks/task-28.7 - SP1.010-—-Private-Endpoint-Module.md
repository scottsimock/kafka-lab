---
id: TASK-28.7
title: SP1.010 — Private Endpoint Module
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
  - terraform/modules/private-endpoint/
documentation:
  - doc-10
  - doc-14
parent_task_id: TASK-28
priority: medium
ordinal: 1010
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable Terraform module at terraform/modules/private-endpoint/ that provisions an Azure Private Endpoint using azapi_resource with type Microsoft.Network/privateEndpoints. The module creates a private endpoint in the snet-private-endpoints subnet, connects to the target resource via privateLinkServiceConnections, and creates a privateDnsZoneGroups child resource for automatic DNS A record registration. Accept target_resource_id, subnet_id, group_ids, dns_zone_id, and tags. Output private_endpoint_id and private_ip_address.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Module exists at terraform/modules/private-endpoint/
- [ ] #2 Uses azapi_resource with Microsoft.Network/privateEndpoints
- [ ] #3 Creates private DNS zone group for automatic DNS registration
- [ ] #4 Accepts target_resource_id, subnet_id, group_ids, dns_zone_id as inputs
- [ ] #5 Outputs private_endpoint_id and private_ip_address
- [ ] #6 terraform validate passes
<!-- AC:END -->
