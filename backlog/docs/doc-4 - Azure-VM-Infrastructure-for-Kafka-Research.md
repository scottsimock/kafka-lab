---
id: doc-4
title: Azure VM Infrastructure for Kafka Research
type: other
created_date: '2026-03-28 18:24'
---
## Summary

This document captures research findings on Azure Virtual Machine infrastructure for hosting Confluent Platform 7.x (ZooKeeper-based) across three Azure regions (southcentralus, mexicocentral, canadaeast). It covers VM SKU selection for all components (brokers, ZooKeeper, Schema Registry, Connect), disk configuration for Kafka data logs, availability zone placement strategy, VM extensions for monitoring, and the individual VMs vs VMSS decision for a lab environment. All recommendations target Ubuntu 22.04 LTS with CMEK encryption and UAMI authentication per project compliance requirements.

## Key Findings

### VM SKU Recommendations by Component

- **Kafka Brokers (lab):** Standard_E8s_v5 — 8 vCPUs, 64 GiB RAM, 12,800 max uncached IOPS, 290 MBps uncached throughput, up to 24 Gbps network bandwidth. Memory-optimized series provides the large page cache Kafka requires. Supports Premium SSD and accelerated networking. For production-scale loads, Standard_L8s_v3 (storage-optimized with local NVMe) is preferred, but Esv5 is more cost-effective for a lab.
- **ZooKeeper nodes:** Standard_E4s_v5 — 4 vCPUs, 32 GiB RAM, 6,400 max uncached IOPS, 145 MBps throughput. ZooKeeper is metadata-intensive but not compute-heavy; low-latency disk I/O matters more than raw CPU. 3 nodes (odd quorum).
- **Schema Registry:** Standard_D2s_v5 — 2 vCPUs, 8 GiB RAM. Lightweight stateless Java service; minimal resource requirements. Deploy 2 instances for HA.
- **Kafka Connect:** Standard_D4s_v5 — 4 vCPUs, 16 GiB RAM. Resource needs scale with connector count and parallelism. Start small and scale up.
- **Control Center / ancillary:** Standard_D4s_v5 — 4 vCPUs, 16 GiB RAM. Adequate for monitoring UI and metrics aggregation in a lab context.

### VM SKU Comparison Table

| Component | SKU | vCPUs | RAM | Max IOPS | Max Throughput | Network | Qty per Region |
|---|---|---|---|---|---|---|---|
| Kafka Broker | Standard_E8s_v5 | 8 | 64 GiB | 12,800 | 290 MBps | 24 Gbps | 3 |
| ZooKeeper | Standard_E4s_v5 | 4 | 32 GiB | 6,400 | 145 MBps | 16 Gbps | 3 |
| Schema Registry | Standard_D2s_v5 | 2 | 8 GiB | 3,200 | 48 MBps | 12.5 Gbps | 2 |
| Kafka Connect | Standard_D4s_v5 | 4 | 16 GiB | 6,400 | 96 MBps | 12.5 Gbps | 2 |
| Control Center | Standard_D4s_v5 | 4 | 16 GiB | 6,400 | 96 MBps | 12.5 Gbps | 1 |

### Disk Configuration for Kafka Data Logs

- **Recommended disk type:** Premium SSD v2 (PremiumV2_LRS). Allows independent provisioning of IOPS and throughput decoupled from disk size. Max 80,000 IOPS and 1,200 MB/s per disk.
- **Lab configuration per broker:** 2 × 512 GiB Premium SSD v2 disks, each provisioned at 5,000 IOPS and 250 MB/s throughput. Striped via LVM (RAID-0) for aggregate 10,000 IOPS and 500 MB/s.
- **OS disk:** 128 GiB Premium SSD (P10), sufficient for Ubuntu 22.04 LTS and Confluent Platform binaries.
- **ZooKeeper data disk:** 1 × 256 GiB Premium SSD v2 at 3,000 IOPS. ZooKeeper transaction logs are small but latency-sensitive.
- **Filesystem:** XFS with mount options `noatime,nodiratime` to minimize metadata I/O overhead.
- **Host caching:** Disabled (`None`) on all Kafka data disks to prevent data loss and ensure write consistency.
- **CMEK encryption:** All managed disks encrypted with a dedicated Customer Managed Key per disk in Azure Key Vault, accessed via the VM's UAMI.

### Premium SSD Reference Tiers (v1 baseline comparison)

| Tier | Size | Baseline IOPS | Baseline Throughput |
|---|---|---|---|
| P10 | 128 GiB | 500 | 100 MB/s |
| P20 | 512 GiB | 2,300 | 150 MB/s |
| P30 | 1 TiB | 5,000 | 200 MB/s |
| P40 | 2 TiB | 7,500 | 250 MB/s |
| P50 | 4 TiB | 7,500 | 250 MB/s |

Premium SSD v2 removes these fixed tiers — IOPS and throughput are provisioned independently at creation time.

### Availability Zone Placement

- **Strategy:** Zone pinning — each Kafka broker is deployed to a specific, deterministic availability zone (broker 0 → Zone 1, broker 1 → Zone 2, broker 2 → Zone 3 in southcentralus). This provides datacenter-level fault isolation with a 99.99% SLA.
- **Availability Sets are not recommended** for this architecture. They provide only rack-level isolation (99.95% SLA) within a single datacenter and do not protect against zone-wide failures.
- **Zone mapping per region:**
  - southcentralus: Zones 1, 2, 3 (all three available) — 1 broker per zone
  - mexicocentral: Zone 1 (limited AZ support) — all 3 brokers in Zone 1, rely on fault domains
  - canadaeast: Zone 1 (limited AZ support) — DR cluster, passive, all in Zone 1
- **Cross-zone latency:** Typically less than 2ms within an Azure region, acceptable for Kafka inter-broker replication.
- **Zone-pinned disks:** Premium SSD v2 disks are zonal resources — they must be created in the same zone as the VM they attach to.

### VM Extensions and Monitoring

- **Azure Monitor Agent (AMA):** Deploy via the `AzureMonitorLinuxAgent` VM extension on all VMs. This is the current-generation monitoring agent replacing the deprecated Linux Diagnostics Extension (LAD, EOL March 2026).
- **Data Collection Rules (DCR):** Configure DCRs to collect syslog, performance counters (CPU, memory, disk IOPS, network), and Kafka-specific application logs. Route to a Log Analytics workspace.
- **VM Insights:** Enable for out-of-the-box dashboards covering CPU, memory, disk, and network metrics per VM.
- **Custom Script Extension:** Use `Microsoft.Azure.Extensions.CustomScript` for post-provisioning configuration (Confluent Platform install, disk formatting, sysctl tuning).
- **AADSSHLogin extension:** `Microsoft.Azure.ActiveDirectory.AADSSHLoginForLinux` enables Entra ID SSH login, complementing UAMI-based authentication.

### VM Scale Sets vs Individual VMs

- **Decision: Use individual VMs for all Kafka Lab components.**
- **Rationale:**
  - Kafka brokers are stateful with persistent disk identity — each broker has a unique `broker.id`, advertised listeners, and zone-pinned data disks. VMSS replacement operations can lose this identity.
  - A 3-broker cluster is small and static; VMSS autoscaling provides no benefit.
  - Individual VMs offer full per-node customization, simpler disk management, and deterministic zone placement.
  - VMSS Flexible Orchestration mode could work for larger dynamic clusters but adds complexity without benefit at lab scale.
  - ZooKeeper nodes are similarly stateful and require stable identity; individual VMs are appropriate.

### Ubuntu 22.04 LTS Azure Considerations

- **Image:** Use the Canonical marketplace image `Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest`. This ships with the `linux-azure` optimized kernel, Azure Linux Agent (waagent), and cloud-init integration.
- **Azure-tuned kernel:** The `-azure` kernel variant includes optimized Hyper-V drivers, accelerated networking support, and virtualization-friendly I/O scheduling.
- **Kafka-specific sysctl tuning (apply via cloud-init or Custom Script Extension):**
  - `vm.swappiness=1` — near-disable swapping (Kafka strongly prefers no swap)
  - `vm.dirty_ratio=80` — allow large dirty page cache before forced writeback
  - `vm.dirty_background_ratio=5` — start background writeback early
  - `net.core.wmem_max=2097152` — increase socket write buffer for replication
  - `net.core.rmem_max=2097152` — increase socket read buffer
  - `net.ipv4.tcp_window_scaling=1` — enable TCP window scaling
  - `fs.file-max=1000000` — raise open file descriptor limit for high partition counts
  - `net.core.somaxconn=4096` — raise connection backlog
- **Unattended upgrades:** Enabled by default for security patches. Consider disabling `unattended-upgrades` for Kafka data nodes and managing patching through a controlled maintenance window instead.
- **Gen2 VM:** Use Generation 2 VMs for UEFI boot, larger OS disk support, and Trusted Launch compatibility.

## Architecture / Design Decisions

### Decision 1: Esv5 over Lsv3 for Kafka Brokers

**Choice:** Standard_E8s_v5 (memory-optimized) over Standard_L8s_v3 (storage-optimized with local NVMe).

**Rationale:** The Lsv3 series provides local NVMe SSDs with exceptional IOPS, but these disks are ephemeral — data is lost on VM deallocation, stop, or host maintenance. For a lab that may be stopped and restarted, persistent Premium SSD v2 managed disks with CMEK encryption are required. The E8s_v5 provides 64 GiB RAM (adequate page cache for a lab workload), supports Premium SSD, and costs less than Lsv3. The 12,800 uncached IOPS ceiling is sufficient for a lab-scale Kafka cluster.

### Decision 2: Premium SSD v2 with LVM Striping

**Choice:** 2 × 512 GiB Premium SSD v2 per broker, striped with LVM.

**Rationale:** Premium SSD v2 decouples IOPS/throughput from disk size, avoiding over-provisioning capacity to get performance. LVM striping across 2 disks doubles aggregate IOPS and throughput while keeping the configuration simple. Kafka's `log.dirs` points to a single LVM mount, and Kafka handles partition distribution internally. CMEK encryption is applied per disk.

### Decision 3: Zone Pinning over Availability Sets

**Choice:** Pin each broker VM to a specific availability zone using the `zones` parameter in Terraform.

**Rationale:** Zone pinning provides datacenter-level fault isolation (99.99% SLA) versus rack-level (99.95% for availability sets). With 3 brokers and `min.insync.replicas=2`, the cluster can tolerate a full zone outage without data loss. Zone pinning is also simpler to model in Terraform — each VM resource specifies `zones = ["1"]`, `["2"]`, or `["3"]`.

### Decision 4: Individual VMs over VMSS

**Choice:** Deploy each Kafka broker, ZooKeeper node, and ancillary service as an individual `azurerm_linux_virtual_machine` resource.

**Rationale:** Stateful workloads with stable identity requirements (broker IDs, zone-pinned disks, advertised hostnames) are better served by individual VMs. The cluster size is fixed at 3 brokers per region — there is no scaling benefit from VMSS. Individual VMs provide full control over per-node disk attachment, zone placement, and configuration.

### Decision 5: Azure Monitor Agent for Observability

**Choice:** Deploy AMA via VM extension with Data Collection Rules.

**Rationale:** AMA is the current-generation agent (LAD deprecated March 2026). DCRs provide granular control over what telemetry is collected and where it is routed. AMA supports Managed Identity authentication, aligning with the project's UAMI requirement.

## Configuration Reference

### Terraform VM Resource (Broker Example)

```hcl
resource "azurerm_linux_virtual_machine" "kafka_broker" {
  count               = 3
  name                = "vm-kafka-broker-${count.index}-scus"
  resource_group_name = "klc-rg-kafkalab-scus"
  location            = "southcentralus"
  zone                = tostring(count.index + 1)
  size                = "Standard_E8s_v5"

  admin_username                  = "kafkaadmin"
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.kafka_broker[count.index].id]

  os_disk {
    name                   = "osdisk-kafka-broker-${count.index}-scus"
    caching                = "ReadWrite"
    storage_account_type   = "Premium_LRS"
    disk_size_gb           = 128
    disk_encryption_set_id = azurerm_disk_encryption_set.kafka_broker_os[count.index].id
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.kafka_broker.id]
  }

  tags = {
    environment = "lab"
    component   = "kafka-broker"
    zone        = tostring(count.index + 1)
  }
}
```

### Terraform Data Disk (Premium SSD v2)

```hcl
resource "azurerm_managed_disk" "kafka_data" {
  count                = 6 // 2 disks × 3 brokers
  name                 = "disk-kafka-data-${count.index}-scus"
  location             = "southcentralus"
  zone                 = tostring((count.index % 3) + 1)
  resource_group_name  = "klc-rg-kafkalab-scus"
  storage_account_type = "PremiumV2_LRS"
  disk_size_gb         = 512

  disk_iops_read_write = 5000
  disk_mbps_read_write = 250

  disk_encryption_set_id = azurerm_disk_encryption_set.kafka_data[count.index].id

  tags = {
    component = "kafka-broker"
    purpose   = "kafka-data"
  }
}
```

### LVM Striping and Mount (cloud-init / Custom Script)

```bash
#!/bin/bash
// Create physical volumes on both data disks
pvcreate /dev/sdc /dev/sdd

// Create volume group
vgcreate vg_kafka /dev/sdc /dev/sdd

// Create striped logical volume (2 stripes, 256K stripe size)
lvcreate -l 100%FREE -n lv_kafka -i 2 -I 256K vg_kafka

// Format with XFS
mkfs.xfs /dev/vg_kafka/lv_kafka

// Create mount point and mount
mkdir -p /kafka/data
mount -o noatime,nodiratime /dev/vg_kafka/lv_kafka /kafka/data

// Persist in fstab
echo '/dev/vg_kafka/lv_kafka /kafka/data xfs noatime,nodiratime 0 2' >> /etc/fstab

// Set ownership
chown -R cp-kafka:confluent /kafka/data
```

### Kafka Broker sysctl Tuning

```bash
cat > /etc/sysctl.d/99-kafka.conf << 'EOF'
vm.swappiness=1
vm.dirty_ratio=80
vm.dirty_background_ratio=5
net.core.wmem_max=2097152
net.core.rmem_max=2097152
net.ipv4.tcp_window_scaling=1
net.core.somaxconn=4096
fs.file-max=1000000
EOF

sysctl --system
```

### Kafka Broker server.properties (disk-related)

```properties
log.dirs=/kafka/data
num.io.threads=8
num.network.threads=8
log.flush.interval.messages=10000
log.flush.interval.ms=1000
log.retention.hours=168
log.segment.bytes=1073741824
```

### Azure Monitor Agent Extension (Terraform)

```hcl
resource "azurerm_virtual_machine_extension" "ama" {
  count                      = 3
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.kafka_broker[count.index].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.33"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true

  settings = jsonencode({
    authentication = {
      managedIdentity = {
        identifier-name  = "mi_res_id"
        identifier-value = azurerm_user_assigned_identity.kafka_broker.id
      }
    }
  })
}
```

## Risks and Open Questions

1. **mexicocentral and canadaeast AZ support:** These regions may have limited availability zone support (potentially only 1 zone). If fewer than 3 zones are available, all 3 brokers in that region share a single zone, reducing fault isolation to fault-domain level only. Verify zone count at deployment time via `az vm list-skus --location mexicocentral --resource-type virtualMachines --query "[?name=='Standard_E8s_v5'].locationInfo[0].zoneDetails"`.
2. **Premium SSD v2 regional availability:** PremiumV2_LRS may not be available in all regions or all zones. Validate availability in mexicocentral and canadaeast before finalizing disk configuration. Fallback: Premium SSD v1 (P30 tier, 5,000 IOPS / 200 MB/s).
3. **Cross-zone replication latency:** While typically less than 2ms, network latency between zones should be measured with `iperf3` or Kafka's own replication metrics after deployment. High latency could affect `acks=all` producer performance.
4. **CMEK key per disk overhead:** The project requires one CMK per resource. With 2 data disks + 1 OS disk × 3 brokers × 3 regions = 27 keys for brokers alone, plus ZooKeeper and ancillary VMs. Key Vault and Disk Encryption Set management may require automation.
5. **Esv5 uncached IOPS ceiling:** The Standard_E8s_v5 caps at 12,800 uncached IOPS. If the LVM stripe delivers 10,000 IOPS from 2 disks, this is within the VM limit but leaves limited headroom. Monitor via Azure Metrics and consider E16s_v5 (25,600 IOPS) if the lab workload grows.
6. **Ephemeral OS disk option:** Esv5 series does not include local temp storage. If ephemeral OS disks are desired (for faster boot and lower cost), the Edsv5 series (with local temp disk) would be needed. Not critical for a lab.
7. **Unattended upgrades risk:** Default Ubuntu unattended-upgrades could restart services or the kernel during operation. Recommend disabling for data-plane VMs and managing updates through a controlled window.
8. **Confluent Platform version lock:** Research is based on Confluent Platform 7.x requirements. If upgrading to 8.x (KRaft mode, no ZooKeeper), the ZooKeeper VM tier becomes unnecessary and broker requirements may change.

## References

- [Azure Virtual Machines overview](https://learn.microsoft.com/en-us/azure/virtual-machines/overview)
- [Azure availability zones overview](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview)
- [Azure managed disk types](https://learn.microsoft.com/en-us/azure/virtual-machines/disks-types)
- [Ev5 series VM specifications](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/memory-optimized/ev5-series)
- [Azure Premium SSD v2 performance design](https://learn.microsoft.com/en-us/azure/virtual-machines/premium-storage-performance)
- [Confluent Platform production deployment](https://docs.confluent.io/platform/current/kafka/deployment.html)
- [Kafka on Azure — AxonOps deployment guide](https://axonops.com/docs/data-platforms/kafka/cloud/azure/)
- [Azure Monitor Agent management](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-manage)
- [VMSS orchestration modes](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-orchestration-modes)
- [Azure VM architecture best practices](https://learn.microsoft.com/en-us/azure/well-architected/service-guides/virtual-machines)
- [Terraform Azure Confluent Platform module](https://github.com/osodevops/terraform-azure-confluent-platform)
- [Ubuntu 22.04 LTS on Azure](https://ubuntu.com/azure)
- [Confluent Schema Registry multi-DC deployment](https://docs.confluent.io/platform/current/schema-registry/multidc.html)
