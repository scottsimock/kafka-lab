# Function App Wired into Dev Environment

**Author:** Drexl
**Date:** 2026-04-01
**Task:** SP7.001

## Decision

The Function App module (`terraform/modules/function-app/`) was defined in SP5 but never instantiated in the dev environment's `main.tf`. This has been fixed:

- Module call added as `klc-func-kafkalab-scus` with Premium EP1 plan
- Private endpoint `klc-pe-func-scus` routes traffic through `snet-private-endpoints`
- New DNS zone `privatelink.azurewebsites.net` resolves the Function App hostname privately
- Schema Registry URL configured as `http://sr-01.kafkalab.internal:8081` (uses internal DNS)
- All Kafka secrets injected via `@Microsoft.KeyVault()` references from `klc-kv-kafkalab-scus`

## Impact

- **Smiley (Frontend):** Function App is now deployable. Web app can be deployed via `webapp-deploy.yml` workflow after Terraform apply.
- **Sid (Testing):** Integration tests can now target the Function App private endpoint for API testing.
- **All agents:** Dev verification uses `verify-dev.yml` (PLAINTEXT, no SASL_SSL) not `verify-cluster.yml` (SASL_SSL).
