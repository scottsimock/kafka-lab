---
id: TASK-34.3
title: SP8.002 — Full Mesh VNet Peering
status: To Do
assignee: []
created_date: '2026-03-30 16:50'
updated_date: '2026-03-31 21:59'
labels:
  - story
milestone: m-7
dependencies:
  - TASK-34.6
references:
  - terraform/
documentation:
  - doc-10
parent_task_id: TASK-34
priority: high
ordinal: 7002
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create full mesh VNet peering between all three regions (6 peering resources). Use azapi_resource with type Microsoft.Network/virtualNetworks/virtualNetworkPeerings. Configure allowVirtualNetworkAccess=true, allowForwardedTraffic=true, allowGatewayTransit=false, useRemoteGateways=false. Per doc-10, Azure VNet peering is non-transitive so all 6 directed pairs are required.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 6 VNet peering resources created (full mesh: scus<->mxc, scus<->cae, mxc<->cae)
- [ ] #2 allowVirtualNetworkAccess=true on all peerings
- [ ] #3 allowForwardedTraffic=true on all peerings
- [ ] #4 Peering status shows Connected for all 6 peerings
- [ ] #5 Cross-region ping connectivity verified between subnets
- [ ] #6 terraform validate passes
<!-- AC:END -->
