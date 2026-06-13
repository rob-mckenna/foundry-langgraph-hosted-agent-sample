terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  location                  = data.azurerm_resource_group.this.location
  container_registry_server = var.container_registry_server != "" ? var.container_registry_server : (var.container_registry_name != "" ? data.azurerm_container_registry.acr[0].login_server : "")
}
