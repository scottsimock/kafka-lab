---
name: azure-function-apps
description: Provision Azure Function Apps with Terraform AzAPI and develop serverless functions in Python. Use when agents need to create, configure, or deploy Function Apps with triggers, bindings, and VNet integration.
---

# Azure Function Apps

Azure Functions is a serverless compute service for running event-driven code without managing infrastructure. Function Apps host one or more functions triggered by HTTP requests, timers, queues, or other Azure services. The Python v2 programming model uses decorators to define triggers and bindings directly in code.

## Overview

- **Category**: Compute / Serverless
- **Key capability**: Event-driven code execution with automatic scaling and pay-per-use pricing
- **When to use**: HTTP APIs, scheduled tasks, event processing, webhook handlers, or lightweight backend services

## Key Concepts

### Function App

A Function App is the hosting container for individual functions. It runs on an App Service Plan (Consumption, Premium, or Flex Consumption) and shares configuration, scaling, and deployment settings across all its functions.

### Triggers and Bindings

Triggers define how a function is invoked (HTTP, Timer, Blob, Queue, Event Hub, etc.). Bindings declaratively connect functions to input/output data sources without explicit SDK calls.

### Python v2 Programming Model

The recommended model uses a decorator-based approach. All functions are defined in `function_app.py` using `@app.route()`, `@app.timer_trigger()`, and similar decorators.

### Flex Consumption Plan

The latest hosting plan providing serverless scaling with VNet integration, per-function scaling, and concurrency controls. Recommended for new deployments.

### VNet Integration

Function Apps can be integrated with a VNet to access private resources (VMs, databases, Kafka brokers) and restrict outbound traffic to the VNet.

## Provisioning with Terraform AzAPI

See [getting-started/main.tf](sample_codes/getting-started/main.tf) for provisioning a Function App with Flex Consumption plan.

### AzAPI Resource Types

| Resource Type | API Version | Purpose |
|---|---|---|
| `Microsoft.Web/serverfarms` | `2024-04-01` | App Service Plan |
| `Microsoft.Web/sites` | `2024-04-01` | Function App |
| `Microsoft.Storage/storageAccounts` | `2023-05-01` | Storage for function code and state |
| `Microsoft.Insights/components` | `2020-02-02` | Application Insights |

## Python Function Development

### Project Structure

```text
function-app/
├── function_app.py        # Function definitions with decorators
├── requirements.txt       # Python dependencies
├── host.json              # Function App host configuration
└── local.settings.json    # Local development settings (gitignored)
```

### Quick Start

See [getting-started/function_app.py](sample_codes/getting-started/function_app.py) for a basic HTTP-triggered function.

### Common Patterns

- **HTTP API**: [common-patterns/http_api.py](sample_codes/common-patterns/http_api.py)
- **Timer-triggered function**: [common-patterns/timer_function.py](sample_codes/common-patterns/timer_function.py)

## Key Configurations

| Setting | Purpose | Default |
|---|---|---|
| `FUNCTIONS_WORKER_RUNTIME` | Language runtime | `python` |
| `AzureWebJobsStorage` | Storage connection for triggers/state | Required |
| `FUNCTIONS_EXTENSION_VERSION` | Functions runtime version | `~4` |
| `WEBSITE_VNET_ROUTE_ALL` | Route all outbound through VNet | `1` (recommended) |

## Best Practices

- **Do**: Use the Python v2 programming model with decorators
- **Do**: Enable VNet integration for accessing private resources
- **Do**: Use Application Insights for monitoring and diagnostics
- **Do**: Store secrets in Key Vault and reference via App Settings
- **Avoid**: Long-running synchronous operations (use Durable Functions instead)
- **Avoid**: Storing state in the function instance (functions are stateless)

## Troubleshooting

| Issue | Solution |
|---|---|
| Function not triggering | Check trigger configuration and connection strings |
| Cold start latency | Use Premium or Flex Consumption plan with always-ready instances |
| Cannot reach private resources | Verify VNet integration is enabled and subnet is correct |

For more issues: `microsoft_docs_search(query="azure functions troubleshoot python {symptom}")`

## Learn More

| Topic | How to Find |
|---|---|
| Python developer guide | `microsoft_docs_fetch(url="https://learn.microsoft.com/azure/azure-functions/functions-reference-python")` |
| Triggers and bindings | `microsoft_docs_search(query="azure functions triggers bindings overview")` |
| VNet integration | `microsoft_docs_search(query="azure functions virtual network integration")` |
| Durable Functions | `microsoft_docs_search(query="azure durable functions python overview")` |
| Flex Consumption | `microsoft_docs_search(query="azure functions flex consumption plan")` |

## CLI Alternative

If the Learn MCP server is not available, use the `mslearn` CLI instead:

| MCP Tool | CLI Command |
|---|---|
| `microsoft_docs_search(query: "...")` | `mslearn search "..."` |
| `microsoft_code_sample_search(query: "...", language: "...")` | `mslearn code-search "..." --language ...` |
| `microsoft_docs_fetch(url: "...")` | `mslearn fetch "..."` |

Run directly with `npx @microsoft/learn-cli <command>` or install globally with `npm install -g @microsoft/learn-cli`.
