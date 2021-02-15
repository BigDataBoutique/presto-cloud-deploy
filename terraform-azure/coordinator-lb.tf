locals {
  presto_coordinator_address                 = var.public_facing  ? azurerm_public_ip.coordinator[0].ip_address : azurerm_lb.coordinator.private_ip_address
  coordinator_private_ip                     = var.public_facing  ? [] : [0]
  coordinator_frontend_ip_configuration_name = var.public_facing ? "presto-${var.presto_cluster}-public-ip" : "presto-${var.presto_cluster}-private-ip"

}


resource "azurerm_public_ip" "coordinator" {
  count = var.public_facing ? 1 : 0

  name                = "presto-${var.presto_cluster}-coordinator-public-ip"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.presto.name
  domain_name_label   = "presto-${var.presto_cluster}-coordinator"
  allocation_method   = "Static"
}

resource "azurerm_lb" "coordinator" {

  location            = var.azure_location
  name                = "presto-${var.presto_cluster}-coordinator-lb"
  resource_group_name = azurerm_resource_group.presto.name


  dynamic frontend_ip_configuration {
    for_each = azurerm_public_ip.coordinator
    content {
      name                 = "presto-${var.presto_cluster}-public-ip"
      public_ip_address_id = frontend_ip_configuration.value.id
    }
  }

  dynamic frontend_ip_configuration {
    for_each = local.coordinator_private_ip
    content {
      name                          = "presto-${var.presto_cluster}-private-ip"
      subnet_id                     = azurerm_subnet.presto_subnet.id
      private_ip_address_allocation = "Dynamic"
      public_ip_address_id          = null
    }
  }

}


resource "azurerm_lb_backend_address_pool" "coordinator-lb-backend" {
  name                = "presto-${var.presto_cluster}-coordinator-lb-backend"
  resource_group_name = azurerm_resource_group.presto.name
  loadbalancer_id     = azurerm_lb.coordinator.id
}

resource "azurerm_lb_probe" "coordinator-httpprobe" {
  name                = "es-${var.presto_cluster}-coordinator-lb-probe"
  port                = 8080
  protocol            = "Http"
  request_path        = "/status"
  resource_group_name = azurerm_resource_group.presto.name
  loadbalancer_id     = azurerm_lb.coordinator.id
}

resource "azurerm_lb_rule" "coordinator-lb-rule" {
  name          = "es-${var.presto_cluster}-coordinator-lb-rule"
  backend_port  = 8080
  frontend_port = 8080

  frontend_ip_configuration_name = local.coordinator_frontend_ip_configuration_name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.coordinator-lb-backend.id
  protocol                       = "Tcp"
  loadbalancer_id                = azurerm_lb.coordinator.id
  resource_group_name            = azurerm_resource_group.presto.name
}

