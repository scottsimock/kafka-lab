---
name: azure-private-dns
description: Provision and manage Azure Private DNS Zones with Terraform AzAPI. Use when agents need to create private DNS zones, link them to VNets, manage DNS records, or configure private endpoint DNS resolution.
---

# Azure Private DNS

Azure Private DNS provides reliable, secure DNS resolution within virtual networks using custom domain names. Private DNS zones are only resolvable from linked VNets, ensuring DNS queries and records remain private. Every Azure PaaS service accessed via Private Endpoint requires a corresponding Private DNS Zone.

## Overview

- **Category**: Networking / DNS
- **Key capability**: Private name resolution for Azure resources without custom DNS servers
- **When to use**: Any deployment using Private Endpoints, custom internal domain names, or multi-VNet DNS resolution

## Key Concepts

### Private DNS Zones

A private DNS zone hosts DNS records that are resolvable only from linked VNets. Zone names must have two or more labels (e.g., `contoso.com`, not `contoso`). A single zone can be linked to up to 1,000 VNets.

### Virtual Network Links

A link associates a Private DNS Zone with a VNet, enabling resources in that VNet to resolve records in the zone. Each link can optionally enable auto-registration.

### Auto-Registration

When enabled on a VNet link, Azure automatically creates and removes A records for VMs deployed in the linked VNet. Only one private DNS zone can have auto-registration enabled per VNet.

### Private Endpoint DNS

Azure PaaS services (Key Vault, Storage, Event Hubs, etc.) each have canonical private DNS zone names. When a Private Endpoint is created, an A record must be added to the corresponding zone pointing to the endpoint's private IP.

### Canonical Zone Names

| Service | Private DNS Zone |
|---|---|
| Blob Storage | `privatelink.blob.core.windows.net` |
| Key Vault | `privatelink.vaultcore.azure.net` |
| Event Hubs | `privatelink.servicebus.windows.net` |
| Azure Functions | `privatelink.azurewebsites.net` |
| SQL Database | `privatelink.database.windows.net` |

## Provisioning with Terraform AzAPI

See [getting-started/main.tf](sample_codes/getting-started/main.tf) for a Private DNS Zone with VNet link and A record.

### AzAPI Resource Types

| Resource Type | API Version | Purpose |
|---|---|---|
| `Microsoft.Network/privateDnsZones` | `2024-06-01` | Private DNS Zone |
| `Microsoft.Network/privateDnsZones/virtualNetworkLinks` | `2024-06-01` | VNet link |
| `Microsoft.Network/privateDnsZones/A` | `2024-06-01` | A record |
| `Microsoft.Network/privateDnsZones/CNAME` | `2024-06-01` | CNAME record |
| `Microsoft.Network/privateEndpoints` | `2024-05-01` | Private Endpoint |
| `Microsoft.Network/privateEndpoints/privateDnsZoneGroups` | `2024-05-01` | Auto DNS registration for endpoints |

## Common Patterns

### Private Endpoint with DNS Zone Group

Automatically register DNS records when creating Private Endpoints. See [common-patterns/private-endpoint-dns.tf](sample_codes/common-patterns/private-endpoint-dns.tf).

### Multi-VNet DNS Resolution

Link a single Private DNS Zone to multiple VNets across regions. See [common-patterns/multi-vnet-link.tf](sample_codes/common-patterns/multi-vnet-link.tf).

## Limits

| Resource | Limit |
|---|---|
| Private DNS zones per subscription | 1,000 |
| Record sets per zone | 25,000 |
| Records per record set | 20 |
| VNet links per zone | 1,000 |
| Auto-registration links per zone | 100 |
| Auto-registration zones per VNet | 1 |

## Best Practices

- **Do**: Create one Private DNS Zone per Azure service type using the canonical zone name
- **Do**: Link zones to all VNets that need to resolve the records
- **Do**: Use `privateDnsZoneGroups` on Private Endpoints for automatic A record management
- **Do**: Use `global` as the location for Private DNS Zones (they are not region-scoped)
- **Avoid**: Single-label zone names (not supported)
- **Avoid**: Manual A record management when `privateDnsZoneGroups` can automate it

## Troubleshooting

| Issue | Solution |
|---|---|
| DNS name not resolving | Verify VNet link exists and is in `Completed` state |
| Private endpoint IP not resolving | Check A record exists in the Private DNS Zone; verify zone is linked to the querying VNet |
| Custom DNS server bypasses private zones | Configure conditional forwarder to `168.63.129.16` for the zone |

For more issues: `microsoft_docs_search(query="azure private dns troubleshoot {symptom}")`

## Learn More

| Topic | How to Find |
|---|---|
| Private DNS overview | `microsoft_docs_fetch(url="https://learn.microsoft.com/azure/dns/private-dns-privatednszone")` |
| Private endpoint DNS config | `microsoft_docs_search(query="azure private endpoint dns configuration")` |
| DNS zone records | `microsoft_docs_fetch(url="https://learn.microsoft.com/azure/dns/dns-private-records")` |
| ARM template reference | `microsoft_docs_fetch(url="https://learn.microsoft.com/azure/templates/microsoft.network/2024-06-01/privatednszones")` |

## CLI Alternative

If the Learn MCP server is not available, use the `mslearn` CLI instead:

| MCP Tool | CLI Command |
|---|---|
| `microsoft_docs_search(query: "...")` | `mslearn search "..."` |
| `microsoft_code_sample_search(query: "...", language: "...")` | `mslearn code-search "..." --language ...` |
| `microsoft_docs_fetch(url: "...")` | `mslearn fetch "..."` |

Run directly with `npx @microsoft/learn-cli <command>` or install globally with `npm install -g @microsoft/learn-cli`.
