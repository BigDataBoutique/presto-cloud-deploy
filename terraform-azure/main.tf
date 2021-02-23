provider "azurerm" {
  subscription_id = var.azure_subscription_id
  client_id = var.azure_client_id
  client_secret = var.azure_client_secret
  tenant_id = var.azure_tenant_id
  features {}
}

resource "random_string" "vm-login-password" {
  length = 16
  special = true
  override_special = "!@#%&-_"
}

resource "azurerm_resource_group" "presto" {
  location = var.azure_location
  name = "presto-cluster-${var.presto_cluster}"
}

resource "azurerm_virtual_network" "presto_vnet" {
  name                = "presto-${var.presto_cluster}-vnet"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.presto.name
  address_space       = ["10.1.0.0/24"]
}

resource "azurerm_subnet" "presto_subnet" {
  name                 = "presto-${var.presto_cluster}-subnet"
  resource_group_name  = azurerm_resource_group.presto.name
  virtual_network_name = azurerm_virtual_network.presto_vnet.name
  address_prefixes       = ["10.1.0.0/24"]
}