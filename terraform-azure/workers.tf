data "template_file" "worker-userdata-script" {
  template = templatefile("${path.module}/../assets/azure/az.user_data.sh", {
    cloud_provider                  = "azure"
    mode_presto                     = "worker"
    environment_name                = var.environment
    http_port                       = var.http_port
    address_presto_coordinator      = local.presto_coordinator_address
    heap_size                       = var.worker_heap_size
    az_account_name                 = var.azure_client_id == null ? "" : var.azure_client_id
    az_access_key                   = var.azure_client_secret == null ? "" : var.azure_client_secret
    query_max_memory_per_node       = ceil(var.worker_heap_size * 0.4)
    query_max_total_memory_per_node = ceil(var.worker_heap_size * 0.6)
    query_max_memory                = var.query_max_memory
    extra_worker_configs            = var.extra_worker_configs
  })
}


resource "azurerm_virtual_machine_scale_set" "workers" {

  count               = (var.count_workers > 0) ? 1 : 0
  name                = "presto-${var.presto_cluster}-workers"
  resource_group_name = azurerm_resource_group.presto.name
  location            = var.azure_location
  sku {
    name     = var.worker_instance_type
    tier     = "Standard"
    capacity = var.count_workers
  }

  upgrade_policy_mode = "Manual"
  overprovision       = false

  os_profile {
    computer_name_prefix = "${var.presto_cluster}-worker"
    admin_username       = "ubuntu"
    admin_password       = random_string.vm-login-password.result
    custom_data          = data.template_file.worker-userdata-script.rendered
  }

  network_profile {
    name                   = "presto-${var.presto_cluster}-net-profile"
    primary                = true
    accelerated_networking = true

    ip_configuration {
      name      = "presto-${var.presto_cluster}-worker-ip-profile"
      subnet_id = azurerm_subnet.presto_subnet.id
      primary   = true
      public_ip_address_configuration {
        domain_name_label = "presto-${var.presto_cluster}-worker"
        idle_timeout      = 4
        name              = "presto-${var.presto_cluster}-worker"
      }
    }
  }


  storage_profile_image_reference {
    id = data.azurerm_image.presto.id
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