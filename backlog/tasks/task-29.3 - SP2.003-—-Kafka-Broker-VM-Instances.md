---
id: TASK-29.3
title: SP2.003 — Kafka Broker VM Instances
status: Done
assignee:
  - tester-1
created_date: '2026-03-30 16:42'
updated_date: '2026-03-30 21:34'
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
priority: high
ordinal: 2003
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add Kafka broker VM instances to the dev environment by calling the `virtual-machine` module 3 times in `terraform/environments/dev/main.tf`. Use a `locals` block with a map of broker node configurations and invoke the module with `for_each`.

**VM Specifications (per node):**
- VM Size: `Standard_D4s_v5`
- Zone: `"1"` (southcentralus Zone 1)
- Subnet: `snet-kafka-brokers` (10.1.1.0/24) — referenced via `module.vnet_scus.subnet_ids["snet-kafka-brokers"]`
- OS Disk: 64 GB Premium SSD
- Data Disk: 256 GB Premium SSD (for Kafka log segments — sized for dev; production would use larger)
- Admin User: `azureuser`
- UAMI: `module.uami_kafkalab.uami_id`

**Node Configuration Map:**
```hcl
locals {
  kafka_broker_nodes = {
    "klc-vm-kb-01-scus" = { private_ip = "10.1.1.4", dns_name = "kb-01" }
    "klc-vm-kb-02-scus" = { private_ip = "10.1.1.5", dns_name = "kb-02" }
    "klc-vm-kb-03-scus" = { private_ip = "10.1.1.6", dns_name = "kb-03" }
  }
}
```

**Tags per VM:** Merge `local.common_tags` with `{ component = "kafka_broker" }`.

**Private DNS:** Each VM gets an A record in the `kafkalab.internal` private DNS zone. DNS names: `kb-01`, `kb-02`, `kb-03`.

**File to modify:** `terraform/environments/dev/main.tf` — add after ZooKeeper section.

**Outputs to add in `terraform/environments/dev/outputs.tf`:**
- `kafka_broker_vm_ids` — map of VM name to VM ID
- `kafka_broker_private_ips` — map of VM name to private IP
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 locals block defines kafka_broker_nodes map with 3 entries: klc-vm-kb-01-scus through klc-vm-kb-03-scus
- [x] #2 Module call uses for_each = local.kafka_broker_nodes to create 3 Kafka broker VMs
- [x] #3 Each VM uses Standard_D4s_v5 SKU and zone = 1
- [x] #4 Each VM placed in snet-kafka-brokers subnet via module.vnet_scus.subnet_ids["snet-kafka-brokers"]
- [x] #5 Static IPs assigned: 10.1.1.4, 10.1.1.5, 10.1.1.6
- [x] #6 Each VM gets 64 GB OS disk and 256 GB data disk (Premium SSD)
- [x] #7 Each VM tagged with component=kafka_broker merged into local.common_tags
- [x] #8 UAMI assigned via module.uami_kafkalab.uami_id
- [x] #9 SSH public key variable referenced (shared with ZooKeeper task)
- [x] #10 Private DNS A records created for kb-01, kb-02, kb-03 in internal DNS zone
- [x] #11 Outputs added: kafka_broker_vm_ids and kafka_broker_private_ips maps
- [x] #12 terraform validate passes from terraform/environments/dev/
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Files to Modify
- `terraform/environments/dev/main.tf` — add Kafka broker VM section with locals and module call
- `terraform/environments/dev/outputs.tf` — add broker VM outputs

### Design Decisions
1. Use `for_each` for stable resource addresses.
2. Name VMs `klc-vm-kb-{NN}-scus` (kb = kafka broker).
3. Data disk is 256 GB for dev — sized for Kafka log segments with reasonable retention.
4. Use Standard_D4s_v5 (4 vCPU, 16 GB RAM) for brokers — larger than ZooKeeper due to message throughput.
5. Place after ZooKeeper section in main.tf.

### Integration Points
- Depends on TASK-29.1 (VM module must exist)
- References SP1 networking: `module.vnet_scus.subnet_ids["snet-kafka-brokers"]`
- References SP1 identity: `module.uami_kafkalab.uami_id`
- SSH key variable shared with TASK-29.2

### Dependency Note (SM review)
Added dependency on TASK-29.2 because:
1. TASK-29.2 creates the `kafkalab.internal` private DNS zone required for broker DNS A records
2. TASK-29.2 adds the `ssh_public_key` variable to `terraform/environments/dev/variables.tf`
3. Both tasks modify `terraform/environments/dev/main.tf` — serial execution required
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T17:10:00-04:00
- Assigned to coder-2 for Wave 3
- Task: Kafka broker VM instances

## [Coder-2] 2026-03-30T17:11:00-04:00
- Created Kafka broker VM section with 3 nodes using for_each
- Standard_D4s_v5, Zone 1, 256 GB data disks
- DNS records: kb-01, kb-02, kb-03
- Added kafka_broker_vm_ids and kafka_broker_private_ips outputs
- terraform fmt and validate passed
- Committed: feat(SP2.003)

## [Tester-1] 2026-03-30T22:05:00Z
- Score: 12/12 (100%) — **PASS**
- AC #1: ✅ locals.kafka_broker_nodes has 3 entries: klc-vm-kb-01-scus, klc-vm-kb-02-scus, klc-vm-kb-03-scus (main.tf:729-733)
- AC #2: ✅ for_each = local.kafka_broker_nodes on module "kafka_broker_vms" (main.tf:738)
- AC #3: ✅ vm_size = "Standard_D4s_v5", zone = "1" (main.tf:745-746)
- AC #4: ✅ subnet_id = module.vnet_scus.subnet_ids["snet-kafka-brokers"] (main.tf:743)
- AC #5: ✅ Static IPs 10.1.1.4, 10.1.1.5, 10.1.1.6 in map values (main.tf:730-732)
- AC #6: ✅ os_disk_size_gb = 64, data_disk_size_gb = 256 (main.tf:747-748)
- AC #7: ✅ tags = merge(local.common_tags, { component = "kafka_broker" }) (main.tf:754)
- AC #8: ✅ uami_id = module.uami_kafkalab.uami_id (main.tf:751)
- AC #9: ✅ ssh_public_key = var.ssh_public_key (main.tf:750)
- AC #10: ✅ DNS records kb-01, kb-02, kb-03 via dns_record_name = each.value.dns_name (main.tf:753)
- AC #11: ✅ Outputs kafka_broker_vm_ids and kafka_broker_private_ips with map comprehensions (outputs.tf:60-68)
- AC #12: ✅ terraform init -backend=false && terraform validate — Success
<!-- SECTION:NOTES:END -->
