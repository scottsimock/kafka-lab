// =====================================================
// Storage Account (required for Function App runtime)
// =====================================================

resource "random_string" "storage_suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  storage_name = var.storage_account_name != null ? var.storage_account_name : "stfunc${random_string.storage_suffix.result}"
}

resource "azapi_resource" "storage" {
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  name      = local.storage_name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  body = {
    sku = {
      name = "Standard_LRS"
    }
    kind = "StorageV2"
    properties = {
      minimumTlsVersion        = "TLS1_2"
      supportsHttpsTrafficOnly = true
      publicNetworkAccess      = "Disabled"
    }
  }
}

// =====================================================
// App Service Plan (Premium EP1 for VNet integration)
// =====================================================

resource "azapi_resource" "app_service_plan" {
  type      = "Microsoft.Web/serverfarms@2023-12-01"
  name      = "${var.name}-plan"
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  body = {
    sku = {
      name = "EP1"
      tier = "ElasticPremium"
    }
    kind = "elastic"
    properties = {
      reserved = true
    }
  }
}

// =====================================================
// UAMI Role Assignment — Key Vault Secrets User
// =====================================================

resource "random_uuid" "kv_secrets_user" {}

resource "azapi_resource" "kv_role_assignment" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.kv_secrets_user.result
  parent_id = var.key_vault_id

  body = {
    properties = {
      roleDefinitionId = "/subscriptions/${split("/", var.resource_group_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6"
      principalId      = var.user_assigned_identity_principal_id
      principalType    = "ServicePrincipal"
    }
  }
}

// =====================================================
// Function App
// =====================================================

resource "azapi_resource" "function_app" {
  type      = "Microsoft.Web/sites@2023-12-01"
  name      = var.name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.user_assigned_identity_id]
  }

  body = {
    kind = "functionapp,linux"
    properties = {
      serverFarmId           = azapi_resource.app_service_plan.id
      httpsOnly              = true
      publicNetworkAccess    = "Disabled"
      virtualNetworkSubnetId = var.web_app_subnet_id
      siteConfig = {
        linuxFxVersion = "Node|20"
        minTlsVersion  = "1.2"
        ftpsState      = "Disabled"
        cors = {
          allowedOrigins = []
        }
        appSettings = [
          {
            name  = "FUNCTIONS_WORKER_RUNTIME"
            value = "Custom"
          },
          {
            name  = "FUNCTIONS_EXTENSION_VERSION"
            value = "~4"
          },
          {
            name  = "AzureWebJobsStorage"
            value = "DefaultEndpointsProtocol=https;AccountName=${azapi_resource.storage.name};AccountKey=${azapi_resource.storage.output.properties.primaryEndpoints.blob}"
          },
          {
            name  = "WEBSITE_VNET_ROUTE_ALL"
            value = "1"
          },
          {
            name  = "WEBSITE_CONTENTOVERVNET"
            value = "1"
          },
          {
            name  = "KAFKA_BOOTSTRAP_SERVERS"
            value = "@Microsoft.KeyVault(VaultName=${var.key_vault_name};SecretName=kafka-bootstrap-servers)"
          },
          {
            name  = "KAFKA_USERNAME"
            value = "@Microsoft.KeyVault(VaultName=${var.key_vault_name};SecretName=kafka-username)"
          },
          {
            name  = "KAFKA_PASSWORD"
            value = "@Microsoft.KeyVault(VaultName=${var.key_vault_name};SecretName=kafka-password)"
          },
          {
            name  = "KAFKA_SSL_CA"
            value = "@Microsoft.KeyVault(VaultName=${var.key_vault_name};SecretName=kafka-ssl-ca)"
          },
          {
            name  = "WEBSITE_RUN_FROM_PACKAGE"
            value = "1"
          }
        ]
      }
    }
  }

  depends_on = [azapi_resource.kv_role_assignment]
}
