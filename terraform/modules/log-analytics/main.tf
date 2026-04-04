// =====================================================
// Log Analytics Workspace
// =====================================================

resource "azapi_resource" "main" {
  type      = "Microsoft.OperationalInsights/workspaces@2023-09-01"
  name      = var.name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  response_export_values = ["properties.customerId"]

  body = {
    properties = {
      sku = {
        name = var.sku
      }
      retentionInDays                 = var.retention_in_days
      publicNetworkAccessForIngestion = "Enabled"
      publicNetworkAccessForQuery     = "Enabled"
    }
  }
}
