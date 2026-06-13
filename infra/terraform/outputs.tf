output "container_app_fqdn" {
  description = "FQDN for the Microsoft Foundry host container app."
  value       = azurerm_container_app.this.ingress[0].fqdn
}

output "managed_identity_id" {
  description = "Resource ID of the user-assigned managed identity."
  value       = azurerm_user_assigned_identity.this.id
}

output "managed_identity_client_id" {
  description = "Client ID of the user-assigned managed identity."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the user-assigned managed identity."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "container_registry_login_server" {
  description = "Login server for the Azure Container Registry."
  value       = azurerm_container_registry.this.login_server
}

output "ai_services_endpoint" {
  description = "Endpoint for the Microsoft Foundry AI Services account."
  value       = azurerm_cognitive_account.ai_services.endpoint
}

output "ai_services_name" {
  description = "Name of the Microsoft Foundry AI Services account."
  value       = azurerm_cognitive_account.ai_services.name
}

output "foundry_project_endpoint" {
  description = "Endpoint for the Microsoft Foundry project."
  value       = "${azurerm_cognitive_account.ai_services.endpoint}api/projects/${var.foundry_project_name}"
}
