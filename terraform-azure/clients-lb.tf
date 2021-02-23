locals {
  presto_clients_address     = var.public_facing  ? azurerm_public_ip.clients[0].ip_address : azurerm_lb.clients.private_ip_address
  clients_private_ip                     = var.public_facing  ? [] : [0]
  clients_frontend_ip_configuration_name = var.public_facing ? "presto-${var.presto_cluster}-clients-public-ip" : "presto-${var.presto_cluster}-clients-private-ip"

}


resource "azurerm_public_ip" "clients" {
  count = var.public_facing ? 1 : 0

  name                = "presto-${var.presto_cluster}-clients-public-ip"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.presto.name
  domain_name_label   = "presto-${var.presto_cluster}-clients"
  allocation_method   = "Static"
}

resource "azurerm_lb" "clients" {

  location            = var.azure_location
  name                = "presto-${var.presto_cluster}-clients-lb"
  resource_group_name = azurerm_resource_group.presto.name


  dynamic frontend_ip_configuration {
    for_each = azurerm_public_ip.clients
    content {
      name                 = "presto-${var.presto_cluster}-clients-public-ip"
      public_ip_address_id = frontend_ip_configuration.value.id
    }
  }

  dynamic frontend_ip_configuration {
    for_each = local.clients_private_ip
    content {
      name                          = "presto-${var.presto_cluster}-clients-private-ip"
      subnet_id                     = azurerm_subnet.presto_subnet.id
      private_ip_address_allocation = "Dynamic"
      public_ip_address_id          = null
    }
  }

}


resource "azurerm_lb_backend_address_pool" "clients-lb-backend" {
  name                = "presto-${var.presto_cluster}-clients-lb-backend"
  resource_group_name = azurerm_resource_group.presto.name
  loadbalancer_id     = azurerm_lb.clients.id
}

resource "azurerm_lb_probe" "clients-httpprobe" {
  name                = "es-${var.presto_cluster}-clients-lb-probe"
  port                = 8080
  protocol            = "Http"
  request_path        = "/status"
  resource_group_name = azurerm_resource_group.presto.name
  loadbalancer_id     = azurerm_lb.clients.id
}

resource "azurerm_lb_rule" "clients-lb-rule-redash" {
  name          = "es-${var.presto_cluster}-clients-lb-rule-redash"
  backend_port  = 8500
  frontend_port = 8500

  frontend_ip_configuration_name = local.clients_frontend_ip_configuration_name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.clients-lb-backend.id
  protocol                       = "Tcp"
  loadbalancer_id                = azurerm_lb.clients.id
  resource_group_name            = azurerm_resource_group.presto.name
}

resource "azurerm_lb_rule" "clients-lb-rule-superset" {
  name          = "es-${var.presto_cluster}-clients-lb-rule-superset"
  backend_port  = 8600
  frontend_port = 8600

  frontend_ip_configuration_name = local.clients_frontend_ip_configuration_name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.clients-lb-backend.id
  protocol                       = "Tcp"
  loadbalancer_id                = azurerm_lb.clients.id
  resource_group_name            = azurerm_resource_group.presto.name
}

resource "azurerm_lb_rule" "clients-lb-rule-zeppelin" {
  name          = "es-${var.presto_cluster}-clients-lb-rule-zeppelin"
  backend_port  = 8700
  frontend_port = 8700

  frontend_ip_configuration_name = local.clients_frontend_ip_configuration_name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.clients-lb-backend.id
  protocol                       = "Tcp"
  loadbalancer_id                = azurerm_lb.clients.id
  resource_group_name            = azurerm_resource_group.presto.name
}

