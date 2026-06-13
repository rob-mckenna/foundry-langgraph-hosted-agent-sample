#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: deployment/standalone/deploy.sh <resource-group> <acr-name> <app-name> [image-tag]

Required environment variables:
  AZURE_OPENAI_ENDPOINT
  AZURE_OPENAI_DEPLOYMENT

Optional environment variables:
  AZURE_OPENAI_RESOURCE_ID   Azure OpenAI resource ID for managed identity RBAC.
  LOCATION                   Overrides the resource group's Azure region.
  CONTAINERAPPS_ENVIRONMENT  Defaults to <app-name>-env.
  LOG_ANALYTICS_WORKSPACE    Defaults to <app-name>-logs.
USAGE
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: ${name}" >&2
    exit 1
  fi
}

if [[ $# -lt 3 || $# -gt 4 ]]; then
  usage
  exit 1
fi

RESOURCE_GROUP="$1"
ACR_NAME="$2"
APP_NAME="$3"
IMAGE_TAG="${4:-latest}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
LOCAL_IMAGE="${APP_NAME}:${IMAGE_TAG}"
OPENAI_ROLE_ID='e7332f29-82ae-436f-8842-345e8de50dd3'
ACR_PULL_ROLE_ID='7f951dda-4ed3-4680-a7ca-43fe172d538d'
PLACEHOLDER_IMAGE='mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
ENVIRONMENT_NAME="${CONTAINERAPPS_ENVIRONMENT:-${APP_NAME}-env}"
WORKSPACE_NAME="${LOG_ANALYTICS_WORKSPACE:-${APP_NAME}-logs}"

require_env AZURE_OPENAI_ENDPOINT
require_env AZURE_OPENAI_DEPLOYMENT

if ! command -v docker >/dev/null 2>&1; then
  echo 'docker is required for standalone deployment.' >&2
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo 'Azure CLI is required for standalone deployment.' >&2
  exit 1
fi

LOCATION="${LOCATION:-$(az group show --name "${RESOURCE_GROUP}" --query location --output tsv)}"
ACR_LOGIN_SERVER="$(az acr show --name "${ACR_NAME}" --resource-group "${RESOURCE_GROUP}" --query loginServer --output tsv)"
FULL_IMAGE="${ACR_LOGIN_SERVER}/${APP_NAME}:${IMAGE_TAG}"
APP_EXISTS='false'

if az containerapp show --name "${APP_NAME}" --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
  APP_EXISTS='true'
fi

if ! az monitor log-analytics workspace show --resource-group "${RESOURCE_GROUP}" --workspace-name "${WORKSPACE_NAME}" >/dev/null 2>&1; then
  az monitor log-analytics workspace create \
    --resource-group "${RESOURCE_GROUP}" \
    --workspace-name "${WORKSPACE_NAME}" \
    --location "${LOCATION}" >/dev/null
fi

if ! az containerapp env show --name "${ENVIRONMENT_NAME}" --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
  WORKSPACE_ID="$(az monitor log-analytics workspace show --resource-group "${RESOURCE_GROUP}" --workspace-name "${WORKSPACE_NAME}" --query customerId --output tsv)"
  WORKSPACE_KEY="$(az monitor log-analytics workspace get-shared-keys --resource-group "${RESOURCE_GROUP}" --workspace-name "${WORKSPACE_NAME}" --query primarySharedKey --output tsv)"
  az containerapp env create \
    --name "${ENVIRONMENT_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --logs-workspace-id "${WORKSPACE_ID}" \
    --logs-workspace-key "${WORKSPACE_KEY}" >/dev/null
fi

az acr login --name "${ACR_NAME}" >/dev/null

docker build -f "${REPO_ROOT}/deployment/standalone/Dockerfile" -t "${LOCAL_IMAGE}" "${REPO_ROOT}"
docker tag "${LOCAL_IMAGE}" "${FULL_IMAGE}"
docker push "${FULL_IMAGE}"

if [[ "${APP_EXISTS}" == 'false' ]]; then
  az containerapp create \
    --name "${APP_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --environment "${ENVIRONMENT_NAME}" \
    --image "${PLACEHOLDER_IMAGE}" \
    --target-port 8080 \
    --ingress external \
    --system-assigned \
    --env-vars \
      AZURE_OPENAI_ENDPOINT="${AZURE_OPENAI_ENDPOINT}" \
      AZURE_OPENAI_DEPLOYMENT="${AZURE_OPENAI_DEPLOYMENT}" >/dev/null
else
  az containerapp identity assign \
    --name "${APP_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --system-assigned >/dev/null
fi

PRINCIPAL_ID="$(az containerapp show --name "${APP_NAME}" --resource-group "${RESOURCE_GROUP}" --query identity.principalId --output tsv)"
ACR_RESOURCE_ID="$(az acr show --name "${ACR_NAME}" --resource-group "${RESOURCE_GROUP}" --query id --output tsv)"

if ! az role assignment list --assignee-object-id "${PRINCIPAL_ID}" --scope "${ACR_RESOURCE_ID}" --query "[?roleDefinitionName=='AcrPull'] | [0].id" --output tsv | grep -q .; then
  az role assignment create \
    --assignee-object-id "${PRINCIPAL_ID}" \
    --assignee-principal-type ServicePrincipal \
    --role "${ACR_PULL_ROLE_ID}" \
    --scope "${ACR_RESOURCE_ID}" >/dev/null
fi

if [[ -n "${AZURE_OPENAI_RESOURCE_ID:-}" ]] && ! az role assignment list --assignee-object-id "${PRINCIPAL_ID}" --scope "${AZURE_OPENAI_RESOURCE_ID}" --query "[?roleDefinitionName=='Cognitive Services OpenAI User'] | [0].id" --output tsv | grep -q .; then
  az role assignment create \
    --assignee-object-id "${PRINCIPAL_ID}" \
    --assignee-principal-type ServicePrincipal \
    --role "${OPENAI_ROLE_ID}" \
    --scope "${AZURE_OPENAI_RESOURCE_ID}" >/dev/null
fi

az containerapp registry set \
  --name "${APP_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --server "${ACR_LOGIN_SERVER}" \
  --identity system >/dev/null

az containerapp update \
  --name "${APP_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --image "${FULL_IMAGE}" \
  --set-env-vars \
    AZURE_OPENAI_ENDPOINT="${AZURE_OPENAI_ENDPOINT}" \
    AZURE_OPENAI_DEPLOYMENT="${AZURE_OPENAI_DEPLOYMENT}" >/dev/null

FQDN="$(az containerapp show --name "${APP_NAME}" --resource-group "${RESOURCE_GROUP}" --query properties.configuration.ingress.fqdn --output tsv)"
echo "Standalone API deployed to https://${FQDN}"
