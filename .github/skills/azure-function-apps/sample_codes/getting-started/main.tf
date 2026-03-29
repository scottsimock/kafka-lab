// Azure Function App with Flex Consumption plan using AzAPI provider

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}

variable "resource_group_id" {
  description = "Resource ID of the target resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "southcentralus"
}

variable "function_app_name" {
  description = "Name of the function app"
  type        = string
}

variable "subnet_id" {
  description = "Resource ID of the subnet for VNet integration"
  type        = string
  default     = null
}

variable "user_assigned_identity_id" {
  description = "Resource ID of the User Assigned Managed Identity"
  type        = string
}

// =====================================================
// Storage Account (required for Function App)
// =====================================================

resource "random_string" "storage_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "azapi_resource" "storage" {
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  name      = "stfunc${random_string.storage_suffix.result}"
  parent_id = var.resource_group_id
  location  = var.location

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
// App Service Plan (Flex Consumption)
// =====================================================

resource "azapi_resource" "plan" {
  type      = "Microsoft.Web/serverfarms@2024-04-01"
  name      = "${var.function_app_name}-plan"
  parent_id = var.resource_group_id
  location  = var.location

  body = {
    sku = {
      tier = "FlexConsumption"
      name = "FC1"
    }
    kind = "functionapp"
    properties = {
      reserved = true
    }
  }
}

// =====================================================
// Function App
// =====================================================

resource "azapi_resource" "function_app" {
  type      = "Microsoft.Web/sites@2024-04-01"
  name      = var.function_app_name
  parent_id = var.resource_group_id
  location  = var.location

  identity {
    type         = "UserAssigned"
    identity_ids = [var.user_assigned_identity_id]
  }

  body = {
    kind = "functionapp,linux"
    properties = {
      serverFarmId = azapi_resource.plan.id
      httpsOnly    = true
      siteConfig = {
        pythonVersion     = "3.11"
        linuxFxVersion    = "Python|3.11"
        minTlsVersion     = "1.2"
        ftpsState         = "Disabled"
        appSettings = [
          {
            name  = "FUNCTIONS_WORKER_RUNTIME"
            value = "python"
          },
          {
            name  = "FUNCTIONS_EXTENSION_VERSION"
            value = "~4"
          },
          {
            name  = "AzureWebJobsStorage"
            value = "DefaultEndpointsProtocol=https;AccountName=${azapi_resource.storage.name}"
          },
          {
            name  = "WEBSITE_VNET_ROUTE_ALL"
            value = "1"
          }
        ]
      }
      virtualNetworkSubnetId = var.subnet_id
      publicNetworkAccess    = "Disabled"
    }
  }
}

output "function_app_id" {
  description = "Resource ID of the Function App"
  value       = azapi_resource.function_app.id
}

output "function_app_hostname" {
  description = "Default hostname of the Function App"
  value       = azapi_resource.function_app.output.properties.defaultHostName
}
