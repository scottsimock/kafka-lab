// =====================================================
// User Assigned Managed Identity
// =====================================================

resource "azapi_resource" "main" {
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  name      = var.name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  response_export_values = ["properties.principalId", "properties.clientId"]

  body = {}
}
