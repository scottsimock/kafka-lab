---
id: doc-10
title: Azure Security UAMI CMEK TLS Research
type: other
created_date: '2026-03-28 18:31'
---
# Azure Security UAMI CMEK TLS Research

Research findings for TASK-1.11 covering User Assigned Managed Identities (UAMI), Customer Managed Keys (CMEK) via Disk Encryption Sets, and TLS enforcement for the Kafka Lab multi-region Confluent Platform deployment.

## Summary

The Kafka Lab deploys Confluent Platform 7.x across three Azure regions (southcentralus, mexicocentral, canadaeast) with 3 Kafka brokers per cluster on Ubuntu 22.04 LTS VMs. Compliance mandates require: one UAMI per workflow for authentication, one CMK per resource for data-at-rest encryption via Azure Key Vault and Disk Encryption Sets, and TLS 1.2+ for all data in transit — including Kafka inter-broker, client-to-broker, and ZooKeeper communication. This document consolidates findings on Azure resource provisioning (UAMI, Key Vault, DES), RBAC role assignments, and Confluent TLS configuration into actionable Terraform HCL and `server.properties` references.

## Key Findings

### UAMI (User Assigned Managed Identities)

- Azure UAMIs exist independently of the resources they are assigned to; deleting a VM does not delete its UAMI
- A single UAMI can be assigned to multiple VMs simultaneously, simplifying RBAC management for homogeneous clusters
- UAMIs are provisioned via `Microsoft.ManagedIdentity/userAssignedIdentities` (API version `2024-11-30`)
- VMs reference UAMIs through the `identity.userAssignedIdentities` property on `Microsoft.Compute/virtualMachines`
- The project compliance policy requires **one UAMI per workflow** (not per VM, not per cluster); this aligns with Microsoft best practices for clusters with homogeneous access patterns
- Each UAMI gets a `principalId` and `clientId` that are used for RBAC role assignments

### CMEK (Customer Managed Keys)

- Azure managed disk encryption with CMK requires three resources: Key Vault, Key Vault Key, and Disk Encryption Set (DES)
- Key Vault **must** have `purge_protection_enabled = true` and `soft_delete_enabled = true` (soft delete is enabled by default on new vaults)
- Key Vault **must** have `enabled_for_disk_encryption = true`
- Only RSA keys of sizes **2048, 3072, or 4096** bits are supported for disk encryption
- HSM-backed keys require Key Vault **Premium** SKU; software-backed keys work with **Standard** SKU
- Key Vault, DES, and managed disks **must all reside in the same Azure region**
- The compliance policy requires **one Key Vault key per resource** — each VM's OS disk and data disk(s) each get a dedicated key
- DES binds a Key Vault key to a managed identity; all disks referencing that DES are encrypted with that key
- To achieve one key per resource: create one Key Vault key + one DES per disk, then reference the DES via `disk_encryption_set_id` on each managed disk

### TLS Enforcement

- Confluent Platform 7.x supports TLS 1.2 and TLS 1.3 via the JVM's JSSE implementation (Java 11+ required for TLS 1.3)
- Kafka brokers enforce TLS via `ssl.enabled.protocols=TLSv1.2,TLSv1.3` in `server.properties`
- Inter-broker communication uses `security.inter.broker.protocol=SSL` with `ssl.client.auth=required` for mutual TLS
- ZooKeeper mTLS uses the Netty client (`zookeeper.clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty`) with `zookeeper.ssl.client.enable=true`
- Endpoint identification (`ssl.endpoint.identification.algorithm=HTTPS`) prevents man-in-the-middle attacks
- Each broker and ZooKeeper node requires its own keystore (private key + cert) and a shared truststore (CA cert)
- Azure resource-level TLS is enforced via `min_tls_version = "TLS1_2"` on all PaaS resources (Key Vault, Storage, etc.)

### RBAC Role Assignments

- DES managed identities require the **Key Vault Crypto Service Encryption User** role (least-privilege for wrap/unwrap operations)
- The **Key Vault Crypto User** role is broader (includes encrypt/decrypt/sign/verify) and should only be used when applications need direct cryptographic operations
- VM UAMIs that need to read secrets (e.g., TLS keystore passwords) require the **Key Vault Secrets User** role
- Storage access (if needed) uses **Storage Blob Data Contributor** or **Storage Blob Data Reader** depending on write requirements

## Architecture / Design Decisions

### Decision 1: UAMI Strategy — One Per Workflow

**Decision:** Provision one UAMI per logical workflow, shared across all VMs in that workflow.

**Rationale:** The project compliance policy mandates "one UAMI per workflow." For the Kafka Lab, this maps to:

| UAMI Name | Assigned To | Purpose |
|---|---|---|
| `uami-kafka-broker-scus` | 3 Kafka broker VMs in southcentralus | Broker identity for Key Vault, storage, monitoring |
| `uami-kafka-broker-mxc` | 3 Kafka broker VMs in mexicocentral | Broker identity for Key Vault, storage, monitoring |
| `uami-kafka-broker-cae` | 3 Kafka broker VMs in canadaeast | Broker identity for Key Vault, storage, monitoring |
| `uami-zookeeper-scus` | ZooKeeper VMs in southcentralus | ZooKeeper identity |
| `uami-zookeeper-mxc` | ZooKeeper VMs in mexicocentral | ZooKeeper identity |
| `uami-zookeeper-cae` | ZooKeeper VMs in canadaeast | ZooKeeper identity |
| `uami-des-scus` | Disk Encryption Sets in southcentralus | Key Vault key wrap/unwrap for disk encryption |
| `uami-des-mxc` | Disk Encryption Sets in mexicocentral | Key Vault key wrap/unwrap for disk encryption |
| `uami-des-cae` | Disk Encryption Sets in canadaeast | Key Vault key wrap/unwrap for disk encryption |

**Total: 9 UAMIs** (3 regions × 3 workflow types). Separating broker, ZooKeeper, and DES identities enforces least-privilege boundaries while staying within the "one per workflow" mandate.

### Decision 2: CMEK — One Key Vault Key + One DES Per Disk

**Decision:** Provision one Key Vault key and one DES per managed disk (OS + data disks).

**Rationale:** Compliance requires "one CMK per resource." Each VM has at minimum an OS disk; Kafka brokers also have data disk(s) for log segments. Each disk gets its own dedicated Key Vault key and DES. This provides cryptographic isolation — compromising one key does not expose other disks.

**Resource count per region (3 brokers, 1 OS disk + 1 data disk each):**

| Resource | Count Per Region |
|---|---|
| Key Vault keys (broker disks) | 6 (3 VMs × 2 disks) |
| Disk Encryption Sets | 6 (one per key) |
| Key Vault (shared per region) | 1 |

A single Key Vault per region holds all keys for that region's resources. This keeps key management centralized while maintaining one-key-per-resource isolation.

### Decision 3: Key Vault Configuration

**Decision:** Use Premium SKU with RBAC authorization (not access policies).

**Rationale:**
- Premium SKU supports HSM-backed keys for higher security assurance
- Azure RBAC mode (`enable_rbac_authorization = true`) is the modern approach, replacing legacy access policies
- Purge protection with 90-day retention prevents accidental or malicious key deletion
- Key Vault must be in the same region as its DES and disks

### Decision 4: TLS — mTLS Everywhere with TLS 1.2 Minimum

**Decision:** Enable mutual TLS (mTLS) for all Confluent component communication with TLS 1.2 as the minimum protocol version.

**Rationale:**
- mTLS ensures both parties authenticate via certificates, preventing unauthorized broker or client connections
- TLS 1.2 minimum satisfies compliance; TLS 1.3 is preferred where supported (Java 11+)
- Each broker gets a unique certificate with SANs matching its FQDN
- A private CA issues all certificates; the CA cert is distributed via truststores

## Configuration Reference

### Terraform HCL — UAMI Provisioning (AzAPI)

```hcl
// =====================================================
// User Assigned Managed Identity — Kafka Brokers
// =====================================================

variable "regions" {
  description = "Map of region short names to Azure locations"
  type        = map(string)
  default = {
    scus = "southcentralus"
    mxc  = "mexicocentral"
    cae  = "canadaeast"
  }
}

variable "resource_group_id" {
  description = "Resource ID of klc-rg-kafkalab-scus"
  type        = string
}

resource "azapi_resource" "uami_kafka_broker" {
  for_each = var.regions

  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30"
  name      = "uami-kafka-broker-${each.key}"
  parent_id = var.resource_group_id
  location  = each.value

  body = {}
}

resource "azapi_resource" "uami_zookeeper" {
  for_each = var.regions

  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30"
  name      = "uami-zookeeper-${each.key}"
  parent_id = var.resource_group_id
  location  = each.value

  body = {}
}

resource "azapi_resource" "uami_des" {
  for_each = var.regions

  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30"
  name      = "uami-des-${each.key}"
  parent_id = var.resource_group_id
  location  = each.value

  body = {}
}
```

### Terraform HCL — Key Vault with RBAC (AzAPI)

```hcl
// =====================================================
// Key Vault — One Per Region, Premium SKU, RBAC Mode
// =====================================================

data "azurerm_client_config" "current" {}

resource "azapi_resource" "key_vault" {
  for_each = var.regions

  type      = "Microsoft.KeyVault/vaults@2023-07-01"
  name      = "kv-kafkalab-${each.key}"
  parent_id = var.resource_group_id
  location  = each.value

  body = {
    properties = {
      sku = {
        family = "A"
        name   = "premium"
      }
      tenantId                   = data.azurerm_client_config.current.tenant_id
      enabledForDiskEncryption   = true
      enableSoftDelete           = true
      softDeleteRetentionInDays  = 90
      enablePurgeProtection      = true
      enableRbacAuthorization    = true
      publicNetworkAccess        = "Disabled"
      networkAcls = {
        defaultAction = "Deny"
        bypass        = "AzureServices"
      }
    }
  }
}
```

### Terraform HCL — Key Vault Keys (One Per Disk)

```hcl
// =====================================================
// Key Vault Keys — One CMK Per Managed Disk
// =====================================================

variable "broker_disk_keys" {
  description = "Map of broker disk identifiers to their region"
  type        = map(string)
  default = {
    "broker-1-os-scus"   = "scus"
    "broker-1-data-scus" = "scus"
    "broker-2-os-scus"   = "scus"
    "broker-2-data-scus" = "scus"
    "broker-3-os-scus"   = "scus"
    "broker-3-data-scus" = "scus"
    // Repeat for mxc and cae regions
  }
}

resource "azapi_resource" "cmk" {
  for_each = var.broker_disk_keys

  type      = "Microsoft.KeyVault/vaults/keys@2023-07-01"
  name      = "cmk-${each.key}"
  parent_id = azapi_resource.key_vault[each.value].id

  body = {
    properties = {
      kty     = "RSA"
      keySize = 4096
      keyOps  = ["wrapKey", "unwrapKey"]
      attributes = {
        enabled = true
      }
    }
  }
}
```

### Terraform HCL — Disk Encryption Sets (One Per Disk)

```hcl
// =====================================================
// Disk Encryption Sets — One DES Per Managed Disk
// =====================================================

resource "azapi_resource" "des" {
  for_each = var.broker_disk_keys

  type      = "Microsoft.Compute/diskEncryptionSets@2023-10-02"
  name      = "des-${each.key}"
  parent_id = var.resource_group_id
  location  = var.regions[each.value]

  identity {
    type         = "UserAssigned"
    identity_ids = [azapi_resource.uami_des[each.value].id]
  }

  body = {
    properties = {
      activeKey = {
        keyUrl = azapi_resource.cmk[each.key].output.properties.keyUriWithVersion
        sourceVault = {
          id = azapi_resource.key_vault[each.value].id
        }
      }
      encryptionType = "EncryptionAtRestWithCustomerKey"
    }
  }
}
```

### Terraform HCL — RBAC Role Assignments

```hcl
// =====================================================
// RBAC — DES Identity Gets Key Vault Crypto Service Encryption User
// =====================================================

resource "azurerm_role_assignment" "des_kv_crypto" {
  for_each = var.regions

  scope                = azapi_resource.key_vault[each.key].id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azapi_resource.uami_des[each.key].output.properties.principalId
}

// =====================================================
// RBAC — Broker Identity Gets Key Vault Secrets User (for TLS keystore passwords)
// =====================================================

resource "azurerm_role_assignment" "broker_kv_secrets" {
  for_each = var.regions

  scope                = azapi_resource.key_vault[each.key].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azapi_resource.uami_kafka_broker[each.key].output.properties.principalId
}
```

### RBAC Role Assignment Summary Table

| UAMI | Azure RBAC Role | Scope | Purpose |
|---|---|---|---|
| `uami-des-{region}` | Key Vault Crypto Service Encryption User | Key Vault (per region) | Wrap/unwrap keys for disk encryption |
| `uami-kafka-broker-{region}` | Key Vault Secrets User | Key Vault (per region) | Read TLS keystore passwords from Key Vault secrets |
| `uami-kafka-broker-{region}` | Storage Blob Data Contributor | Storage Account (if used) | Read/write Kafka tiered storage data |
| `uami-zookeeper-{region}` | Key Vault Secrets User | Key Vault (per region) | Read ZooKeeper TLS keystore passwords |

### Terraform HCL — VM with UAMI and DES-Encrypted Disk

```hcl
// =====================================================
// Kafka Broker VM — UAMI Assignment + CMEK Disks
// =====================================================

resource "azapi_resource" "kafka_broker_vm" {
  // Example for one broker; use for_each for all brokers
  type      = "Microsoft.Compute/virtualMachines@2024-03-01"
  name      = "vm-kafka-broker-1-scus"
  parent_id = var.resource_group_id
  location  = "southcentralus"

  identity {
    type         = "UserAssigned"
    identity_ids = [azapi_resource.uami_kafka_broker["scus"].id]
  }

  body = {
    properties = {
      hardwareProfile = {
        vmSize = "Standard_D4s_v5"
      }
      storageProfile = {
        osDisk = {
          createOption = "FromImage"
          managedDisk = {
            storageAccountType    = "Premium_LRS"
            diskEncryptionSet = {
              id = azapi_resource.des["broker-1-os-scus"].id
            }
          }
        }
        dataDisks = [
          {
            lun            = 0
            createOption   = "Empty"
            diskSizeGB     = 1024
            managedDisk = {
              storageAccountType    = "Premium_LRS"
              diskEncryptionSet = {
                id = azapi_resource.des["broker-1-data-scus"].id
              }
            }
          }
        ]
      }
      osProfile = {
        computerName  = "kafka-broker-1"
        adminUsername  = "kafkaadmin"
        linuxConfiguration = {
          disablePasswordAuthentication = true
        }
      }
      // networkProfile omitted for brevity
    }
  }
}
```

### Confluent Kafka Broker — server.properties (TLS Configuration)

```properties
# =====================================================
# Kafka Broker SSL/TLS Configuration
# =====================================================

# Listener configuration — SSL only, no plaintext
listeners=SSL://:9093
advertised.listeners=SSL://broker-1.kafkalab.internal:9093

# Inter-broker communication protocol — mutual TLS
security.inter.broker.protocol=SSL

# Keystore — unique per broker (contains broker private key + cert)
ssl.keystore.type=JKS
ssl.keystore.location=/etc/kafka/ssl/kafka-broker-1.keystore.jks
ssl.keystore.password=${KEYSTORE_PASSWORD}
ssl.key.password=${KEY_PASSWORD}

# Truststore — shared across all brokers (contains CA cert)
ssl.truststore.type=JKS
ssl.truststore.location=/etc/kafka/ssl/kafka.truststore.jks
ssl.truststore.password=${TRUSTSTORE_PASSWORD}

# Mutual TLS — require client certificate authentication
ssl.client.auth=required

# Protocol versions — TLS 1.2 minimum, prefer TLS 1.3
ssl.enabled.protocols=TLSv1.2,TLSv1.3
ssl.protocol=TLSv1.3

# Cipher suites — strong ciphers only (TLS 1.2)
ssl.cipher.suites=TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256

# Endpoint identification — prevents MITM attacks
ssl.endpoint.identification.algorithm=HTTPS
```

### Confluent Kafka Broker — server.properties (ZooKeeper TLS)

```properties
# =====================================================
# ZooKeeper mTLS Configuration (on broker side)
# =====================================================

# Use Netty for TLS-capable ZooKeeper connections
zookeeper.clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty
zookeeper.ssl.client.enable=true

# ZooKeeper TLS keystore and truststore
zookeeper.ssl.keyStore.location=/etc/kafka/ssl/kafka-broker-1.keystore.jks
zookeeper.ssl.keyStore.password=${ZK_KEYSTORE_PASSWORD}
zookeeper.ssl.trustStore.location=/etc/kafka/ssl/kafka.truststore.jks
zookeeper.ssl.trustStore.password=${ZK_TRUSTSTORE_PASSWORD}

# Enable ZooKeeper ACLs with mTLS authentication
zookeeper.set.acl=true
```

### ZooKeeper Node — zookeeper.properties (TLS Configuration)

```properties
# =====================================================
# ZooKeeper Server SSL/TLS Configuration
# =====================================================

# Secure client port (TLS)
secureClientPort=2182
# Disable plaintext client port
clientPort=0

# Authentication provider for mTLS
authProvider.x509=org.apache.zookeeper.server.auth.X509AuthenticationProvider

# Server-side keystore and truststore
ssl.keyStore.location=/etc/kafka/ssl/zookeeper-1.keystore.jks
ssl.keyStore.password=${ZK_SERVER_KEYSTORE_PASSWORD}
ssl.trustStore.location=/etc/kafka/ssl/kafka.truststore.jks
ssl.trustStore.password=${ZK_SERVER_TRUSTSTORE_PASSWORD}

# Quorum TLS (ZooKeeper-to-ZooKeeper communication)
sslQuorum=true
ssl.quorum.keyStore.location=/etc/kafka/ssl/zookeeper-1.keystore.jks
ssl.quorum.keyStore.password=${ZK_QUORUM_KEYSTORE_PASSWORD}
ssl.quorum.trustStore.location=/etc/kafka/ssl/kafka.truststore.jks
ssl.quorum.trustStore.password=${ZK_QUORUM_TRUSTSTORE_PASSWORD}
```

### Azure Resource-Level TLS Enforcement (Key Vault Example)

```hcl
// Set minimum TLS version on Key Vault via AzAPI properties
body = {
  properties = {
    // ... other properties ...
    minimumTlsVersion = "TLS1_2"
  }
}
```

For resources that do not support TLS enforcement, apply the compliance tag:

```hcl
tags = {
  "compliance.data-in-transit" = "No TLS Enforcement"
}
```

## Risks and Open Questions

### Risks

1. **Key Vault key count scaling** — With one key per disk across 3 regions × 3 brokers × 2 disks = 18 keys minimum (brokers only), plus ZooKeeper disks, the total key count grows significantly. Key Vault supports up to 500 key versions per key and thousands of keys per vault, so this is within limits but requires automation for key rotation.

2. **DES resource count** — One DES per disk means 18+ DES resources for brokers alone. This adds Terraform state complexity and plan time. Consider whether a DES-per-VM (covering both OS and data disk with the same key) is acceptable as a pragmatic simplification — but this would deviate from the strict "one CMK per resource" policy.

3. **Certificate management** — Each broker and ZooKeeper node needs unique keystores with per-host certificates. Automating certificate issuance, distribution, and rotation (via Ansible or a private CA like HashiCorp Vault) is essential. Manual certificate management across 9+ brokers and 9+ ZooKeeper nodes is error-prone.

4. **Key rotation** — Azure supports automatic key rotation on Key Vault keys, but DES picks up new key versions only after explicit update. A rotation strategy (automated via Azure Policy or Terraform) must be planned.

5. **Regional Key Vault dependency** — Key Vault, DES, and disks must be co-located in the same region. A regional Key Vault outage would prevent new disk creation or VM re-provisioning in that region. Consider cross-region key backup procedures for DR.

### Open Questions

1. **ZooKeeper disk count** — How many disks per ZooKeeper node (OS only, or OS + data)? This affects total CMK/DES count.

2. **Tiered storage** — Will Confluent Tiered Storage be used? If so, the broker UAMI needs Storage Blob Data Contributor role, and the storage account needs its own CMEK configuration (separate from disk encryption).

3. **Certificate authority** — Will the project use a self-signed private CA, HashiCorp Vault PKI, or Azure Key Vault certificates for TLS cert issuance? This decision affects the certificate management automation approach.

4. **Key Vault network access** — With `publicNetworkAccess = "Disabled"`, VMs must access Key Vault via Private Endpoint. The networking module must provision private endpoints and private DNS zones for `privatelink.vaultcore.azure.net` before Key Vault keys can be referenced.

5. **DES identity type** — This document uses UAMI for DES. Azure also supports SystemAssigned identity on DES. Using UAMI aligns with project policy but adds management overhead. Confirm this is the desired approach.

6. **Java version** — TLS 1.3 requires Java 11+. Confirm the JDK version bundled with Confluent Platform 7.x on Ubuntu 22.04 supports TLS 1.3.

## References

- [Azure Managed Identities Overview](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview)
- [Managed Identity Best Practice Recommendations](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/managed-identity-best-practice-recommendations)
- [Azure Disk Encryption Overview](https://learn.microsoft.com/en-us/azure/virtual-machines/disk-encryption-overview)
- [Enable CMK for Managed Disks (Portal)](https://learn.microsoft.com/en-us/azure/virtual-machines/disks-enable-customer-managed-keys-portal)
- [Azure Key Vault RBAC Guide](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide)
- [Azure Key Vault RBAC Migration (Role Mapping)](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-migration)
- [Terraform AzAPI — UAMI Resource](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/Microsoft.ManagedIdentity_userAssignedIdentities)
- [Terraform AzAPI — Key Vault Resource](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/Microsoft.KeyVault_vaults)
- [Terraform AzureRM — Disk Encryption Set](https://registry.terraform.io/providers/hashicorp/Azurerm/4.15.0/docs/resources/disk_encryption_set)
- [ARM Template Reference — UAMI](https://learn.microsoft.com/en-us/azure/templates/microsoft.managedidentity/2024-11-30/userassignedidentities)
- [ARM Template Reference — Key Vault](https://learn.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults)
- [Confluent Platform — Secure ZooKeeper](https://docs.confluent.io/platform/7.7/security/component/zk-security.html)
- [Confluent Platform — TLS Encryption](https://docs.confluent.io/platform/current/security/protect-data/encrypt-tls.html)
- [Confluent Platform — mTLS Authentication](https://docs.confluent.io/platform/current/security/authentication/mutual-tls/overview.html)
- [Confluent Platform — Security Tutorial (ZooKeeper-Based Cluster)](https://docs.confluent.io/platform/7.7/security/security_tutorial.html)
- [Azure Key Vault BYOK Specification](https://learn.microsoft.com/en-us/azure/key-vault/keys/byok-specification)
