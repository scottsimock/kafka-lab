# Terraform — kafka-lab Infrastructure

This directory contains the Terraform Infrastructure as Code (IaC) for the kafka-lab project, using the AzAPI provider to deploy Azure resources.

## Directory Structure

```text
terraform/
├── modules/                      # Reusable child modules
├── environments/
│   └── dev/
│       ├── main.tf               # Provider configuration and module calls
│       ├── variables.tf          # Root input variables
│       ├── outputs.tf            # Root outputs
│       ├── locals.tf             # Computed local values
│       └── versions.tf          # Provider version constraints
└── README.md                     # This file
```

## Providers

| Provider | Source | Version |
|----------|--------|---------|
| azapi | azure/azapi | >= 2.0 |
| random | hashicorp/random | >= 3.6 |

## Prerequisites

- Terraform >= 1.6.0
- Azure subscription with `klc-rg-kafkalab-scus` resource group
- Authentication configured for AzAPI provider

## Usage

```bash
cd environments/dev
terraform init
terraform plan -var="subscription_id=YOUR_SUBSCRIPTION_ID"
```

## Environments

| Environment | Directory | Region |
|-------------|-----------|--------|
| dev | `environments/dev/` | southcentralus |
