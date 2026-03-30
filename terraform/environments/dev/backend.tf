// =====================================================
// Terraform Remote State Backend
// =====================================================
//
// This configuration uses partial backend configuration.
// Provide backend values at init time:
//
//   terraform init -backend-config=backend.tfvars.example
//
// Or copy backend.tfvars.example to backend.tfvars, fill in values, and run:
//   terraform init -backend-config=backend.tfvars
//
// Add backend.tfvars to .gitignore to prevent committing secrets.

terraform {
  backend "azurerm" {}
}
