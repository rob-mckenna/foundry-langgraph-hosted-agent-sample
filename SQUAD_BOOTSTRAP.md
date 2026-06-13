# Project Requirements

This document is the source of truth for project compliance verification. All team members and automation must adhere to the requirements below.

## Naming & Branding
- All references to the AI platform must use "Microsoft Foundry" — NOT "Azure AI Foundry", "Azure AI Studio", or "Foundry Hub"

## Authentication
- Authentication MUST use `DefaultAzureCredential` (Azure Identity SDK)
- API keys are NOT permitted anywhere in the codebase (source, config, IaC, workflows)
- Production deployments use managed identity
- GitHub Actions use OIDC/federated identity (no service principal secrets)

## Infrastructure as Code (IaC)
- IaC is located in the top-level `infra/` directory
- Two subdirectories: `infra/bicep/` and `infra/terraform/`
- Both must provision equivalent resources for the Microsoft Foundry hosted agent
- IaC provisions Microsoft Foundry PROJECT setup ONLY
- Do NOT use deprecated Foundry Hub deployment patterns
- Resources provisioned: Container Apps Environment, Container App, User-Assigned Managed Identity, Log Analytics, RBAC role assignments

## GitHub Actions Workflows
- CI workflow: lint (ruff) + test (pytest) on push/PR to `main`
- Deploy workflow: provision and deploy via `azd up` on push to `main`
- Build workflow: build and push Docker images to ACR on source changes
- All workflows use OIDC for Azure authentication (no stored secrets for Azure access)

## Deployment
- Solution MUST be deployable via `azd up` from the repository root
- Root-level `azure.yaml` configures the azd project
- Bicep templates are referenced from `infra/bicep/`
- The Foundry host Container App runs on port 8088
- The standalone host Container App runs on port 8080

## Project Structure
```text
├── azure.yaml              # azd project config (root-level)
├── infra/
│   ├── bicep/              # Bicep IaC templates
│   │   ├── main.bicep
│   │   └── parameters.json
│   └── terraform/          # Terraform IaC templates
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── ...
├── .github/workflows/
│   ├── ci.yml              # Lint + test
│   ├── deploy.yml          # azd provision + deploy
│   └── build-image.yml     # Docker build + push to ACR
├── src/                    # Application source
├── frontend/               # Sample chat UI
├── deployment/             # Dockerfiles and deploy scripts
└── tests/                  # Test suite
```
