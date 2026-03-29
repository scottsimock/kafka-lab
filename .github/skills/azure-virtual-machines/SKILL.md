---
name: azure-virtual-machines
description: Provision and manage Azure Virtual Machines with Terraform AzAPI and configure them with Ansible. Use when agents need to deploy VMs across regions and availability zones, configure OS-level software, or manage VM lifecycle operations.
---

# Azure Virtual Machines

Azure Virtual Machines provide on-demand, scalable compute resources with full control over the OS and runtime environment. VMs support Linux and Windows, can be placed in specific availability zones for resilience, and integrate with VNets, managed disks, and managed identities.

## Overview

- **Category**: Compute
- **Key capability**: Full OS control for workloads requiring custom software (e.g., Confluent Kafka brokers)
- **When to use**: Applications needing direct OS access, custom kernel configurations, or software that cannot run in PaaS services

## Key Concepts

### VM Sizes and Series

Azure offers VM families optimized for different workloads. For Kafka brokers, memory-optimized (E-series) or general-purpose (D-series) are typical choices. Each size defines vCPUs, RAM, max data disks, and network bandwidth.

### Availability Zones

VMs can be pinned to specific availability zones within a region for high availability. Each zone is an independent fault domain with its own power, cooling, and networking.

### Managed Disks

Azure Managed Disks provide block-level storage for VMs. OS disks and data disks are provisioned separately. Premium SSD is recommended for production Kafka workloads requiring high IOPS.

### Trusted Launch

Default for Generation 2 VMs. Provides Secure Boot, vTPM, and boot integrity monitoring to protect against rootkits and boot-level malware.

### User Assigned Managed Identity

VMs authenticate to other Azure services via a User Assigned Managed Identity (UAMI), avoiding stored credentials.

## Provisioning with Terraform AzAPI

See [getting-started/main.tf](sample_codes/getting-started/main.tf) for a complete VM deployment example.

### AzAPI Resource Types

| Resource Type | API Version | Purpose |
|---|---|---|
| `Microsoft.Compute/virtualMachines` | `2024-11-01` | VM resource |
| `Microsoft.Network/networkInterfaces` | `2024-05-01` | NIC attached to VM |
| `Microsoft.Compute/disks` | `2024-03-02` | Managed data disks |
| `Microsoft.ManagedIdentity/userAssignedIdentities` | `2023-01-31` | UAMI for authentication |

## Configuration with Ansible

After provisioning, use Ansible to configure the VM OS, install packages, and deploy application software. See [common-patterns/configure-vm.yml](sample_codes/common-patterns/configure-vm.yml).

## Common Patterns

### Multi-Zone Deployment

Deploy VMs across availability zones using `for_each` with zone assignments. See [common-patterns/multi-zone.tf](sample_codes/common-patterns/multi-zone.tf).

### Data Disk Attachment

Attach additional managed disks for application data (e.g., Kafka log directories). See [common-patterns/data-disks.tf](sample_codes/common-patterns/data-disks.tf).

## Best Practices

- **Do**: Pin VMs to specific availability zones for HA deployments
- **Do**: Use Premium SSD managed disks for production workloads
- **Do**: Assign a dedicated UAMI per VM workflow
- **Do**: Use Trusted Launch (Generation 2) for all new VMs
- **Avoid**: Public IP addresses on VMs; use Azure Bastion or VPN for management access
- **Avoid**: Sharing managed identities across unrelated workloads

## Troubleshooting

| Issue | Solution |
|---|---|
| VM allocation failure in zone | Check zone capacity; try a different VM size or zone |
| SSH connection timeout | Verify NSG rules allow port 22 from your source; check VNet routing |
| Disk IOPS throttling | Upgrade to a larger disk tier or enable host caching |

For more issues: `microsoft_docs_search(query="azure virtual machines troubleshoot {symptom}")`

## Learn More

| Topic | How to Find |
|---|---|
| VM sizes reference | `microsoft_docs_search(query="azure virtual machine sizes overview")` |
| Availability zones | `microsoft_docs_fetch(url="https://learn.microsoft.com/azure/reliability/availability-zones-overview")` |
| ARM template reference | `microsoft_docs_fetch(url="https://learn.microsoft.com/azure/templates/microsoft.compute/2024-11-01/virtualmachines")` |
| Cloud-init | `microsoft_docs_search(query="azure virtual machines cloud-init linux")` |
| Pricing | `microsoft_docs_search(query="azure virtual machines pricing linux")` |

## CLI Alternative

If the Learn MCP server is not available, use the `mslearn` CLI instead:

| MCP Tool | CLI Command |
|---|---|
| `microsoft_docs_search(query: "...")` | `mslearn search "..."` |
| `microsoft_code_sample_search(query: "...", language: "...")` | `mslearn code-search "..." --language ...` |
| `microsoft_docs_fetch(url: "...")` | `mslearn fetch "..."` |

Run directly with `npx @microsoft/learn-cli <command>` or install globally with `npm install -g @microsoft/learn-cli`.
