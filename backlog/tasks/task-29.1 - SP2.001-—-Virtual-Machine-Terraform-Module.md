---
id: TASK-29.1
title: SP2.001 — Virtual Machine Terraform Module
status: To Do
assignee: []
created_date: '2026-03-30 16:42'
updated_date: '2026-03-30 16:43'
labels:
  - story
milestone: m-2
dependencies:
  - TASK-28.5
  - TASK-28.8
references:
  - terraform/modules/virtual-machine/
documentation:
  - doc-12
  - doc-14
parent_task_id: TASK-29
priority: high
ordinal: 2001
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable Terraform module at terraform/modules/virtual-machine/ that provisions an Azure Linux VM using azapi_resource. The module creates a NIC (Microsoft.Network/networkInterfaces) with static IP and accelerated networking, a VM (Microsoft.Compute/virtualMachines) using Ubuntu 22.04 LTS Gen2 image, and a managed data disk (Microsoft.Compute/disks). Accept parameters for VM SKU, availability zone, subnet, disk sizes, admin credentials, component tags for Ansible inventory. Assign UAMI to the VM.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Module exists at terraform/modules/virtual-machine/
- [ ] #2 Uses azapi_resource with Microsoft.Compute/virtualMachines
- [ ] #3 Accepts vm_sku, zone, subnet_id, data_disk_size_gb, os_disk_size_gb, admin_username, ssh_public_key
- [ ] #4 Creates NIC with static private IP and accelerated networking
- [ ] #5 Attaches managed data disk (Premium SSD) formatted as separate resource
- [ ] #6 Sets VM tags for Ansible dynamic inventory (component, environment, region)
- [ ] #7 UAMI assigned to VM
- [ ] #8 Outputs vm_id, vm_name, private_ip_address, nic_id
- [ ] #9 terraform validate passes
<!-- AC:END -->
