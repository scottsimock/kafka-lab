// =====================================================
// Key Vault
// =====================================================

resource "azapi_resource" "main" {
  type      = "Microsoft.KeyVault/vaults@2023-07-01"
  name      = var.name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  response_export_values = ["properties.vaultUri"]

  body = {
    properties = {
      sku = {
        family = "A"
        name   = "standard"
      }
      tenantId                  = var.tenant_id
      enableRbacAuthorization   = true
      enablePurgeProtection     = true
      softDeleteRetentionInDays = 90
      publicNetworkAccess       = "Disabled"
    }
  }
}

// =====================================================
// UAMI Role Assignment — Key Vault Crypto Officer
// =====================================================

resource "random_uuid" "kv_crypto_officer" {}

resource "azapi_resource" "role_assignment" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.kv_crypto_officer.result
  parent_id = azapi_resource.main.id

  body = {
    properties = {
      roleDefinitionId = "/subscriptions/${split("/", var.resource_group_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/14b46e9e-c2b7-41b4-b07b-48a6ebf60603"
      principalId      = var.uami_principal_id
      principalType    = "ServicePrincipal"
    }
  }

  depends_on = [azapi_resource.main]
}

// =====================================================
// CMEK Encryption Key
// =====================================================

resource "azapi_resource" "cmk_key" {
  type      = "Microsoft.KeyVault/vaults/keys@2023-07-01"
  name      = "${var.name}-cmk"
  parent_id = azapi_resource.main.id

  response_export_values = ["properties.keyUriWithVersion", "properties.keyUri"]

  body = {
    properties = {
      kty     = "RSA"
      keySize = 2048
      keyOps  = ["wrapKey", "unwrapKey"]
    }
  }

  depends_on = [azapi_resource.role_assignment]
}
