---
id: TASK-29.1
title: SP2.001 — Virtual Machine Terraform Module
status: Done
assignee:
  - tester-1
created_date: '2026-03-30 16:42'
updated_date: '2026-03-30 21:13'
labels:
  - story
  - terraform
  - infrastructure
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
Create a reusable Terraform module at `terraform/modules/virtual-machine/` that provisions an Azure Linux VM using `azapi_resource`. The module must follow the established codebase patterns (azapi_resource, `// ` comments, snake_case variables, consistent versions.tf).

**Resources created by this module:**

1. **NIC** (`Microsoft.Network/networkInterfaces@2024-05-01`) — static private IP, accelerated networking enabled, associated with a provided subnet ID.
2. **OS Disk** — included in the VM resource body, Ubuntu 22.04 LTS Gen2, Premium SSD, configurable size (default 64 GB).
3. **Data Disk** (`Microsoft.Compute/disks@2024-03-02`) — Premium SSD, configurable size, conditional creation (only when `data_disk_size_gb > 0`). Attached via `Microsoft.Compute/virtualMachines/dataDisks` or via the VM body `dataDisks` array.
4. **VM** (`Microsoft.Compute/virtualMachines@2024-07-01`) — Ubuntu 22.04 LTS Gen2 image (`Canonical:ubuntu-24_04-lts:server-gen2:latest` — NOTE: use `Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest`), SSH key auth, UAMI assigned, availability zone placement.
5. **Private DNS A Record** (`Microsoft.Network/privateDnsZones/A@2020-06-01`) — optional, creates an A record pointing to the VM's private IP in a specified DNS zone.

**Variable inputs (all with descriptions, no trailing periods):**
- `name` (string) — VM resource name, e.g., `klc-vm-zk-01-scus`
- `location` (string) — Azure region
- `resource_group_id` (string) — Target resource group ID
- `subnet_id` (string) — Subnet resource ID for NIC placement
- `private_ip_address` (string) — Static private IP for the NIC
- `vm_size` (string) — Azure VM SKU, e.g., `Standard_D2s_v5`
- `zone` (string) — Availability zone, e.g., `"1"`
- `os_disk_size_gb` (number, default: 64) — OS disk size
- `data_disk_size_gb` (number, default: 0) — Data disk size; 0 means no data disk
- `admin_username` (string, default: `"azureuser"`) — SSH admin user
- `ssh_public_key` (string) — SSH public key for authentication
- `uami_id` (string) — User Assigned Managed Identity resource ID
- `dns_zone_id` (string, default: null) — Optional private DNS zone ID for A record
- `dns_record_name` (string, default: null) — Optional DNS A record hostname
- `tags` (map(string), default: {}) — Resource tags, must include `component`, `environment`, `region` for Ansible inventory

**Outputs:**
- `vm_id` — VM resource ID
- `vm_name` — VM name
- `private_ip_address` — NIC private IP
- `nic_id` — NIC resource ID
- `data_disk_id` — Data disk resource ID (null when no data disk)

**Integration with SP1:**
- Subnet IDs come from `module.vnet_scus.subnet_ids["snet-xxx"]` in the dev environment
- UAMI comes from `module.uami_kafkalab.uami_id`
- Resource group from `data.azapi_resource.resource_group.id`
- Tags use `local.common_tags` merged with component-specific tags
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Module directory exists at terraform/modules/virtual-machine/ with main.tf, variables.tf, outputs.tf, versions.tf
- [x] #2 main.tf uses azapi_resource for Microsoft.Network/networkInterfaces@2024-05-01 with enableAcceleratedNetworking=true and static private IP
- [x] #3 main.tf uses azapi_resource for Microsoft.Compute/virtualMachines@2024-07-01 with Ubuntu 22.04 LTS Gen2 image (Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest)
- [x] #4 VM resource configures SSH key authentication via linuxConfiguration.ssh.publicKeys — no password auth
- [x] #5 VM resource assigns UAMI via identity block with type=UserAssigned
- [x] #6 Data disk (Microsoft.Compute/disks@2024-03-02) is conditionally created only when var.data_disk_size_gb > 0 using count or for_each
- [x] #7 Data disk uses Premium_LRS (Premium SSD) storage SKU
- [x] #8 VM supports availability zone placement via the zones property
- [x] #9 Private DNS A record (Microsoft.Network/privateDnsZones/A@2020-06-01) is conditionally created when var.dns_zone_id is not null
- [x] #10 versions.tf declares required_version >= 1.6.0 and azapi provider >= 2.0
- [x] #11 variables.tf includes all specified variables with type constraints and descriptions (no trailing periods)
- [x] #12 outputs.tf exposes vm_id, vm_name, private_ip_address, nic_id, and data_disk_id
- [x] #13 terraform validate passes from the module directory (with required variable stubs)
- [x] #14 All azapi_resource blocks use // comments (not #), consistent with codebase conventions
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Files to Create
- `terraform/modules/virtual-machine/main.tf`
- `terraform/modules/virtual-machine/variables.tf`
- `terraform/modules/virtual-machine/outputs.tf`
- `terraform/modules/virtual-machine/versions.tf`

### Design Decisions
1. **Conditional data disk**: Use `count = var.data_disk_size_gb > 0 ? 1 : 0` on both the disk resource and the disk attachment (or include in VM body dataDisks array conditionally).
2. **Conditional DNS A record**: Use `count = var.dns_zone_id != null ? 1 : 0`.
3. **NIC before VM**: NIC must be created first; VM references NIC ID. Use `depends_on` or implicit reference.
4. **Image reference**: Use `imageReference` with publisher=Canonical, offer=0001-com-ubuntu-server-jammy, sku=22_04-lts-gen2, version=latest.
5. **SSH auth**: Set `disablePasswordAuthentication = true` in `linuxConfiguration`, provide public key in `ssh.publicKeys` array with path `/home/{admin_username}/.ssh/authorized_keys`.
6. **UAMI**: Set `identity { type = "UserAssigned", identity_ids = [var.uami_id] }` on the VM resource.
7. **Accelerated networking**: Set `enableAcceleratedNetworking = true` on the NIC properties (supported by D2s_v5 and D4s_v5).
8. **Tags**: Pass `var.tags` to all resources. Caller merges `local.common_tags` with component-specific tags like `{ component = "zookeeper" }`.

### Integration Points
- Called from `terraform/environments/dev/main.tf` by TASK-29.2, 29.3, and 29.10
- References SP1 outputs: `module.vnet_scus.subnet_ids`, `module.uami_kafkalab.uami_id`, `data.azapi_resource.resource_group.id`
- Follow the same versions.tf pattern as other modules (terraform >= 1.6.0, azapi >= 2.0)
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T16:42:00-04:00
- Assigned to coder-1 for Wave 1 execution
- Task: Create VM Terraform module using AzAPI

## [Coder-1] 2026-03-30T16:43:00-04:00
- Created terraform/modules/virtual-machine/ with main.tf, variables.tf, outputs.tf, versions.tf
- NIC with accelerated networking and static IP
- VM with Ubuntu 22.04 LTS Gen2, SSH auth, UAMI, zone placement
- Conditional data disk (Premium_LRS) when data_disk_size_gb > 0
- Conditional DNS A record when dns_zone_id not null
- terraform fmt and validate passed
- Committed: feat(SP2.001)

## [Tester-1] 2025-07-24T12:50:00Z
- Score: 14/14 (100%) — **PASS**
- terraform init -backend=false: PASS
- terraform validate: PASS ("Success! The configuration is valid.")
- terraform fmt -check: PASS (exit 0)
- No `#` comments found; `//` comments present in main.tf (15), variables.tf (3), outputs.tf (3)
- AC #1: All 4 files exist (main.tf, variables.tf, outputs.tf, versions.tf)
- AC #2: NIC uses Microsoft.Network/networkInterfaces@2024-05-01, enableAcceleratedNetworking=true, Static IP referencing var.private_ip_address
- AC #3: VM uses Microsoft.Compute/virtualMachines@2024-07-01, image: Canonical/0001-com-ubuntu-server-jammy/22_04-lts-gen2/latest
- AC #4: disablePasswordAuthentication=true, publicKeys array with path and keyData
- AC #5: identity block type="UserAssigned", identity_ids=[var.uami_id]
- AC #6: data_disk count = var.data_disk_size_gb > 0 ? 1 : 0
- AC #7: sku.name = "Premium_LRS"
- AC #8: zones = [var.zone] on VM resource
- AC #9: dns_record count = var.dns_zone_id != null ? 1 : 0
- AC #10: required_version >= 1.6.0, azapi >= 2.0
- AC #11: All 15 variables present with correct types, defaults, and no trailing periods in descriptions
- AC #12: All 5 outputs present; data_disk_id handles null via ternary
- AC #13: terraform validate passes
- AC #14: Zero # comments, // style used throughout
<!-- SECTION:NOTES:END -->
