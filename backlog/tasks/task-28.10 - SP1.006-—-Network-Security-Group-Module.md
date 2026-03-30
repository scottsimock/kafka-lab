---
id: TASK-28.10
title: SP1.006 — Network Security Group Module
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
  - terraform/modules/network-security-group/
documentation:
  - doc-10
parent_task_id: TASK-28
priority: medium
ordinal: 1006
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable Terraform module at terraform/modules/network-security-group/ that provisions an NSG using azapi_resource with type Microsoft.Network/networkSecurityGroups. The module accepts a list of security rules (priority, direction, protocol, port, source, destination, description) and a subnet_id for association. Every NSG includes a terminal Deny-All-Inbound rule at priority 4096. Output nsg_id and nsg_name.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Module exists at terraform/modules/network-security-group/
- [ ] #2 Uses azapi_resource with Microsoft.Network/networkSecurityGroups
- [ ] #3 Accepts a list of security rules as variable input
- [ ] #4 Creates NSG and associates it with a subnet
- [ ] #5 Terminal Deny-All-Inbound rule at priority 4096
- [ ] #6 terraform validate passes
<!-- AC:END -->
