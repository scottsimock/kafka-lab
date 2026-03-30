---
id: doc-12
title: SP0.007 — Azure Virtual Machines for Kafka
type: other
created_date: '2026-03-30 15:53'
---
# SP0.007 — Azure Virtual Machines for Kafka

## Executive Summary

Deploying Confluent Kafka on Azure requires careful VM selection that balances CPU, memory, network throughput, and storage I/O. The kafka-lab project uses two VM SKUs from the Dsv5-series: **Standard_D4s_v5** (4 vCPU / 16 GB RAM) for Kafka brokers, and **Standard_D2s_v5** (2 vCPU / 8 GB RAM) for ZooKeeper, Schema Registry, and Kafka Connect nodes. Both run on Intel Xeon Platinum processors (Sapphire Rapids / Ice Lake / Emerald Rapids) at up to 3.5 GHz with AVX-512, support Premium Storage (including Premium SSD v2 and Ultra Disk), and require Accelerated Networking (SR-IOV) — making them well-suited for distributed messaging workloads demanding consistent low-latency I/O and high network throughput.

Disk strategy separates concerns by tier: a 64 GB Premium SSD P6 OS disk handles the operating system, while dedicated Premium SSD P30/P40 data disks serve Kafka log directories. For scenarios requiring sub-millisecond storage latency or workloads exceeding 5,000 IOPS per disk, Premium SSD v2 (configurable IOPS/throughput without resizing) or Ultra Disk (up to 400,000 IOPS per disk) are viable alternatives. OS disks use Premium SSD; neither Ultra Disk nor Premium SSD v2 can be used as OS disks.

Availability zone placement ensures fault isolation: brokers are distributed across southcentralus Zone 1 (primary) and Zone 2 (HA replica), providing independent power, cooling, and network paths. ZooKeeper and ancillary services (Schema Registry, Kafka Connect) are deployed in the same region and zone as their associated brokers. Disaster recovery nodes land in mexicocentral Zone 1 and canadaeast Zone 1. This multi-zone topology, combined with Confluent's rack-awareness (`broker.rack`), ensures that a single AZ failure does not take down any topic with replication factor ≥ 2.

---

## VM Sizing Rationale

| Component | VM SKU | vCPUs | RAM (GB) | Max Data Disks | Uncached IOPS | Network (Mbps) | Rationale |
|---|---|---|---|---|---|---|---|
| Kafka Broker | Standard_D4s_v5 | 4 | 16 | 8 | 6,400 | 12,500 | Confluent recommends ≥4 cores for broker JVM; 16 GB provides heap (6 GB) + page cache headroom for active segments |
| ZooKeeper | Standard_D2s_v5 | 2 | 8 | 4 | 3,750 | 12,500 | ZK is coordination-only, low CPU; 8 GB supports ZK JVM (2 GB) with OS overhead |
| Schema Registry | Standard_D2s_v5 | 2 | 8 | 4 | 3,750 | 12,500 | Stateless registry caches schemas in memory; modest CPU/RAM sufficient |
| Kafka Connect | Standard_D2s_v5 | 2 | 8 | 4 | 3,750 | 12,500 | Connect workers are I/O-bound more than CPU-bound for moderate connector counts |

**Confluent Platform sizing notes:**
- Kafka brokers require at least 4 vCPUs in production for concurrent partition leadership and replication; 8+ vCPUs recommended for high-throughput clusters.
- 16 GB RAM per broker: allocate 6 GB to the Kafka JVM heap (`-Xms6g -Xmx6g`), leaving ~10 GB for OS page cache — the critical hot-path for read performance.
- D4s_v5 supports up to 8 attached data disks and 12,500 Mbps network; both ceilings are sufficient for a small-to-medium cluster.
- ZooKeeper's JVM should be set to 2–4 GB heap; 8 GB total RAM is adequate for a 3-node ensemble.
- All Dsv5 sizes require Accelerated Networking (it is mandatory, not optional, for this series).

---

## Disk Configuration

### OS Disk

| Property | Value |
|---|---|
| Disk type | Premium SSD (P6) |
| Size | 64 GiB |
| IOPS (provisioned) | 240 |
| Throughput | 50 MB/s |
| Caching | ReadWrite |
| Notes | OS disk only; no Kafka data stored here |

### Kafka Log Data Disks

| Disk Tier | Size (GiB) | Base IOPS | Base Throughput | Burst IOPS | Burst Throughput | Use Case |
|---|---|---|---|---|---|---|
| Premium SSD P30 | 1,024 | 5,000 | 200 MB/s | 30,000 | 1,000 MB/s | Standard broker: ≤100 GB/day ingest, ≤3,000 IOPS steady state |
| Premium SSD P40 | 2,048 | 7,500 | 250 MB/s | 30,000 | 1,000 MB/s | High-partition broker: ≤200 GB/day ingest, up to 7,500 IOPS steady state |
| Premium SSD v2 | 256–2,048 (configurable) | 3,000–80,000 (configurable) | 125–1,200 MB/s (configurable) | N/A | N/A | Workloads needing independent IOPS/throughput tuning without disk resize |
| Ultra Disk | 512–2,048 | Up to 400,000 | Up to 10,000 MB/s | N/A | N/A | Mission-critical, sub-ms latency, very high IOPS requirements |

**Recommendations:**
- **Default (Kafka brokers):** Attach one P40 (2 TB) data disk per broker as the Kafka log directory (`/kafka/data`). The P40's 7,500 base IOPS and 250 MB/s throughput handle typical medium-throughput clusters without bursting.
- **Premium SSD v2** is the best cost-performance choice when IOPS or throughput needs vary over time — pay for exactly what you provision. Requires the VM to be zonal (which all brokers in this design are).
- **Ultra Disk** is reserved for latency-sensitive scenarios (sub-1ms P99 is demonstrably required). Ultra Disk is not available in every zone of southcentralus; verify availability before using. South Central US currently supports Ultra Disk in one availability zone only.
- **Neither Ultra Disk nor Premium SSD v2 can be used as an OS disk.** Always use a separate Premium SSD for the OS.
- Format all data disks with XFS and mount with `noatime,nodiratime` to reduce unnecessary metadata writes on Kafka log directories.

---

## Availability Zone Placement

### Strategy

| Region | Zone | Role | Components |
|---|---|---|---|
| southcentralus | Zone 1 | Primary | Primary Kafka brokers, ZooKeeper leaders |
| southcentralus | Zone 2 | HA Replica | Replica Kafka brokers, ZooKeeper followers |
| mexicocentral | Zone 1 | Secondary | Secondary brokers, ZooKeeper observers |
| canadaeast | Zone 1 | DR | DR brokers, ZooKeeper (if needed) |

### Zone Fault Domains

Azure Availability Zones are physically separate datacenters within a region, each with independent power, cooling, and networking. Zone-level failures (hardware faults, power outages) affect only a single zone, leaving the other zones unaffected. South Central US has three availability zones; mexicocentral and canadaeast each have at least one AZ that supports zonal VM deployment.

### Kafka Rack Awareness

Set `broker.rack` on each Kafka broker to the availability zone identifier (e.g., `1`, `2`). Confluent replication will then spread partition replicas across racks (zones), ensuring that a single AZ failure does not cause data loss for topics with replication factor ≥ 2.

```properties
# /etc/kafka/server.properties
broker.rack=1   # Zone 1 brokers
broker.rack=2   # Zone 2 brokers
```

### ZooKeeper Quorum Distribution

For a 3-node ZooKeeper ensemble across two zones in southcentralus, place 2 nodes in Zone 1 and 1 node in Zone 2. This ensures quorum survives a Zone 2 failure. For 5-node ensembles, distribute as 3 + 2.

### Premium SSD v2 and Ultra Disk Zone Constraints

- Premium SSD v2 requires the attached VM to be **zonal** (not regional/availability set). All VMs in this design are zonal, so this constraint is satisfied.
- Ultra Disk in southcentralus is available in **one availability zone only** — confirm AZ support via `az vm list-skus` before deploying Ultra Disks to Zone 2.

---

## Accelerated Networking

### What It Is

Accelerated Networking enables **Single Root I/O Virtualization (SR-IOV)** on supported VM types. It bypasses the Azure host virtual switch and delivers network packets directly from the physical NIC to the VM's network interface, eliminating host-side policy processing latency.

### Benefits for Kafka

| Metric | Without Accelerated Networking | With Accelerated Networking |
|---|---|---|
| Latency | ~1ms+ (host vSwitch adds jitter) | ~25 µs hardware path |
| Packet throughput | Limited by vSwitch CPU | Near line-rate NIC speed |
| CPU overhead | Host CPU consumed for net processing | NIC hardware offloads policy enforcement |
| Jitter | Variable (depends on host CPU load) | Minimal (hardware deterministic) |

### Requirements

- VM must be **stopped and deallocated** before enabling Accelerated Networking — it cannot be enabled on a running VM.
- Accelerated Networking is **required** (not optional) on Dsv5-series VMs; the platform enforces this.
- Ubuntu 22.04 LTS ships with native SR-IOV driver support out of the box (mlx4/mlx5 for ConnectX NICs, MANA for Microsoft Azure Network Adapter).
- Custom images must include NVIDIA ConnectX-3/4/5 or MANA drivers and handle dynamic VF binding/revocation (live migration revokes VF temporarily; the guest must bind to the synthetic NIC, not the VF directly).

### NIC Configuration

Each Kafka VM uses a **single NIC** with:
- Private IP assigned statically from the subnet address space (set `privateIPAllocationMethod: Static` in the Terraform resource).
- DNS settings inherit from the VNet (Azure-provided DNS resolves `privatelink.*` zones via Private DNS Zone links).
- No public IP — all access is via private endpoints or jump host within the VNet.
- `enableAcceleratedNetworking: true` in the NIC resource properties.

### Enabling via Azure CLI (reference)

```bash
az network nic update \
  --resource-group klc-rg-kafkalab-scus \
  --name <nic-name> \
  --accelerated-networking true
```

Note: the VM must be deallocated first; the CLI will error if the VM is running.

---

## OS Hardening Baseline

### Base Image

**Ubuntu 22.04 LTS (Jammy Jellyfish)** — Azure Marketplace image `Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest`. Generation 2 VM preferred for Secure Boot and vTPM support. Ubuntu 22.04 is explicitly listed as an Accelerated Networking-supported distribution.

### Kernel Parameters (`/etc/sysctl.d/99-kafka.conf`)

```ini
# Reduce swapping aggressively; Kafka relies on OS page cache
vm.swappiness = 1

# Max socket backlog for high-connection-rate brokers
net.core.somaxconn = 65535

# SYN backlog
net.ipv4.tcp_max_syn_backlog = 65535

# File descriptor maximum (system-wide)
fs.file-max = 2097152

# Network receive/send buffers (128 MB)
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576

# TCP receive/send buffer ranges
net.ipv4.tcp_rmem = 4096 1048576 134217728
net.ipv4.tcp_wmem = 4096 1048576 134217728

# Enable TCP fast recycling and reuse for TIME_WAIT connections
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15

# Virtual memory — allow high dirty page ratio for sequential write batching
vm.dirty_ratio = 80
vm.dirty_background_ratio = 5

# Disable transparent hugepages kernel management (set to madvise; runtime THP is handled below)
# Applied via rc.local or systemd unit; not a sysctl key
```

### File Descriptor Limits (`/etc/security/limits.d/99-kafka.conf`)

```ini
kafka soft nofile 1000000
kafka hard nofile 1000000
kafka soft nproc 65536
kafka hard nproc 65536
root soft nofile 1000000
root hard nofile 1000000
```

### Disk Scheduler

For Premium SSD and Ultra Disk (NVMe/SCSI-backed managed disks), use the `mq-deadline` or `none` (noop) I/O scheduler rather than `cfq`. Set via udev rule:

```bash
# /etc/udev/rules.d/60-kafka-disk-scheduler.rules
ACTION=="add|change", KERNEL=="sd[b-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
```

### Transparent Huge Pages

Disable THP to avoid latency spikes from page compaction:

```bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
```

Add to `/etc/rc.local` or a systemd `ExecStartPost` unit to persist across reboots.

### NTP / Chrony

Kafka and ZooKeeper are sensitive to clock skew. Ensure chrony is configured and synchronized:

```bash
apt-get install -y chrony
systemctl enable --now chrony
```

Azure VMs can use the Azure host time source (`169.254.169.254`) via the `azure-vm-utils` package, which is pre-installed on Ubuntu Marketplace images.

### Java

Install OpenJDK 17 (Confluent Platform 7.x recommends JDK 11 or 17):

```bash
apt-get install -y openjdk-17-jdk-headless
```

Set `JAVA_HOME` in `/etc/environment`:

```bash
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
```

---

## Cloud-Init Configuration

The following cloud-init YAML bootstraps a Kafka broker VM: mounts the data disk, applies kernel tuning, installs Java, and creates the `kafka` OS user.

```yaml
#cloud-config

# ── Package updates ──────────────────────────────────────────────────────────
package_update: true
package_upgrade: true

packages:
  - openjdk-17-jdk-headless
  - chrony
  - xfsprogs
  - util-linux
  - ntp

# ── OS Users ──────────────────────────────────────────────────────────────────
users:
  - name: kafka
    system: true
    shell: /usr/sbin/nologin
    home: /opt/kafka
    no_create_home: false

# ── File writes ───────────────────────────────────────────────────────────────
write_files:
  - path: /etc/sysctl.d/99-kafka.conf
    permissions: '0644'
    content: |
      vm.swappiness = 1
      net.core.somaxconn = 65535
      net.ipv4.tcp_max_syn_backlog = 65535
      fs.file-max = 2097152
      net.core.rmem_max = 134217728
      net.core.wmem_max = 134217728
      net.ipv4.tcp_rmem = 4096 1048576 134217728
      net.ipv4.tcp_wmem = 4096 1048576 134217728
      net.ipv4.tcp_tw_reuse = 1
      net.ipv4.tcp_fin_timeout = 15
      vm.dirty_ratio = 80
      vm.dirty_background_ratio = 5

  - path: /etc/security/limits.d/99-kafka.conf
    permissions: '0644'
    content: |
      kafka soft nofile 1000000
      kafka hard nofile 1000000
      kafka soft nproc 65536
      kafka hard nproc 65536
      root  soft nofile 1000000
      root  hard nofile 1000000

  - path: /etc/udev/rules.d/60-kafka-disk.rules
    permissions: '0644'
    content: |
      ACTION=="add|change", KERNEL=="sd[b-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"

  - path: /etc/environment
    permissions: '0644'
    append: true
    content: |
      JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# ── Boot commands (run once, before runcmd) ───────────────────────────────────
bootcmd:
  - echo never > /sys/kernel/mm/transparent_hugepage/enabled
  - echo never > /sys/kernel/mm/transparent_hugepage/defrag

# ── Run commands ──────────────────────────────────────────────────────────────
runcmd:
  # Apply kernel parameters
  - sysctl --system

  # Format and mount the data disk (second disk, /dev/sdc on Azure)
  # /dev/sdc is the first attached data disk after the OS disk
  - |
    if ! blkid /dev/sdc | grep -q xfs; then
      mkfs.xfs -f /dev/sdc
    fi
  - mkdir -p /kafka/data
  - |
    DISK_UUID=$(blkid -s UUID -o value /dev/sdc)
    if ! grep -q "$DISK_UUID" /etc/fstab; then
      echo "UUID=$DISK_UUID /kafka/data xfs defaults,noatime,nodiratime 0 2" >> /etc/fstab
    fi
  - mount -a

  # Set ownership for kafka user
  - chown -R kafka:kafka /kafka/data

  # Enable and start chrony
  - systemctl enable --now chrony

  # Disable THP permanently via systemd
  - |
    cat > /etc/systemd/system/disable-thp.service <<'EOF'
    [Unit]
    Description=Disable Transparent Huge Pages
    After=sysinit.target local-fs.target
    Before=kafka.service

    [Service]
    Type=oneshot
    ExecStart=/bin/sh -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled && echo never > /sys/kernel/mm/transparent_hugepage/defrag'
    RemainAfterExit=yes

    [Install]
    WantedBy=multi-user.target
    EOF
  - systemctl daemon-reload
  - systemctl enable disable-thp.service
```

---

## Example Terraform AzAPI

The following illustrates an AzAPI resource block for a Kafka broker VM in southcentralus Zone 1. It includes managed disk attachment, AZ placement, Accelerated Networking, and User Assigned Managed Identity.

```hcl
// =====================================================
// User Assigned Managed Identity (per VM)
// =====================================================
resource "azapi_resource" "kafka_broker_uami" {
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  name      = "uami-kafka-broker-${var.broker_index}-scus"
  location  = "southcentralus"
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/klc-rg-kafkalab-scus"
}

// =====================================================
// OS Disk — Premium SSD P6 (64 GiB)
// =====================================================
// Provisioned inline via storageProfile.osDisk; no separate azapi_resource needed.

// =====================================================
// Data Disk — Premium SSD P40 (2048 GiB) for Kafka logs
// =====================================================
resource "azapi_resource" "kafka_broker_data_disk" {
  type      = "Microsoft.Compute/disks@2024-03-02"
  name      = "disk-kafka-broker-${var.broker_index}-data-scus"
  location  = "southcentralus"
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/klc-rg-kafkalab-scus"

  body = {
    sku = {
      name = "Premium_LRS"
    }
    zones    = ["1"]
    properties = {
      diskSizeGB    = 2048
      creationData  = { createOption = "Empty" }
      encryption = {
        type                      = "EncryptionAtRestWithCustomerKey"
        diskEncryptionSetId       = var.disk_encryption_set_id
      }
    }
  }
}

// =====================================================
// NIC — single NIC, private IP, Accelerated Networking
// =====================================================
resource "azapi_resource" "kafka_broker_nic" {
  type      = "Microsoft.Network/networkInterfaces@2024-01-01"
  name      = "nic-kafka-broker-${var.broker_index}-scus"
  location  = "southcentralus"
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/klc-rg-kafkalab-scus"

  body = {
    properties = {
      enableAcceleratedNetworking = true
      ipConfigurations = [
        {
          name = "ipconfig1"
          properties = {
            subnet                          = { id = var.broker_subnet_id }
            privateIPAllocationMethod       = "Static"
            privateIPAddress                = var.broker_private_ip
            privateIPAddressVersion         = "IPv4"
          }
        }
      ]
    }
  }
}

// =====================================================
// Kafka Broker VM
// =====================================================
resource "azapi_resource" "kafka_broker_vm" {
  type      = "Microsoft.Compute/virtualMachines@2024-07-01"
  name      = "vm-kafka-broker-${var.broker_index}-scus"
  location  = "southcentralus"
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/klc-rg-kafkalab-scus"

  // Place in Zone 1; change to "2" for HA replica brokers
  zones = ["1"]

  identity = {
    type = "UserAssigned"
    userAssignedIdentities = {
      (azapi_resource.kafka_broker_uami.id) = {}
    }
  }

  body = {
    properties = {
      hardwareProfile = {
        vmSize = "Standard_D4s_v5"
      }

      storageProfile = {
        imageReference = {
          publisher = "Canonical"
          offer     = "0001-com-ubuntu-server-jammy"
          sku       = "22_04-lts-gen2"
          version   = "latest"
        }
        osDisk = {
          name         = "osdisk-kafka-broker-${var.broker_index}-scus"
          createOption = "FromImage"
          managedDisk = {
            storageAccountType  = "Premium_LRS"
            diskEncryptionSet   = { id = var.disk_encryption_set_id }
          }
          diskSizeGB = 64
          caching    = "ReadWrite"
        }
        dataDisks = [
          {
            lun          = 0
            createOption = "Attach"
            caching      = "None"
            managedDisk  = { id = azapi_resource.kafka_broker_data_disk.id }
          }
        ]
      }

      osProfile = {
        computerName       = "kafka-broker-${var.broker_index}"
        adminUsername      = "kafkaadmin"
        // SSH public key auth only — no password
        linuxConfiguration = {
          disablePasswordAuthentication = true
          ssh = {
            publicKeys = [
              {
                path    = "/home/kafkaadmin/.ssh/authorized_keys"
                keyData = var.ssh_public_key
              }
            ]
          }
        }
        customData = base64encode(file("${path.module}/cloud-init/kafka-broker.yaml"))
      }

      networkProfile = {
        networkInterfaces = [
          {
            id = azapi_resource.kafka_broker_nic.id
            properties = { primary = true }
          }
        ]
      }

      diagnosticsProfile = {
        bootDiagnostics = { enabled = true }
      }
    }
  }

  tags = {
    component   = "kafka-broker"
    sprint      = "SP0"
    environment = "lab"
    zone        = "1"
    region      = "southcentralus"
  }
}
```

> **Notes:**
> - `diskEncryptionSet` provides CMEK (Customer Managed Key) encryption as required by the project compliance rules.
> - Set `zones = ["2"]` for HA replica brokers in southcentralus Zone 2.
> - For ZooKeeper and ancillary nodes, change `vmSize` to `"Standard_D2s_v5"` and reduce the data disk to a P30 (1024 GiB).
> - `customData` is the base64-encoded cloud-init YAML from the section above.
> - The NIC has `enableAcceleratedNetworking: true`; this is mandatory for Dsv5-series and cannot be toggled while the VM is running.

---

## References

| Source | URL |
|---|---|
| Azure Dsv5-series VM specs | <https://learn.microsoft.com/en-us/azure/virtual-machines/dv5-dsv5-series> |
| Azure Dsv5-series (sizes page) | <https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dsv5-series> |
| Azure Managed Disk Types | <https://learn.microsoft.com/en-us/azure/virtual-machines/disks-types> |
| Azure Accelerated Networking Overview | <https://learn.microsoft.com/en-us/azure/virtual-network/accelerated-networking-overview> |
| Azure VM overview | <https://learn.microsoft.com/en-us/azure/virtual-machines/overview> |
| Confluent Platform Deployment Guide | <https://docs.confluent.io/platform/current/kafka/deployment.html> |
| Azure Premium Storage Performance | <https://learn.microsoft.com/en-us/azure/virtual-machines/premium-storage-performance> |
| Confluent Platform Sizing Guide | <https://docs.confluent.io/platform/current/kafka/sizing.html> |
| Azure VM Networking — Accelerated Networking | <https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-network-interface> |
