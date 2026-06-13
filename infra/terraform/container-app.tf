resource "azurerm_container_app_environment" "this" {
  name                       = var.container_apps_environment_name
  location                   = local.location
  resource_group_name        = data.azurerm_resource_group.this.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
}

resource "azurerm_container_app" "this" {
  name                         = var.container_app_name
  resource_group_name          = data.azurerm_resource_group.this.name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Single"

  tags = {
    "azd-service-name" = "claims-foundry-agent"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 8088
    transport                  = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  registry {
    server   = azurerm_container_registry.this.login_server
    identity = azurerm_user_assigned_identity.this.id
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "foundry-agent"
      image  = var.container_image
      cpu    = var.container_cpu
      memory = var.container_memory

      env {
        name  = "PORT"
        value = "8088"
      }

      env {
        name  = "FOUNDRY_PROJECT_ENDPOINT"
        value = "${azurerm_cognitive_account.ai_services.endpoint}api/projects/${var.foundry_project_name}"
      }

      env {
        name  = "AZURE_AI_MODEL_DEPLOYMENT_NAME"
        value = var.azure_ai_model_deployment_name
      }

      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.this.client_id
      }
    }
  }

  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_role_assignment.openai_user,
  ]
}
