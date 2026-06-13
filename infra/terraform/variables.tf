variable "subscription_id" {
  description = "Azure subscription ID used by the azurerm provider."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group that will contain the Microsoft Foundry hosting resources."
  type        = string
}

variable "container_app_name" {
  description = "Name for the Container App that hosts the Microsoft Foundry agent."
  type        = string
  default     = "claims-foundry-agent"
}

variable "container_apps_environment_name" {
  description = "Name for the Container Apps managed environment."
  type        = string
  default     = "claims-foundry-env"
}

variable "log_analytics_workspace_name" {
  description = "Name for the Log Analytics workspace."
  type        = string
  default     = "claims-foundry-logs"
}

variable "managed_identity_name" {
  description = "Name for the user-assigned managed identity used by the container app."
  type        = string
  default     = "claims-foundry-agent-mi"
}

variable "container_image" {
  description = "Container image to run inside the Microsoft Foundry host container app."
  type        = string
}

variable "container_registry_name" {
  description = "Name for the Azure Container Registry."
  type        = string
  default     = "claimsfoundryacr"
}

variable "ai_services_name" {
  description = "Name for the Azure AI Services (Microsoft Foundry) account."
  type        = string
  default     = "claims-foundry-ai"
}

variable "azure_ai_model_deployment_name" {
  description = "Model deployment name (e.g. gpt-4.1, gpt-4o)."
  type        = string
  default     = "gpt-4.1"
}

variable "ai_model_version" {
  description = "Model version to deploy."
  type        = string
  default     = "2025-04-14"
}

variable "ai_model_capacity" {
  description = "Model SKU capacity (thousands of tokens per minute)."
  type        = number
  default     = 10
}

variable "container_cpu" {
  description = "CPU allocated to the container app."
  type        = number
  default     = 1
}

variable "container_memory" {
  description = "Memory allocated to the container app."
  type        = string
  default     = "2Gi"
}
