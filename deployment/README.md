# Deployment

The repository-root `azure.yaml` is the canonical azd deployment configuration. It deploys the standalone and ACA-hosted Container Apps plus the Foundry hosted agent. The standalone script below is an optional manual path for deploying only the standalone Container App.

## Prerequisites

- Azure CLI (`az`) logged in
- Docker for image builds and pushes
- An Azure Container Registry (ACR)
- Access to the target Azure subscription and resource group
- Azure Developer CLI (`azd`) for the complete three-mode deployment

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

## Deploy all three modes with azd

From the repository root, authenticate and deploy using the root `azure.yaml` and `infra/bicep`:

```bash
azd auth login
azd env new <environment-name>
azd env set AZURE_LOCATION eastus2
azd env set AZURE_AI_MODEL_DEPLOYMENT_NAME gpt-4.1
azd up
```

`azd up` provisions shared resources and the two Container Apps from `infra/bicep/main.bicep`, then deploys all services declared in the root `azure.yaml`, including the Foundry hosted agent from `agent.yaml`. Configure Bicep parameter values with `azd env set` when the defaults are not appropriate.

## GitHub Actions automation

The repository now includes two GitHub Actions workflows for Azure delivery with **OIDC/federated credentials only** — no API keys or client secrets:

- `.github/workflows/deploy.yml` runs lint and tests on pushes to `main`, then provisions and deploys all three root `azure.yaml` services with azd from the repository root.
- `.github/workflows/build-image.yml` separately builds and pushes the standalone and ACA-hosted/Foundry-hosted images to ACR when application or Docker assets change on `main`.

### Required GitHub environment secrets

Set these in the `production` environment:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

The GitHub Actions identity needs permission to push to the provisioned ACR for image publishing.

### Recommended GitHub environment variables

Use environment variables for non-secret deployment settings such as:

- `AZURE_ENV_NAME`
- `AZURE_LOCATION`
- `AZURE_RESOURCE_GROUP`
- `STANDALONE_CONTAINER_APP_NAME`
- `ACA_HOSTED_CONTAINER_APP_NAME`
- `CONTAINER_APPS_ENVIRONMENT_NAME`
- `LOG_ANALYTICS_WORKSPACE_NAME`
- `MANAGED_IDENTITY_NAME`
- `AZURE_AI_MODEL_DEPLOYMENT_NAME`
- `AI_SERVICES_NAME`
- `FOUNDRY_PROJECT_NAME`
- `CONTAINER_REGISTRY_NAME`

The workflow uses OIDC for deployment. At runtime, the Container Apps and Foundry-hosted agent authenticate with their configured managed identities.

## Foundry infrastructure details

`infra/bicep/main.bicep` provisions:

- Log Analytics workspace
- Container Apps environment
- user-assigned managed identity
- Container App with external ingress on port `8088`
- AI Services account, model deployment, and Foundry project
- role assignments and project connections for the configured identities and registry
- standalone and ACA-hosted Container Apps

The template outputs the Container App FQDNs, Foundry project endpoint, and deployment settings after provisioning.
