#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: deployment/foundry/deploy.sh <resource-group> <acr-name> <container-app-name> [image-tag]

Required environment variables:
  FOUNDRY_PROJECT_ENDPOINT
  AZURE_AI_MODEL_DEPLOYMENT_NAME

Recommended environment variables:
  OPENAI_RESOURCE_ID         Azure OpenAI resource ID for managed identity RBAC.
  OPENAI_ACCOUNT_NAME        Optional override when the Azure OpenAI account is in the same resource group.
  AZURE_LOCATION             Overrides the resource group's Azure region.
  AZURE_ENV_NAME             azd environment name. Defaults to foundry-agent.
  CONTAINER_APPS_ENVIRONMENT_NAME
  LOG_ANALYTICS_WORKSPACE_NAME
  MANAGED_IDENTITY_NAME
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
CONTAINER_APP_NAME="$3"
IMAGE_TAG="${4:-latest}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
AZD_DIR="${SCRIPT_DIR}/azd"
ENVIRONMENT_NAME="${AZURE_ENV_NAME:-foundry-agent}"
LOCATION="${AZURE_LOCATION:-$(az group show --name "${RESOURCE_GROUP}" --query location --output tsv)}"
ACA_ENV_NAME="${CONTAINER_APPS_ENVIRONMENT_NAME:-${CONTAINER_APP_NAME}-env}"
WORKSPACE_NAME="${LOG_ANALYTICS_WORKSPACE_NAME:-${CONTAINER_APP_NAME}-logs}"
IDENTITY_NAME="${MANAGED_IDENTITY_NAME:-${CONTAINER_APP_NAME}-mi}"
DERIVED_OPENAI_ACCOUNT_NAME="${OPENAI_ACCOUNT_NAME:-${OPENAI_RESOURCE_ID##*/}}"

require_env FOUNDRY_PROJECT_ENDPOINT
require_env AZURE_AI_MODEL_DEPLOYMENT_NAME

if ! command -v az >/dev/null 2>&1; then
  echo 'Azure CLI is required for Foundry deployment.' >&2
  exit 1
fi

if command -v azd >/dev/null 2>&1; then
  cd "${AZD_DIR}"
  azd env select "${ENVIRONMENT_NAME}" >/dev/null 2>&1 || azd env new "${ENVIRONMENT_NAME}" --no-prompt >/dev/null
  azd env set AZURE_LOCATION "${LOCATION}" >/dev/null
  azd env set AZURE_RESOURCE_GROUP "${RESOURCE_GROUP}" >/dev/null
  azd env set CONTAINER_APP_NAME "${CONTAINER_APP_NAME}" >/dev/null
  azd env set CONTAINER_APPS_ENVIRONMENT_NAME "${ACA_ENV_NAME}" >/dev/null
  azd env set LOG_ANALYTICS_WORKSPACE_NAME "${WORKSPACE_NAME}" >/dev/null
  azd env set MANAGED_IDENTITY_NAME "${IDENTITY_NAME}" >/dev/null
  azd env set FOUNDRY_PROJECT_ENDPOINT "${FOUNDRY_PROJECT_ENDPOINT}" >/dev/null
  azd env set AZURE_AI_MODEL_DEPLOYMENT_NAME "${AZURE_AI_MODEL_DEPLOYMENT_NAME}" >/dev/null
  if [[ -n "${DERIVED_OPENAI_ACCOUNT_NAME:-}" ]]; then
    azd env set OPENAI_ACCOUNT_NAME "${DERIVED_OPENAI_ACCOUNT_NAME}" >/dev/null
  fi
  azd env set CONTAINER_REGISTRY_SERVER "" >/dev/null
  azd env set CONTAINER_REGISTRY_NAME "${ACR_NAME}" >/dev/null
  azd provision --no-prompt
  azd deploy --no-prompt
  FQDN="$(az containerapp show --name "${CONTAINER_APP_NAME}" --resource-group "${RESOURCE_GROUP}" --query properties.configuration.ingress.fqdn --output tsv)"
  echo "Foundry agent deployed with azd to https://${FQDN}"
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo 'docker is required when azd is unavailable.' >&2
  exit 1
fi

ACR_LOGIN_SERVER="$(az acr show --name "${ACR_NAME}" --resource-group "${RESOURCE_GROUP}" --query loginServer --output tsv)"
FULL_IMAGE="${ACR_LOGIN_SERVER}/${CONTAINER_APP_NAME}:${IMAGE_TAG}"
LOCAL_IMAGE="${CONTAINER_APP_NAME}:${IMAGE_TAG}"

az acr login --name "${ACR_NAME}" >/dev/null
docker build -f "${REPO_ROOT}/deployment/foundry/Dockerfile" -t "${LOCAL_IMAGE}" "${REPO_ROOT}"
docker tag "${LOCAL_IMAGE}" "${FULL_IMAGE}"
docker push "${FULL_IMAGE}"

az deployment group create \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "${REPO_ROOT}/infra/bicep/main.bicep" \
  --parameters \
    AZURE_LOCATION="${LOCATION}" \
    CONTAINER_APP_NAME="${CONTAINER_APP_NAME}" \
    CONTAINER_APPS_ENVIRONMENT_NAME="${ACA_ENV_NAME}" \
    LOG_ANALYTICS_WORKSPACE_NAME="${WORKSPACE_NAME}" \
    MANAGED_IDENTITY_NAME="${IDENTITY_NAME}" \
    CONTAINER_IMAGE="${FULL_IMAGE}" \
    CONTAINER_REGISTRY_SERVER="${ACR_LOGIN_SERVER}" \
    CONTAINER_REGISTRY_NAME="${ACR_NAME}" \
    FOUNDRY_PROJECT_ENDPOINT="${FOUNDRY_PROJECT_ENDPOINT}" \
    AZURE_AI_MODEL_DEPLOYMENT_NAME="${AZURE_AI_MODEL_DEPLOYMENT_NAME}" \
    OPENAI_ACCOUNT_NAME="${DERIVED_OPENAI_ACCOUNT_NAME:-}" >/dev/null

FQDN="$(az containerapp show --name "${CONTAINER_APP_NAME}" --resource-group "${RESOURCE_GROUP}" --query properties.configuration.ingress.fqdn --output tsv)"
echo "Foundry agent deployed with az CLI to https://${FQDN}"
