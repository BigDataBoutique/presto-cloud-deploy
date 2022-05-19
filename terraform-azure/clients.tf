data "template_file" "client-userdata-script" {
  count    = var.count_clients != "0" ? 1 : 0
  template = file("${path.module}/../assets/client_user_data.sh")

  vars = {
    presto_coordinator_host = azurerm_lb.coordinator.private_ip_address
    coordinator_port        = var.http_port
    admin_password          = var.count_clients != "0" ? random_string.clients-admin-password[0].result : ""
    cert_pem                = tls_self_signed_cert.presto-clients-cert.cert_pem
    key_pem                 = tls_private_key.presto-clients-private-key.private_key_pem
  }
}

resource "random_string" "clients-admin-password" {
  count   = var.count_clients != "0" ? 1 : 0
  length  = 16
  special = false
}

resource "tls_private_key" "presto-clients-private-key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "presto-clients-cert" {
  key_algorithm   = "ECDSA"
  private_key_pem = tls_private_key.presto-clients-private-key.private_key_pem

  subject {
    common_name = "*"
  }

  validity_period_hours = 48

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}


resource "azurerm_virtual_machine_scale_set" "clients" {

  name                = "presto-${var.presto_cluster}-clients"
  resource_group_name = azurerm_resource_group.presto.name
  location            = var.azure_location
  upgrade_policy_mode = "Manual"
  overprovision       = false


  sku {
    name     = var.client_instance_type
    tier     = "Standard"
    capacity = var.count_clients
  }


  os_profile {
    computer_name_prefix = "${var.presto_cluster}-client"
    admin_username       = "ubuntu"
    admin_password       = random_string.vm-login-password.result
    custom_data          = data.template_file.client-userdata-script[0].rendered
  }

  network_profile {
    name    = "presto-${var.presto_cluster}-net-profile"
    primary = true


    ip_configuration {
      name                                   = "presto-${var.presto_cluster}-client-ip-profile"
      subnet_id                              = azurerm_subnet.presto_subnet.id
      primary                                = true
      load_balancer_backend_address_pool_ids = [
        azurerm_lb_backend_address_pool.clients-lb-backend.id
      ]

      public_ip_address_configuration {
        domain_name_label = "presto-${var.presto_cluster}-client"
        idle_timeout      = 4
        name              = "presto-${var.presto_cluster}-client"
      }
    }
  }


  storage_profile_image_reference {
    id = data.azurerm_image.presto-client.id
  }

  storage_profile_os_disk {
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/ubuntu/.ssh/authorized_keys"
      key_data = file(var.key_path)
    }
  }

  storage_profile_data_disk {
    lun               = 0
    caching           = "ReadWrite"
    create_option     = "Empty"
    disk_size_gb      = var.presto_coordinator_volume_size
    managed_disk_type = "Standard_LRS"
  }
}