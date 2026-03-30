// =====================================================
// Outputs
// =====================================================

output "dns_zone_id" {
  description = "Resource ID of the private DNS zone"
  value       = azapi_resource.main.id
}

output "dns_zone_name" {
  description = "Name of the private DNS zone"
  value       = azapi_resource.main.name
}
