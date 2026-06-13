# Infrastructure options

This repository keeps Microsoft Foundry project hosting infrastructure in `infra/` with parallel Bicep and Terraform implementations. Both options provision the same Microsoft Foundry project hosting resources only: a Log Analytics workspace, a Container Apps environment, a user-assigned managed identity, a Container App listening on port `8088`, and optional RBAC for Azure OpenAI and ACR pulls.

## Layout

- `bicep/main.bicep` - azd/Bicep deployment for Microsoft Foundry project hosting
- `bicep/parameters.json` - example parameter values for manual Bicep deployments
- `terraform/` - equivalent Terraform configuration using the `azurerm` provider

## Bicep / azd

The repo-root `azure.yaml` points azd at `infra/bicep`. The deployment-scoped `deployment/foundry/azd/azure.yaml` points to the same shared Bicep with a relative path.

Example manual deployment:

```bash
az deployment group create \
  --resource-group <resource-group> \
  --template-file infra/bicep/main.bicep \
  --parameters @infra/bicep/parameters.json
```

## Terraform

Terraform expects an existing resource group, just like the Bicep template. Provide values for:

- `subscription_id`
- `resource_group_name`
- `container_image`
- `foundry_project_endpoint`
- optionally `container_registry_name`, `container_registry_server`, and `openai_account_name`

The Container App is configured to use managed identity and `DefaultAzureCredential`-compatible environment settings only. No API keys are included, and the templates provision Microsoft Foundry project resources only.
