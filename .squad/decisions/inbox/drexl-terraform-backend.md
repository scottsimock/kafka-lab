# Decision: Terraform Backend Storage in klc-rg-kafkalab-scus

**Author:** Drexl  
**Date:** 2026-04-01  
**Status:** Implemented

## Context

All Terraform `init` calls across scripts and workflows only passed the state `key` but omitted storage account, container, and resource group. The `backend.tfvars.example` referenced a separate `klc-rg-tfstate-scus` resource group that either doesn't exist or is inaccessible to our service principal.

## Decision

Created the tfstate storage account `klcstgtfstatescus` inside `klc-rg-kafkalab-scus` (the only RG we have permissions on). All scripts and workflows now pass full inline backend-config flags instead of relying on a `backend.tfvars` file.

Key properties:
- **Storage account:** `klcstgtfstatescus` in `klc-rg-kafkalab-scus`
- **Container:** `tfstate`
- **Auth:** Azure AD only (`use_azuread_auth=true`). Shared key access is blocked by Azure Policy.
- **State keys:** `kafka-lab/dev-shared.tfstate`, `kafka-lab/dev.tfstate`

## Impact

- All terraform init calls now work without a local `backend.tfvars` file
- CI/CD workflows use `TF_BACKEND_*` env vars at the workflow level
- Local scripts use `BACKEND_*` env vars with sensible defaults (overridable)
- `scripts/bootstrap-tfstate.sh` bootstraps the storage account for new environments
- The OIDC service principal needs `Storage Blob Data Contributor` on the storage account

## Files Changed

- `scripts/bootstrap-tfstate.sh` (new)
- `scripts/deploy-dev-shared.sh`, `scripts/deploy-dev.sh`, `scripts/teardown-dev.sh`
- `.github/workflows/dev-shared-deploy.yml`, `dev-recreate.yml`, `dev-teardown.yml`
- `.github/workflows/terraform-deploy.yml`, `drift-detection.yml`, `pr-validation.yml`
- `terraform/environments/dev-shared/backend.tfvars.example`, `terraform/environments/dev/backend.tfvars.example`
