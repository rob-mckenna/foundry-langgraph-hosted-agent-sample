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
  description = "Optional Azure Container Registry name in the current resource group. When provided, the managed identity receives AcrPull."
  type        = string
  default     = ""
}

variable "container_registry_server" {
  description = "Optional Azure Container Registry login server. When provided, the managed identity is used for image pulls."
  type        = string
  default     = ""
}

variable "foundry_project_endpoint" {
  description = "Microsoft Foundry project endpoint exposed to the container app as FOUNDRY_PROJECT_ENDPOINT."
  type        = string
}

variable "azure_ai_model_deployment_name" {
  description = "Model deployment name exposed to the container app as AZURE_AI_MODEL_DEPLOYMENT_NAME."
  type        = string
  default     = "gpt-4.1"
}

variable "openai_account_name" {
  description = "Optional Azure OpenAI account name in the current resource group used for the Cognitive Services OpenAI User role assignment."
  type        = string
  default     = ""
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
