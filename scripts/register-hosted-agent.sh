#!/usr/bin/env bash
# Register the container image as a Foundry Hosted Agent.
# This script is called as a post-deploy hook by azd.
# It creates (or updates) a hosted agent version in Foundry Agent Service.
set -euo pipefail

# --- Configuration ---
AGENT_NAME="${HOSTED_AGENT_NAME:-claims-foundry-agent}"
MODEL_DEPLOYMENT="${AZURE_AI_MODEL_DEPLOYMENT_NAME:-gpt-4.1}"

# These are populated by azd from Bicep outputs or environment
REGISTRY_SERVER="${AZURE_CONTAINER_REGISTRY_ENDPOINT:?AZURE_CONTAINER_REGISTRY_ENDPOINT is required}"
PROJECT_ENDPOINT="${FOUNDRY_PROJECT_ENDPOINT:?FOUNDRY_PROJECT_ENDPOINT is required}"

# Determine the image tag — azd tags images during deploy
# Try the common azd naming patterns
if [ -n "${SERVICE_CLAIMS_FOUNDRY_AGENT_IMAGE_NAME:-}" ]; then
  IMAGE="${REGISTRY_SERVER}/${SERVICE_CLAIMS_FOUNDRY_AGENT_IMAGE_NAME}"
else
  # Fallback: query the most recent tag from the ACR repository
  REPO_NAME=$(az acr repository list --name "${REGISTRY_SERVER%%.*}" --query "[0]" -o tsv 2>/dev/null || echo "")
  if [ -n "$REPO_NAME" ]; then
    LATEST_TAG=$(az acr repository show-tags --name "${REGISTRY_SERVER%%.*}" --repository "$REPO_NAME" --orderby time_desc --top 1 -o tsv 2>/dev/null || echo "latest")
    IMAGE="${REGISTRY_SERVER}/${REPO_NAME}:${LATEST_TAG}"
  else
    IMAGE="${REGISTRY_SERVER}/claims-foundry-agent:latest"
  fi
fi

echo "=== Registering Foundry Hosted Agent ==="
echo "  Agent name:       $AGENT_NAME"
echo "  Project endpoint: $PROJECT_ENDPOINT"
echo "  Image:            $IMAGE"
echo "  Model deployment: $MODEL_DEPLOYMENT"

# Get a token for the Foundry data plane
TOKEN=$(az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv)

# Check if the agent already exists
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "${PROJECT_ENDPOINT}/agents/${AGENT_NAME}?api-version=v1")

if [ "$HTTP_CODE" = "200" ]; then
  echo "  Agent exists — creating new version..."
  RESPONSE=$(curl -s -X POST \
    "${PROJECT_ENDPOINT}/agents/${AGENT_NAME}/versions?api-version=v1" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"definition\": {
        \"kind\": \"hosted\",
        \"container_configuration\": {
          \"image\": \"${IMAGE}\"
        },
        \"cpu\": \"1\",
        \"memory\": \"2Gi\",
        \"protocol_versions\": [
          {\"protocol\": \"responses\", \"version\": \"1.0.0\"}
        ],
        \"environment_variables\": {
          \"AZURE_AI_MODEL_DEPLOYMENT_NAME\": \"${MODEL_DEPLOYMENT}\",
          \"USE_MANAGED_IDENTITY\": \"true\"
        }
      }
    }")
else
  echo "  Creating new agent..."
  RESPONSE=$(curl -s -X POST \
    "${PROJECT_ENDPOINT}/agents?api-version=v1" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"${AGENT_NAME}\",
      \"definition\": {
        \"kind\": \"hosted\",
        \"container_configuration\": {
          \"image\": \"${IMAGE}\"
        },
        \"cpu\": \"1\",
        \"memory\": \"2Gi\",
        \"protocol_versions\": [
          {\"protocol\": \"responses\", \"version\": \"1.0.0\"}
        ],
        \"environment_variables\": {
          \"AZURE_AI_MODEL_DEPLOYMENT_NAME\": \"${MODEL_DEPLOYMENT}\",
          \"USE_MANAGED_IDENTITY\": \"true\"
        }
      }
    }")
fi

echo "  Response: $RESPONSE"

# Extract version number from response
VERSION=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('version','unknown'))" 2>/dev/null || echo "unknown")
echo "  Version: $VERSION"

# Poll for active status (max 2 minutes)
echo "  Waiting for agent to become active..."
for i in $(seq 1 24); do
  STATUS=$(curl -s \
    "${PROJECT_ENDPOINT}/agents/${AGENT_NAME}/versions/${VERSION}?api-version=v1" \
    -H "Authorization: Bearer $TOKEN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
  
  if [ "$STATUS" = "active" ]; then
    echo "  ✅ Hosted agent is active!"
    echo "  Invoke via: POST ${PROJECT_ENDPOINT}/agents/${AGENT_NAME}/endpoint/protocols/openai/responses?api-version=v1"
    exit 0
  elif [ "$STATUS" = "failed" ]; then
    echo "  ❌ Agent provisioning failed."
    curl -s "${PROJECT_ENDPOINT}/agents/${AGENT_NAME}/versions/${VERSION}?api-version=v1" \
      -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
    exit 1
  fi
  
  echo "    Status: $STATUS (attempt $i/24)"
  sleep 5
done

echo "  ⚠️  Agent still provisioning after 2 minutes. Check status manually."
exit 0
