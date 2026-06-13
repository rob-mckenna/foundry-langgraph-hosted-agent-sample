locals {
  cognitive_services_openai_user_role_definition_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/e7332f29-82ae-436f-8842-345e8de50dd3"
  acr_pull_role_definition_id                       = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d"
}

resource "azurerm_user_assigned_identity" "this" {
  name                = var.managed_identity_name
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_cognitive_account" "openai" {
  count               = var.openai_account_name != "" ? 1 : 0
  name                = var.openai_account_name
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_container_registry" "acr" {
  count               = var.container_registry_name != "" ? 1 : 0
  name                = var.container_registry_name
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_role_assignment" "openai_user" {
  count              = var.openai_account_name != "" ? 1 : 0
  scope              = data.azurerm_cognitive_account.openai[0].id
  role_definition_id = local.cognitive_services_openai_user_role_definition_id
  principal_id       = azurerm_user_assigned_identity.this.principal_id
}

resource "azurerm_role_assignment" "acr_pull" {
  count              = var.container_registry_name != "" ? 1 : 0
  scope              = data.azurerm_container_registry.acr[0].id
  role_definition_id = local.acr_pull_role_definition_id
  principal_id       = azurerm_user_assigned_identity.this.principal_id
}
