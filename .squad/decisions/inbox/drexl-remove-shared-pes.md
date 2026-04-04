# Decision: Remove Private Endpoints from dev-shared Layer

**Date:** 2026-04-05
**Author:** Drexl (Infrastructure Developer)
**Status:** Accepted

## Context

GitHub-hosted Actions runners operate on the public internet and cannot reach Azure resources behind private endpoints. This was blocking CI/CD workflows from accessing Key Vault and storage resources during deployments.

The user manually enabled public access on existing Azure resources in the Azure portal. The Terraform IaC needed to match so `terraform plan` would not attempt to re-create the deleted private endpoints and DNS zones.

## Decision

Remove all private endpoint and private DNS zone configuration from the `dev-shared` Terraform layer:

- Private DNS zones (`privatelink.vaultcore.azure.net`, `privatelink.blob.core.windows.net`)
- Key Vault private endpoint (`klc-pe-keyvault-scus`)
- Related outputs and downstream references in the `dev` layer

Also removed the storage blob PE from the `dev` layer since it depended on the shared blob DNS zone.

## Consequences

- All shared PaaS resources (Key Vault, storage) are now accessible over the public internet
- GitHub Actions workflows can reach these resources without VNet integration
- VNet, subnets, and the `snet-private-endpoints` subnet remain defined for future use
- The PE and private DNS zone modules remain available in `terraform/modules/` for re-use in other environments
- If private endpoints are needed again, self-hosted runners or VNet-integrated GitHub Actions runners will be required
