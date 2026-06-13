#!/usr/bin/env bash
# predeploy hook — removes stale azd env variables that can poison the
# Foundry Hosted Agent publish step.
#
# These are auto-generated outputs from earlier azd provisions that conflict
# with the azure.ai.agent host type. Safe to remove: azd provision will
# re-create any that are still needed.

set -euo pipefail

STALE_PREFIXES=(
  "SERVICE_"
  "containerApp"
  "managedIdentity"
)

env_file=""
if [ -n "${AZURE_ENV_NAME:-}" ]; then
  env_file=".azure/${AZURE_ENV_NAME}/.env"
fi

if [ -z "$env_file" ] || [ ! -f "$env_file" ]; then
  echo "No azd env file found — skipping stale var cleanup."
  exit 0
fi

removed=0
for prefix in "${STALE_PREFIXES[@]}"; do
  count=$(grep -c "^${prefix}" "$env_file" 2>/dev/null || true)
  if [ "$count" -gt 0 ]; then
    sed -i "/^${prefix}/d" "$env_file"
    removed=$((removed + count))
  fi
done

if [ "$removed" -gt 0 ]; then
  echo "Cleaned $removed stale env variable(s) from $env_file"
else
  echo "No stale env variables found — env is clean."
fi
