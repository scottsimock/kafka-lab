---
name: azure-virtual-network
description: Provision and manage Azure Virtual Networks with Terraform AzAPI. Use when agents need to create VNets, subnets, NSGs, VNet peering, or configure network security across regions and availability zones.
---

# Azure Virtual Network

Azure Virtual Network (VNet) is the fundamental building block for private networking in Azure. VNets enable Azure resources to securely communicate with each other, on-premises networks, and the internet. Every Azure resource in this project must be deployed into a VNet with no public endpoint exposure.

## Overview

- **Category**: Networking
- **Key capability**: Isolated private network for Azure resources with subnets, NSGs, and peering
- **When to use**: Any deployment requiring private networking, subnet segmentation, or cross-region connectivity

## Key Concepts

### Address Space

Each VNet defines a private IP address range using CIDR notation (RFC 1918). Example: `10.0.0.0/16` provides 65,536 addresses. Plan address spaces to avoid overlaps when peering VNets across regions.

### Subnets

Subnets segment a VNet's address space into smaller ranges. Azure reserves the first four and last IP in each subnet. Dedicated subnets are needed for specific services (e.g., `GatewaySubnet` for VPN gateways, delegated subnets for PaaS services).

### Network Security Groups (NSGs)

NSGs contain security rules that filter inbound and outbound traffic. Rules are evaluated by priority (lower number = higher priority). Each rule specifies source, destination, port, and protocol. NSGs can be attached to subnets or individual NICs.

### VNet Peering

Connects two VNets so resources communicate over Azure's backbone network. Peering works across regions (global VNet peering). Traffic between peered VNets is private and does not traverse the public internet.

### Service Endpoints and Private Endpoints

Service endpoints extend VNet identity to Azure services. Private endpoints assign a private IP from your VNet to a service instance, eliminating public network exposure entirely.

## Provisioning with Terraform AzAPI

See [getting-started/main.tf](sample_codes/getting-started/main.tf) for a complete VNet with subnets and NSG.

### AzAPI Resource Types

| Resource Type | API Version | Purpose |
|---|---|---|
| `Microsoft.Network/virtualNetworks` | `2024-05-01` | Virtual Network |
| `Microsoft.Network/virtualNetworks/subnets` | `2024-05-01` | Subnet (child resource) |
| `Microsoft.Network/networkSecurityGroups` | `2024-05-01` | Network Security Group |
| `Microsoft.Network/virtualNetworks/virtualNetworkPeerings` | `2024-05-01` | VNet Peering |
| `Microsoft.Network/privateEndpoints` | `2024-05-01` | Private Endpoint |

## Common Patterns

### Multi-Region VNet with Peering

Deploy VNets in each region and establish bidirectional peering. See [common-patterns/vnet-peering.tf](sample_codes/common-patterns/vnet-peering.tf).

### Subnet Segmentation

Separate subnets for different tiers: compute, data, management, and gateway. See [common-patterns/subnet-layout.tf](sample_codes/common-patterns/subnet-layout.tf).

## Best Practices

- **Do**: Plan address spaces upfront to avoid overlaps across peered VNets
- **Do**: Use NSGs on every subnet with deny-all default and explicit allow rules
- **Do**: Disable public network access on all PaaS resources; use Private Endpoints
- **Do**: Use separate subnets for different workload tiers
- **Avoid**: Overlapping CIDR ranges between VNets that will be peered
- **Avoid**: Overly broad NSG rules (e.g., allow all from any source)

## Troubleshooting

| Issue | Solution |
|---|---|
| Cannot reach VM in peered VNet | Verify peering status is `Connected` on both sides; check NSG rules |
| Subnet address exhaustion | Review allocated IPs; resize subnet or create additional subnets |
| Private endpoint DNS not resolving | Confirm Private DNS Zone is linked to the VNet |

For more issues: `microsoft_docs_search(query="azure virtual network troubleshoot {symptom}")`

## Learn More

| Topic | How to Find |
|---|---|
| VNet concepts | `microsoft_docs_fetch(url="https://learn.microsoft.com/azure/virtual-network/concepts-and-best-practices")` |
| NSG rules | `microsoft_docs_search(query="azure network security groups overview rules")` |
| VNet peering | `microsoft_docs_search(query="azure virtual network peering overview")` |
| Private endpoints | `microsoft_docs_search(query="azure private endpoint overview")` |
| ARM template reference | `microsoft_docs_fetch(url="https://learn.microsoft.com/azure/templates/microsoft.network/2024-05-01/virtualnetworks")` |

## CLI Alternative

If the Learn MCP server is not available, use the `mslearn` CLI instead:

| MCP Tool | CLI Command |
|---|---|
| `microsoft_docs_search(query: "...")` | `mslearn search "..."` |
| `microsoft_code_sample_search(query: "...", language: "...")` | `mslearn code-search "..." --language ...` |
| `microsoft_docs_fetch(url: "...")` | `mslearn fetch "..."` |

Run directly with `npx @microsoft/learn-cli <command>` or install globally with `npm install -g @microsoft/learn-cli`.
