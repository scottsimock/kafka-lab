---
id: TASK-29.2
title: SP2.002 — ZooKeeper VM Instances
status: Done
assignee:
  - tester-1
created_date: '2026-03-30 16:42'
updated_date: '2026-03-30 21:25'
labels:
  - story
  - terraform
  - infrastructure
milestone: m-2
dependencies:
  - TASK-29.1
references:
  - terraform/modules/virtual-machine/
documentation:
  - doc-12
parent_task_id: TASK-29
priority: high
ordinal: 2002
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add ZooKeeper VM instances to the dev environment by calling the `virtual-machine` module 3 times in `terraform/environments/dev/main.tf`. Use a `locals` block with a map of ZooKeeper node configurations, then invoke the module with `for_each`.

**VM Specifications (per node):**
- VM Size: `Standard_D2s_v5`
- Zone: `"1"` (southcentralus Zone 1)
- Subnet: `snet-zookeeper` (10.1.2.0/24) — referenced via `module.vnet_scus.subnet_ids["snet-zookeeper"]`
- OS Disk: 64 GB Premium SSD
- Data Disk: 64 GB Premium SSD (for ZooKeeper data and transaction logs)
- Admin User: `azureuser`
- UAMI: `module.uami_kafkalab.uami_id`

**Node Configuration Map:**
```hcl
locals {
  zookeeper_nodes = {
    "klc-vm-zk-01-scus" = { private_ip = "10.1.2.4", dns_name = "zk-01" }
    "klc-vm-zk-02-scus" = { private_ip = "10.1.2.5", dns_name = "zk-02" }
    "klc-vm-zk-03-scus" = { private_ip = "10.1.2.6", dns_name = "zk-03" }
  }
}
```

**Tags per VM:** Merge `local.common_tags` with `{ component = "zookeeper" }`.

**Private DNS:** Each VM gets an A record in the `kafkalab.internal` private DNS zone (this zone may need to be created in this sprint or referenced if created in SP1 — check existing DNS zones). DNS names: `zk-01`, `zk-02`, `zk-03`.

**File to modify:** `terraform/environments/dev/main.tf` — add a new section after the storage/private endpoint section.

**Outputs to add in `terraform/environments/dev/outputs.tf`:**
- `zookeeper_vm_ids` — map of VM name to VM ID
- `zookeeper_private_ips` — map of VM name to private IP
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 locals block defines zookeeper_nodes map with 3 entries: klc-vm-zk-01-scus through klc-vm-zk-03-scus
- [x] #2 Module call uses for_each = local.zookeeper_nodes to create 3 ZooKeeper VMs
- [x] #3 Each VM uses Standard_D2s_v5 SKU and zone = 1
- [x] #4 Each VM placed in snet-zookeeper subnet via module.vnet_scus.subnet_ids["snet-zookeeper"]
- [x] #5 Static IPs assigned: 10.1.2.4, 10.1.2.5, 10.1.2.6
- [x] #6 Each VM gets 64 GB OS disk and 64 GB data disk (Premium SSD)
- [x] #7 Each VM tagged with component=zookeeper merged into local.common_tags
- [x] #8 UAMI assigned via module.uami_kafkalab.uami_id
- [x] #9 SSH public key variable referenced (var.ssh_public_key added to variables.tf if not present)
- [x] #10 Private DNS A records created for zk-01, zk-02, zk-03 in internal DNS zone
- [x] #11 Outputs added: zookeeper_vm_ids and zookeeper_private_ips maps
- [x] #12 terraform validate passes from terraform/environments/dev/
- [x] #13 kafkalab.internal private DNS zone added to private_dns_zones locals in dev main.tf and created via existing private-dns-zone module with VNet link to klc-vnet-scus — zone ID passed as dns_zone_id to VM module calls
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Files to Modify
- `terraform/environments/dev/main.tf` — add ZooKeeper VM section with locals and module call
- `terraform/environments/dev/variables.tf` — add `ssh_public_key` variable if not present
- `terraform/environments/dev/outputs.tf` — add zookeeper VM outputs

### Files May Need to Create
- Private DNS zone for internal VM resolution (`kafkalab.internal`) if not already created — add module call in main.tf or create as part of this task

### Design Decisions
1. Use `for_each` over `count` for stable resource addresses when nodes are added/removed.
2. Name VMs with `klc-vm-zk-{NN}-scus` pattern consistent with project naming conventions.
3. Data disk size is 64 GB (sufficient for dev ZooKeeper data + txn logs).
4. Place the ZooKeeper section after the NSG section in main.tf, organized with a section header comment.
5. The `ssh_public_key` variable should be a `sensitive = true` string variable.

### Integration Points
- Depends on TASK-29.1 (VM module must exist)
- References SP1 networking: `module.vnet_scus.subnet_ids["snet-zookeeper"]`
- References SP1 identity: `module.uami_kafkalab.uami_id`
- References SP1 resource group: `data.azapi_resource.resource_group.id`

### DNS Zone Prerequisite
This task is the first to reference the `kafkalab.internal` private DNS zone, which does NOT exist yet in the dev environment. The current `local.private_dns_zones` only has `blob` and `vault` entries. This task MUST:
1. Add `"internal" = "kafkalab.internal"` to `local.private_dns_zones` in `main.tf`
2. The existing `module.private_dns_zones` for_each will automatically create the zone
3. Reference the zone ID as `module.private_dns_zones["internal"].dns_zone_id` when passing `dns_zone_id` to the VM module
4. TASK-29.3 and TASK-29.10 depend on this task for the DNS zone
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T16:55:00-04:00
- Assigned to coder-1 for Wave 2
- Task: ZooKeeper VM instances in dev environment

## [Coder-1] 2026-03-30T16:56:00-04:00
- Added kafkalab.internal to private_dns_zones locals
- Created ZooKeeper VM section with 3 nodes using for_each
- Added ssh_public_key variable to variables.tf
- Added zookeeper_vm_ids and zookeeper_private_ips outputs
- terraform fmt and validate passed
- Committed: feat(SP2.002)

## [Tester-1] 2025-07-21T18:30:00Z
- Score: 13/13 (100%) — PASS (threshold 95%)
- AC1: ✅ locals.zookeeper_nodes map has klc-vm-zk-01-scus, klc-vm-zk-02-scus, klc-vm-zk-03-scus
- AC2: ✅ module "zookeeper_vms" with for_each = local.zookeeper_nodes
- AC3: ✅ vm_size = "Standard_D2s_v5", zone = "1"
- AC4: ✅ subnet_id = module.vnet_scus.subnet_ids["snet-zookeeper"]
- AC5: ✅ IPs 10.1.2.4, 10.1.2.5, 10.1.2.6 present
- AC6: ✅ os_disk_size_gb = 64, data_disk_size_gb = 64
- AC7: ✅ tags = merge(local.common_tags, { component = "zookeeper" })
- AC8: ✅ uami_id = module.uami_kafkalab.uami_id
- AC9: ✅ ssh_public_key = var.ssh_public_key; variable defined in variables.tf with sensitive = true
- AC10: ✅ dns_zone_id from internal zone, dns_record_name = zk-01/zk-02/zk-03
- AC11: ✅ outputs.tf has zookeeper_vm_ids and zookeeper_private_ips
- AC12: ✅ terraform validate passes, fmt -check clean
- AC13: ✅ "internal" = "kafkalab.internal" in private_dns_zones, zone ID passed to VM module
<!-- SECTION:NOTES:END -->
