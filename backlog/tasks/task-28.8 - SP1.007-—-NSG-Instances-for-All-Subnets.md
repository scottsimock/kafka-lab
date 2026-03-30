---
id: TASK-28.8
title: SP1.007 — NSG Instances for All Subnets
status: Done
assignee:
  - tester-1
created_date: '2026-03-30 16:40'
updated_date: '2026-03-30 19:39'
labels:
  - story
milestone: m-1
dependencies:
  - TASK-28.10
  - TASK-28.5
references:
  - terraform/modules/network-security-group/
documentation:
  - doc-10
parent_task_id: TASK-28
priority: medium
ordinal: 1007
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Using the NSG module from TASK-28.10 (SP1.006), instantiate 7 NSGs (one per subnet) in the root module with security rules matching the research doc-10 specifications. Use for_each to create all NSG instances from a local map.

NSG rules per doc-10:

**nsg-kafka-brokers** (snet-kafka-brokers):
- P100: TCP 9092 from snet-connect, snet-web-app (client connections)
- P110: TCP 9093 from snet-connect, snet-web-app (SSL client connections)
- P120: TCP 9092 from 10.1.1.0/24, 10.2.1.0/24, 10.3.1.0/24 (inter-broker replication)
- P130: TCP 9093 from 10.1.1.0/24, 10.2.1.0/24, 10.3.1.0/24 (inter-broker SSL)
- P140: TCP 9092-9093 from snet-schema-registry (SR to broker)
- P150: TCP 9021 from snet-management (Control Center)
- P160: TCP 22 from snet-management (SSH)

**nsg-zookeeper** (snet-zookeeper):
- P100: TCP 2181 from snet-kafka-brokers (ZK client)
- P110: TCP 2181 from 10.1.1.0/24, 10.2.1.0/24, 10.3.1.0/24 (cross-region broker access)
- P120: TCP 2888 from 10.1.2.0/24, 10.2.2.0/24, 10.3.2.0/24 (follower-to-leader)
- P130: TCP 3888 from 10.1.2.0/24, 10.2.2.0/24, 10.3.2.0/24 (leader election)
- P140: TCP 22 from snet-management (SSH)

**nsg-schema-registry** (snet-schema-registry):
- P100: TCP 8081 from snet-kafka-brokers
- P110: TCP 8081 from snet-connect
- P120: TCP 8081 from snet-web-app
- P130: TCP 8081 from 10.1.3.0/24, 10.2.3.0/24, 10.3.3.0/24 (cross-region SR)
- P140: TCP 22 from snet-management (SSH)

**nsg-connect** (snet-connect):
- P100: TCP 8083 from snet-management (REST API)
- P110: TCP 8083 from snet-web-app (REST API)
- P120: TCP 8089 from snet-management (intra-cluster)
- P130: TCP 8090 from snet-management (MDS/RBAC)
- P140: TCP 22 from snet-management (SSH)

**nsg-web-app** (snet-web-app):
- P100: TCP 443 from AzureFrontDoor.Backend service tag (HTTPS)
- P110: TCP 22 from snet-management (SSH)

**nsg-private-endpoints** (snet-private-endpoints):
- P100: TCP 443 from VirtualNetwork (HTTPS to KV PE)
- P110: TCP 443 from VirtualNetwork (HTTPS to Blob PE)

**nsg-management** (snet-management):
- P100: TCP 22 from VirtualNetwork (SSH access from within VNet)

All NSGs auto-include Deny-All-Inbound at P4096.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 7 NSG instances created in root module using the network-security-group module from TASK-28.10 via for_each
- [x] #2 nsg-kafka-brokers: allows TCP 9092 from snet-connect and snet-web-app; TCP 9093 from snet-connect and snet-web-app; TCP 9092 from cross-region broker CIDRs (10.1.1.0/24, 10.2.1.0/24, 10.3.1.0/24); TCP 9093 from cross-region broker CIDRs; TCP 9092-9093 from snet-schema-registry; TCP 9021 from snet-management; TCP 22 from snet-management
- [x] #3 nsg-zookeeper: allows TCP 2181 from snet-kafka-brokers and cross-region broker CIDRs; TCP 2888 from cross-region ZK CIDRs (10.1.2.0/24, 10.2.2.0/24, 10.3.2.0/24); TCP 3888 from cross-region ZK CIDRs; TCP 22 from snet-management
- [x] #4 nsg-schema-registry: allows TCP 8081 from snet-kafka-brokers, snet-connect, snet-web-app, and cross-region SR CIDRs (10.1.3.0/24, 10.2.3.0/24, 10.3.3.0/24); TCP 22 from snet-management
- [x] #5 nsg-connect: allows TCP 8083 from snet-management and snet-web-app; TCP 8089 from snet-management; TCP 8090 from snet-management; TCP 22 from snet-management
- [x] #6 nsg-web-app: allows TCP 443 from AzureFrontDoor.Backend service tag; TCP 22 from snet-management
- [x] #7 nsg-private-endpoints: allows TCP 443 from VirtualNetwork service tag (for KV and Blob access)
- [x] #8 nsg-management: allows TCP 22 inbound from VirtualNetwork service tag at priority 100
- [x] #9 Each NSG is associated with its respective subnet via the module
- [x] #10 All NSGs include the terminal Deny-All-Inbound rule at priority 4096 (auto-appended by module)
- [x] #11 Security rule priorities match doc-10 specifications (100, 110, 120, etc.)
- [x] #12 terraform validate passes in terraform/environments/dev/
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T19:35:00Z
- Assigned to coder-1 (Wave 3)
- Dependencies 28.10 and 28.5 both Done
- Modifies main.tf heavily (7 NSG instances via for_each)

## [Coder] 2026-03-30T19:45:00Z
- Appended `locals.nsg_configs` and `module.nsgs` (for_each) to `terraform/environments/dev/main.tf`
- 7 NSG instances: nsg-kafka-brokers, nsg-zookeeper, nsg-schema-registry, nsg-connect, nsg-web-app, nsg-private-endpoints, nsg-management
- All security rule objects normalized with explicit null for all optional fields to ensure consistent HCL type inference
- `terraform fmt -recursive` and `terraform validate` both pass
- Committed: feat(SP1.007): nsg instances for all subnets

## [Tester] 2026-03-30T20:00:00Z
- Reviewed NSG implementation in terraform/environments/dev/main.tf (lines 88–572)
- `terraform fmt -check -recursive ../../` — PASS
- `terraform validate` — PASS
- All 7 NSG instances present via `for_each` over `local.nsg_configs`
- nsg-kafka-brokers: all 7 rules verified (P100–P160), dual-port SR rule uses `destination_port_ranges = ["9092","9093"]` ✅
- nsg-zookeeper: all 5 rules verified (P100–P140) ✅
- nsg-schema-registry: all 5 rules verified (P100–P140) ✅
- nsg-connect: all 5 rules verified (P100–P140) ✅
- nsg-web-app: AzureFrontDoor.Backend service tag at P100 ✅
- nsg-private-endpoints: VirtualNetwork service tag at P100/P110 ✅
- nsg-management: VirtualNetwork at P100 ✅
- Subnet association via `module.vnet_scus.subnet_ids[each.value.subnet_name]` ✅
- DenyAllInbound at P4096 auto-appended by NSG module ✅
- All priorities match doc-10 spec ✅

**Score: 100/100 — PASS**
| Category | Weight | Score |
|---|---|---|
| Acceptance Criteria | 30 | 30 |
| Tests | 25 | 25 |
| Code Quality | 20 | 20 |
| Documentation | 15 | 15 |
| Dependencies | 10 | 10 |
| **Total** | **100** | **100** |
<!-- SECTION:NOTES:END -->
