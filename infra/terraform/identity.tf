locals {
  cognitive_services_openai_user_role_definition_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/e7332f29-82ae-436f-8842-345e8de50dd3"
  acr_pull_role_definition_id                       = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d"
}

resource "azurerm_user_assigned_identity" "this" {
  name                = var.managed_identity_name
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_container_registry" "this" {
  name                = var.container_registry_name
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "Basic"
  admin_enabled       = false
}

resource "azurerm_cognitive_account" "ai_services" {
  name                  = var.ai_services_name
  location              = local.location
  resource_group_name   = data.azurerm_resource_group.this.name
  kind                  = "AIServices"
  sku_name              = "S0"
  custom_subdomain_name = var.ai_services_name
  public_network_access_enabled = true
}

resource "azurerm_cognitive_deployment" "model" {
  name                 = var.azure_ai_model_deployment_name
  cognitive_account_id = azurerm_cognitive_account.ai_services.id

  model {
    format  = "OpenAI"
    name    = var.azure_ai_model_deployment_name
    version = var.ai_model_version
  }

  sku {
    name     = "Standard"
    capacity = var.ai_model_capacity
  }
}

resource "azurerm_role_assignment" "openai_user" {
  scope              = azurerm_cognitive_account.ai_services.id
  role_definition_id = local.cognitive_services_openai_user_role_definition_id
  principal_id       = azurerm_user_assigned_identity.this.principal_id
}

resource "azurerm_role_assignment" "acr_pull" {
  scope              = azurerm_container_registry.this.id
  role_definition_id = local.acr_pull_role_definition_id
  principal_id       = azurerm_user_assigned_identity.this.principal_id
}
