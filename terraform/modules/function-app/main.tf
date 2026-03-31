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
// UAMI Role Assignments
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

resource "random_uuid" "storage_blob_owner" {}

resource "azapi_resource" "storage_blob_role" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.storage_blob_owner.result
  parent_id = azapi_resource.storage.id

  body = {
    properties = {
      roleDefinitionId = "/subscriptions/${split("/", var.resource_group_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/b7e6dc6d-f1e8-4753-8033-0f276bb0955b"
      principalId      = var.user_assigned_identity_principal_id
      principalType    = "ServicePrincipal"
    }
  }
}

resource "random_uuid" "storage_queue_contributor" {}

resource "azapi_resource" "storage_queue_role" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.storage_queue_contributor.result
  parent_id = azapi_resource.storage.id

  body = {
    properties = {
      roleDefinitionId = "/subscriptions/${split("/", var.resource_group_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/974c5e8b-45b9-4653-ba55-5f855dd0fb88"
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
            name  = "AzureWebJobsStorage__accountName"
            value = azapi_resource.storage.name
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
            name  = "SCHEMA_REGISTRY_URL"
            value = var.schema_registry_url
          },
          {
            name  = "WEBSITE_RUN_FROM_PACKAGE"
            value = "1"
          }
        ]
      }
    }
  }

  response_export_values = ["properties.defaultHostName"]

  depends_on = [
    azapi_resource.kv_role_assignment,
    azapi_resource.storage_blob_role,
    azapi_resource.storage_queue_role
  ]
}
