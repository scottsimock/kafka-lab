// =====================================================
// Computed Local Values
// =====================================================

locals {
  common_tags = {
    environment = var.environment
    project     = "kafka-lab"
    managed_by  = "terraform"
  }
}
