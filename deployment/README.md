# Deployment

This repository supports two Azure deployment paths for the same claims agent.

## Prerequisites

- Azure CLI (`az`) logged in
- Docker for image builds and pushes
- An Azure Container Registry (ACR)
- Access to the target Azure subscription and resource group
- For the Foundry path, `azd` is optional but preferred

## Standalone Container App

The standalone host runs the FastAPI `/chat` surface from `deployment/standalone/Dockerfile` on port `8080`.

### Required runtime settings

```bash
export AZURE_OPENAI_ENDPOINT="https://<resource>.openai.azure.com"
export AZURE_OPENAI_DEPLOYMENT="gpt-4.1"
```

### Optional managed identity RBAC

If you want the script to grant the Container App identity access to Azure OpenAI automatically, also set:

```bash
export AZURE_OPENAI_RESOURCE_ID="/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<name>"
```

### Deploy command

```bash
deployment/standalone/deploy.sh <resource-group> <acr-name> <app-name> [image-tag]
```

What the script does:

1. builds the standalone Docker image from `deployment/standalone/Dockerfile`
2. tags it for your ACR
3. pushes it to ACR
4. creates or reuses a Container Apps environment
5. creates or updates the Container App
6. injects `AZURE_OPENAI_ENDPOINT` and `AZURE_OPENAI_DEPLOYMENT`
7. optionally assigns the `Cognitive Services OpenAI User` role to the app identity

## Foundry-hosted Container App

The Foundry host runs `python -m foundry_host.app` from `deployment/foundry/Dockerfile` on port `8088`.

### Required runtime settings

```bash
export FOUNDRY_PROJECT_ENDPOINT="https://<project>.services.ai.azure.com/api/projects/<project-name>"
export AZURE_AI_MODEL_DEPLOYMENT_NAME="gpt-4.1"
```

### Optional RBAC setting

The helper script can derive the Azure OpenAI account name from a resource ID and feed it to the Bicep template when the account is in the same resource group:

```bash
export OPENAI_RESOURCE_ID="/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<name>"
```

### Preferred deployment with `azd`

```bash
cd deployment/foundry/azd
azd init -t foundry-langgraph-hosted-agent-sample
azd env set FOUNDRY_PROJECT_ENDPOINT "$FOUNDRY_PROJECT_ENDPOINT"
azd env set AZURE_AI_MODEL_DEPLOYMENT_NAME "$AZURE_AI_MODEL_DEPLOYMENT_NAME"
azd provision
azd deploy
```

### One-command deployment helper

```bash
deployment/foundry/deploy.sh <resource-group> <acr-name> <container-app-name> [image-tag]
```

Behavior:

- if `azd` is installed, the script seeds the azd environment, runs `azd provision`, then runs `azd deploy`
- if `azd` is not installed, the script falls back to Azure CLI, builds and pushes the Foundry image, and deploys the Bicep template directly

## GitHub Actions automation

The repository now includes two GitHub Actions workflows for Azure delivery with **OIDC/federated credentials only** — no API keys or client secrets:

- `.github/workflows/deploy.yml` runs lint + tests on pushes to `main`, then provisions and deploys the Microsoft Foundry Container App with `azd provision` and `azd deploy` in the `production` environment.
- `.github/workflows/build-image.yml` builds and pushes the standalone and Microsoft Foundry Docker images to ACR when application or Docker assets change on `main`.

### Required GitHub environment secrets

Set these in the `production` environment:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `ACR_NAME` (for image publishing)

### Recommended GitHub environment variables

Use environment variables for non-secret deployment settings such as:

- `FOUNDRY_PROJECT_ENDPOINT`
- `AZURE_ENV_NAME`
- `AZURE_LOCATION`
- `AZURE_RESOURCE_GROUP`
- `CONTAINER_APP_NAME`
- `CONTAINER_APPS_ENVIRONMENT_NAME`
- `LOG_ANALYTICS_WORKSPACE_NAME`
- `MANAGED_IDENTITY_NAME`
- `AZURE_AI_MODEL_DEPLOYMENT_NAME`
- `OPENAI_ACCOUNT_NAME`
- `CONTAINER_REGISTRY_NAME`

At runtime, the deployed Container Apps continue to authenticate with `DefaultAzureCredential` and managed identity, so production stays passwordless end-to-end.

## Foundry infrastructure details

`infra/bicep/main.bicep` now provisions:

- Log Analytics workspace
- Container Apps environment
- user-assigned managed identity
- Container App with external ingress on port `8088`
- `Cognitive Services OpenAI User` role assignment when `OPENAI_ACCOUNT_NAME` is supplied
- `AcrPull` role assignment when `CONTAINER_REGISTRY_NAME` is supplied

The template outputs the Container App FQDN after deployment.
