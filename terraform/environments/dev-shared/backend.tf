// =====================================================
// Terraform Remote State Backend
// =====================================================
//
// Separate state file for long-lived shared resources (Key Vault, UAMI)
// that must survive dev-teardown and dev-recreate cycles.
//
// Provide backend values at init time:
//
//   terraform init -backend-config=backend.tfvars
//
// Or pass the key directly in CI:
//   terraform init -backend-config="key=kafka-lab/dev-shared.tfstate"

terraform {
  backend "azurerm" {}
}
