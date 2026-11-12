# Infrastructure options

This repository keeps Azure infrastructure in `infra/` with Bicep and Terraform implementations. The root `azure.yaml` and Bicep template are the canonical `azd` path and provision shared Foundry resources plus the standalone and ACA-hosted Container Apps. Terraform is an alternate infrastructure configuration.

## Layout

- `bicep/main.bicep` - root azd/Bicep deployment for the shared resources and Container Apps
- `bicep/parameters.json` - example parameter values for manual Bicep deployments
- `terraform/` - equivalent Terraform configuration using the `azurerm` provider

## Bicep / azd

The repository-root `azure.yaml` points azd at `infra/bicep` and describes all three deployment services. Run `azd up` from the repository root.

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

The Terraform configuration covers the ACA-hosted Container App path. Runtime authentication uses managed identity and `DefaultAzureCredential`-compatible environment settings; no API keys are included. LangGraph uses `MemorySaver`, so conversation state is process-local and not durable across restarts.
