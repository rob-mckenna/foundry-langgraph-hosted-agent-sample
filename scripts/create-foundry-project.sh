#!/usr/bin/env bash
# Post-provision hook: Creates the Microsoft Foundry project.
# ARM cannot create the project in the same deployment as the account because
# the system-assigned identity must propagate in Entra ID first.
set -euo pipefail

AI_SERVICES_NAME="${AI_SERVICES_NAME:-claims-foundry-ai}"
FOUNDRY_PROJECT_NAME="${FOUNDRY_PROJECT_NAME:-claims-foundry-project}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-foundry-lg-agent-demo}"
LOCATION="${AZURE_LOCATION:-eastus2}"

echo "Checking if Foundry project '${FOUNDRY_PROJECT_NAME}' already exists..."
EXISTING=$(az cognitiveservices account project list \
  --account-name "$AI_SERVICES_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?name=='${FOUNDRY_PROJECT_NAME}'].name" \
  -o tsv 2>/dev/null || echo "")

if [ -n "$EXISTING" ]; then
  echo "✅ Foundry project '${FOUNDRY_PROJECT_NAME}' already exists. Skipping."
  exit 0
fi

echo "Waiting for identity propagation (30s)..."
sleep 30

echo "Creating Foundry project '${FOUNDRY_PROJECT_NAME}'..."
az cognitiveservices account project create \
  --account-name "$AI_SERVICES_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$FOUNDRY_PROJECT_NAME" \
  --location "$LOCATION" \
  --project-kind "Foundry" \
  --description "Claims Foundry agent project"

echo "✅ Foundry project '${FOUNDRY_PROJECT_NAME}' created successfully."
