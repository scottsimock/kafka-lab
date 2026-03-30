---
id: TASK-28.1
title: SP1.001 — Terraform Project Structure and Provider Configuration
status: Done
assignee:
  - coder-1
created_date: '2026-03-30 16:37'
updated_date: '2026-03-30 19:21'
labels:
  - story
milestone: m-1
dependencies: []
references:
  - terraform/
  - terraform/versions.tf
  - terraform/variables.tf
  - terraform/environments/dev/
  - terraform/modules/
documentation:
  - doc-14
parent_task_id: TASK-28
priority: high
ordinal: 1001
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the Terraform project directory structure with modules layout and environment directories. Configure the AzAPI provider in versions.tf with required_version >= 1.6.0, azapi >= 2.0, and random >= 3.6. Create main.tf, variables.tf, outputs.tf, and locals.tf at the root module level under terraform/environments/dev/. Define core variables: subscription_id, environment (default "dev"), primary_location (default "southcentralus"), resource_group_name (default "klc-rg-kafkalab-scus"). The modules/ directory should be empty initially — each subsequent task creates its own module. Use // comment style (not #) per codebase conventions.

Directory structure to create:
```
terraform/
├── modules/               # Reusable child modules (populated by later tasks)
├── environments/
│   └── dev/
│       ├── main.tf         # Module calls and provider configuration
│       ├── variables.tf    # Root input variables
│       ├── outputs.tf      # Root outputs
│       ├── locals.tf       # Computed local values
│       └── versions.tf     # Provider version constraints
└── README.md               # Module documentation
```

The root module at terraform/environments/dev/ is where terraform init/plan/apply runs. Provider configuration block must include azapi provider features block. Use data "azapi_resource" to reference the existing resource group rather than creating one.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 terraform/modules/ directory exists
- [x] #2 terraform/environments/dev/ directory exists with main.tf, variables.tf, outputs.tf, locals.tf, versions.tf
- [x] #3 versions.tf declares terraform required_version >= 1.6.0
- [x] #4 versions.tf declares azapi provider (source azure/azapi) >= 2.0
- [x] #5 versions.tf declares random provider (source hashicorp/random) >= 3.6
- [x] #6 variables.tf defines subscription_id (string, no default), environment (string, default "dev"), primary_location (string, default "southcentralus"), resource_group_name (string, default "klc-rg-kafkalab-scus")
- [x] #7 main.tf configures the azapi provider block
- [x] #8 main.tf uses data azapi_resource to reference the existing resource group klc-rg-kafkalab-scus
- [x] #9 All .tf files use // comment style (not #)
- [x] #10 terraform init succeeds in terraform/environments/dev/
- [x] #11 terraform validate passes with no errors in terraform/environments/dev/
- [x] #12 terraform fmt -check passes on all .tf files
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T19:00:00Z
- Assigned TASK-28.1 to coder-1 (Wave 1)
- Single task in Wave 1, no dependencies

## [TL] 2026-03-30T19:30:00Z
- Evaluated existing coder work against all 12 AC items
- terraform fmt -check: PASS
- terraform init (backend=false): PASS
- terraform validate: PASS
- All // comment style verified
- Fixed: added terraform .gitignore entries and removed .terraform/ provider binaries from tracking
- Committed as feat(SP1.001): terraform project structure and provider configuration
- Sending to tester

## [Tester] 2026-03-30T20:00:00Z

### Review Summary

Reviewed all 12 acceptance criteria, ran terraform fmt -check and terraform validate, and inspected code quality.

### Acceptance Criteria Verification

- AC#1 ✅ terraform/modules/ directory exists (tracked via .gitkeep)
- AC#2 ✅ terraform/environments/dev/ contains main.tf, variables.tf, outputs.tf, locals.tf, versions.tf
- AC#3 ✅ versions.tf: required_version >= "1.6.0"
- AC#4 ✅ versions.tf: azapi source "azure/azapi" version >= 2.0
- AC#5 ✅ versions.tf: random source "hashicorp/random" version >= 3.6
- AC#6 ✅ variables.tf: subscription_id (no default), environment (default "dev"), primary_location (default "southcentralus"), resource_group_name (default "klc-rg-kafkalab-scus")
- AC#7 ✅ main.tf: provider "azapi" {} block present
- AC#8 ✅ main.tf: data "azapi_resource" "resource_group" with type "Microsoft.Resources/resourceGroups@2023-07-01" and correct parent_id
- AC#9 ✅ All .tf files use // comment style — no # comments found
- AC#10 ✅ terraform init succeeded — .terraform.lock.hcl committed, .terraform/ binaries excluded via .gitignore
- AC#11 ✅ terraform validate: Success! The configuration is valid.
- AC#12 ✅ terraform fmt -check: PASS (exit code 0)

### Rubric Scores

- **Acceptance Criteria: 30/30** — All 12 AC items fully met
- **Tests: 25/25** — terraform fmt -check PASS + terraform validate PASS
- **Code Quality: 20/20** — // comments throughout, snake_case naming, section header separators, all variables/outputs have descriptions, clean minimal structure
- **Documentation: 15/15** — terraform/README.md with full structure diagram, providers table, prerequisites, usage instructions, environments table; all variables and outputs documented
- **Dependencies: 10/10** — .gitignore updated with terraform entries, .terraform.lock.hcl committed correctly, .terraform/ binaries not tracked, no broken imports

**Total: 100/100 (100%)**

### Result: PASS ✅
<!-- SECTION:NOTES:END -->
