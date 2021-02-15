data "template_file" "worker-spot-userdata-script" {
  template = templatefile("${path.module}/../assets/azure/az.user_data.sh", {
    cloud_provider                  = "azure"
    mode_presto                     = "worker"
    environment_name                = var.environment
    http_port                       = var.http_port
    address_presto_coordinator      = local.presto_coordinator_address
    az_account_name                 = var.azure_client_id == null ? "" : var.azure_client_id
    az_access_key                   = var.azure_client_secret == null ? "" : var.azure_client_secret
    heap_size                       = var.worker_heap_size
    query_max_memory_per_node       = ceil(var.worker_heap_size * 0.4)
    query_max_total_memory_per_node = ceil(var.worker_heap_size * 0.6)
    query_max_memory                = var.query_max_memory
    extra_worker_configs            = var.extra_worker_configs
  })
}


resource "azurerm_linux_virtual_machine_scale_set" "workers-spot" {
  count               = (var.count_workers_spot > 0) ? 1 : 0

  name                 = "presto-${var.presto_cluster}-spot-workers"
  resource_group_name  = azurerm_resource_group.presto.name
  location             = var.azure_location
  sku                  = var.worker_spot_instance_type
  overprovision        = false
  priority             = "Spot"
  eviction_policy      = "Delete"
  max_bid_price        = var.worker_spot_hourly_price
  source_image_id      = data.azurerm_image.presto.id
  admin_username       = "ubuntu"
  instances            = var.count_workers_spot
  custom_data          = base64encode(data.template_file.worker-spot-userdata-script.rendered)
  admin_password       = random_string.vm-login-password.result
  computer_name_prefix = "${var.presto_cluster}-worker-spot"

  admin_ssh_key {
    username   = "ubuntu"
    public_key = file(var.key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface {
    name    = "presto-${var.presto_cluster}-spot-net-profile"
    primary = true

    ip_configuration {
      name      = "presto-${var.presto_cluster}-spot-worker-ip-profile"
      subnet_id = azurerm_subnet.presto_subnet.id
      primary   = true

      public_ip_address {
        domain_name_label       = "presto-${var.presto_cluster}-spot-worker"
        idle_timeout_in_minutes = 4
        name                    = "presto-${var.presto_cluster}-spot-worker"
      }
    }
  }


  data_disk {
    lun                  = 0
    caching              = "ReadWrite"
    disk_size_gb         = var.presto_coordinator_volume_size
    storage_account_type = "Standard_LRS"
  }
}