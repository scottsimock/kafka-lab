---
id: TASK-29.10
title: SP2.009 — Schema Registry and Kafka Connect VM Instances
status: Done
assignee:
  - tester-3
created_date: '2026-03-30 16:42'
updated_date: '2026-03-30 21:36'
labels:
  - story
  - terraform
  - infrastructure
milestone: m-2
dependencies:
  - TASK-29.1
  - TASK-29.2
references:
  - terraform/modules/virtual-machine/
documentation:
  - doc-12
parent_task_id: TASK-29
priority: medium
ordinal: 2009
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add Schema Registry and Kafka Connect VM instances to the dev environment by calling the `virtual-machine` module in `terraform/environments/dev/main.tf`. These VMs have no data disks (unlike ZooKeeper and broker VMs).

**Schema Registry VM:**
- Name: `klc-vm-sr-01-scus`
- VM Size: `Standard_D2s_v5`
- Zone: `"1"` (southcentralus Zone 1)
- Subnet: `snet-schema-registry` (10.1.3.0/24) — via `module.vnet_scus.subnet_ids["snet-schema-registry"]`
- Static IP: `10.1.3.4`
- OS Disk: 64 GB Premium SSD
- Data Disk: **None** (`data_disk_size_gb = 0`)
- Tags: `local.common_tags` merged with `{ component = "schema_registry" }`
- DNS Name: `sr-01`

**Kafka Connect VM:**
- Name: `klc-vm-kc-01-scus`
- VM Size: `Standard_D2s_v5`
- Zone: `"1"` (southcentralus Zone 1)
- Subnet: `snet-connect` (10.1.4.0/24) — via `module.vnet_scus.subnet_ids["snet-connect"]`
- Static IP: `10.1.4.4`
- OS Disk: 64 GB Premium SSD
- Data Disk: **None** (`data_disk_size_gb = 0`)
- Tags: `local.common_tags` merged with `{ component = "kafka_connect" }`
- DNS Name: `kc-01`

**Node Configuration Maps:**
```hcl
locals {
  schema_registry_nodes = {
    "klc-vm-sr-01-scus" = { private_ip = "10.1.3.4", dns_name = "sr-01" }
  }

  kafka_connect_nodes = {
    "klc-vm-kc-01-scus" = { private_ip = "10.1.4.4", dns_name = "kc-01" }
  }
}
```

**File to modify:** `terraform/environments/dev/main.tf` — add after Kafka broker section.

**Outputs to add in `terraform/environments/dev/outputs.tf`:**
- `schema_registry_vm_ids` — map
- `schema_registry_private_ips` — map
- `kafka_connect_vm_ids` — map
- `kafka_connect_private_ips` — map

**Key difference from ZK/broker tasks:** `data_disk_size_gb = 0` skips data disk creation in the VM module (conditional logic from TASK-29.1).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 locals block defines schema_registry_nodes map with 1 entry: klc-vm-sr-01-scus
- [x] #2 locals block defines kafka_connect_nodes map with 1 entry: klc-vm-kc-01-scus
- [x] #3 Module call uses for_each to create 1 Schema Registry VM (Standard_D2s_v5, Zone 1)
- [x] #4 Schema Registry VM placed in snet-schema-registry subnet via module.vnet_scus.subnet_ids["snet-schema-registry"]
- [x] #5 Schema Registry static IP: 10.1.3.4
- [x] #6 Schema Registry tagged component=schema_registry merged into local.common_tags
- [x] #7 Schema Registry data_disk_size_gb = 0 (no data disk)
- [x] #8 Module call uses for_each to create 1 Kafka Connect VM (Standard_D2s_v5, Zone 1)
- [x] #9 Kafka Connect VM placed in snet-connect subnet via module.vnet_scus.subnet_ids["snet-connect"]
- [x] #10 Kafka Connect static IP: 10.1.4.4
- [x] #11 Kafka Connect tagged component=kafka_connect merged into local.common_tags
- [x] #12 Kafka Connect data_disk_size_gb = 0 (no data disk)
- [x] #13 UAMI assigned to both VMs via module.uami_kafkalab.uami_id
- [x] #14 Private DNS A records created for sr-01 and kc-01 in internal DNS zone
- [x] #15 Outputs added for both VMs: schema_registry_vm_ids, kafka_connect_vm_ids, and their private IPs
- [x] #16 terraform validate passes from terraform/environments/dev/
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Files to Modify
- `terraform/environments/dev/main.tf` — add Schema Registry and Kafka Connect VM sections
- `terraform/environments/dev/outputs.tf` — add SR and Connect VM outputs

### Design Decisions
1. Use `for_each` (even for single instances) for consistency with ZK/broker patterns and easy scaling later.
2. No data disk for SR and Connect — use `data_disk_size_gb = 0` which triggers conditional skip in VM module.
3. Separate locals maps for SR and Connect (not merged) for clear separation of concerns.
4. Same naming convention: `klc-vm-{component}-{NN}-{region}` (sr = schema registry, kc = kafka connect).
5. Both VMs in Zone 1, matching all other dev VMs.

### Integration Points
- Depends on TASK-29.1 (VM module — must handle data_disk_size_gb = 0 conditional)
- References SP1 networking: `module.vnet_scus.subnet_ids["snet-schema-registry"]` and `["snet-connect"]`
- References SP1 identity: `module.uami_kafkalab.uami_id`
- SSH key variable shared with TASK-29.2/29.3

### Dependency Note (SM review)
Added dependency on TASK-29.2 because:
1. TASK-29.2 creates the `kafkalab.internal` private DNS zone required for SR/Connect DNS A records
2. TASK-29.2 adds the `ssh_public_key` variable to `terraform/environments/dev/variables.tf`
3. Both tasks modify `terraform/environments/dev/main.tf` — serial execution required
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T17:10:00-04:00
- Assigned to coder-3 for Wave 3
- Task: Schema Registry and Kafka Connect VMs

## [Coder-3] 2026-03-30T17:15:00-04:00
- Added Schema Registry VM (klc-vm-sr-01-scus) and Kafka Connect VM (klc-vm-kc-01-scus)
- Both use Standard_D2s_v5, Zone 1, no data disk (data_disk_size_gb=0)
- DNS records: sr-01 and kc-01
- Added 4 outputs: sr/kc vm_ids and private_ips
- terraform fmt and validate passed
- Committed: feat(SP2.009)

## [Tester-3] 2026-03-30T17:20:00-04:00
- Score: 16/16 (100%) — PASS (threshold 95%)
- AC #1: ✅ locals.schema_registry_nodes map with 1 entry "klc-vm-sr-01-scus" (line 762-764)
- AC #2: ✅ locals.kafka_connect_nodes map with 1 entry "klc-vm-kc-01-scus" (line 793-795)
- AC #3: ✅ module.schema_registry_vms uses for_each, vm_size="Standard_D2s_v5", zone="1" (lines 769,776-777)
- AC #4: ✅ subnet_id = module.vnet_scus.subnet_ids["snet-schema-registry"] (line 774)
- AC #5: ✅ Static IP 10.1.3.4 via each.value.private_ip (lines 763,775)
- AC #6: ✅ tags = merge(local.common_tags, { component = "schema_registry" }) (line 785)
- AC #7: ✅ data_disk_size_gb = 0 (line 779)
- AC #8: ✅ module.kafka_connect_vms uses for_each, vm_size="Standard_D2s_v5", zone="1" (lines 800,807-808)
- AC #9: ✅ subnet_id = module.vnet_scus.subnet_ids["snet-connect"] (line 805)
- AC #10: ✅ Static IP 10.1.4.4 via each.value.private_ip (lines 794,806)
- AC #11: ✅ tags = merge(local.common_tags, { component = "kafka_connect" }) (line 816)
- AC #12: ✅ data_disk_size_gb = 0 (line 810)
- AC #13: ✅ Both modules set uami_id = module.uami_kafkalab.uami_id (lines 782,813)
- AC #14: ✅ DNS A records via dns_zone_id + dns_record_name for sr-01 and kc-01 (lines 783-784, 814-815)
- AC #15: ✅ All four outputs present in outputs.tf: schema_registry_vm_ids, schema_registry_private_ips, kafka_connect_vm_ids, kafka_connect_private_ips (lines 70-88)
- AC #16: ✅ terraform init -backend=false && terraform validate succeeded
<!-- SECTION:NOTES:END -->
