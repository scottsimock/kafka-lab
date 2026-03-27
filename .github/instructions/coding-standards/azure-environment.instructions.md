---
applyTo: '**'
description: 'Azure environment context for the Kafka Lab project — regions, availability zones, and resource groups'
---

# Azure Environment

## Regions

| Region | Role | Purpose |
|---|---|---|
| `southcentralus` | Primary | Main production workloads |
| `mexicocentral` | Secondary | Secondary and HA workloads |
| `canadaeast` | DR | Disaster recovery |

## Availability Zones

| Region | Zone | Usage |
|---|---|---|
| `southcentralus` | Zone 1 | Main deployments |
| `southcentralus` | Zone 2 | High availability (HA) replicas |
| `mexicocentral` | Zone 1 | Default zone for secondary and HA workloads |
| `canadaeast` | Zone 1 | Default zone for DR workloads |

## Resource Groups

All resources must be deployed to the following resource group:

| Resource Group | Region |
|---|---|
| `klc-rg-kafkalab-scus` | `southcentralus` |

Do not create new resource groups or deploy resources to any other resource group without explicit instruction.

## Data at Rest

Every Azure resource must be encrypted with a **Customer Managed Key (CMEK)**. Provision one dedicated CMK per resource — do not share keys across resources.

If a service does not support CMEK, apply the following tag to that resource instead:

```hcl
tags = {
  "compliance.data-at-rest" = "No CMEK"
}
```

## Authentication

Every Azure resource must authenticate using a **User Assigned Managed Identity (UAMI)**. Provision one dedicated UAMI per workflow and grant it only the permissions required for that workflow (least privilege).

If a service does not support UAMI, use a **System Assigned Managed Identity** instead.

If a service supports neither, use the next available authentication method and apply the following tag to that resource:

```hcl
tags = {
  "compliance.authentication" = "No Managed Identity"
}
```

Never omit the tag when managed identity is not used. The tag serves as an explicit audit marker that the absence of managed identity is intentional and acknowledged.

## Data in Transit

All data in transit must be encrypted. The minimum accepted TLS version is **TLS 1.2**. Prefer TLS 1.3 where the service supports it.

Always configure the minimum TLS version explicitly on every resource — do not rely on service defaults:

```hcl
min_tls_version = "TLS1_2"
```

If a service does not support enforcing a minimum TLS version, apply the following tag:

```hcl
tags = {
  "compliance.data-in-transit" = "No TLS Enforcement"
}
```

Never omit the tag when TLS enforcement is unavailable. Plaintext or unencrypted transports are not permitted under any circumstance.
