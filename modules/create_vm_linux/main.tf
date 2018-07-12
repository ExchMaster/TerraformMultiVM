locals {
  base_hostname = "${format("%s%s%s%s%s", var.environment_code, var.deployment_code, var.location_code, var.os_code, var.instance_type)}"
}

resource "random_string" "datadisk_id" {
  count       = "${var.instance_count == 0 ? 0 : var.instance_count * var.data_disk_count}"
  length      = 8
  special     = false
  min_upper   = 0
  min_lower   = 1
  min_special = 0
}

resource "azurerm_public_ip" "vm_pip" {
  count                        = "${var.pip_count}"
  name                         = "${format("%s%03d", local.base_hostname, count.index + 1)}"
  location                     = "${var.azure_location}"
  resource_group_name          = "${var.resource_group_name}"
  public_ip_address_allocation = "static"
  domain_name_label            = "${var.instance_type == "net" ? format("%s%s-%d", var.deployment_code, var.location_code, count.index + 1) : format("%s%03d", local.base_hostname, count.index + 1)}"
}

resource "azurerm_network_interface" "vm_nic" {
  count                         = "${var.instance_count}"
  name                          = "${format("%s%03dNetworkInterface", local.base_hostname, count.index + 1)}"
  location                      = "${var.azure_location}"
  resource_group_name           = "${var.resource_group_name}"
  network_security_group_id     = "${var.network_security_group_id}"
  enable_ip_forwarding          = "${var.ip_forwarding}"
  enable_accelerated_networking = true

  ip_configuration {
    name                                    = "ipconfig"
    load_balancer_backend_address_pools_ids = ["${compact(split(",", contains(var.load_balancer_pool_exclusions, "${format("%s%03d", local.base_hostname, count.index + 1)}") ? "" : join(",", var.lb_pools_ids)))}"]
    subnet_id                               = "${var.subnet_id}"
    private_ip_address_allocation           = "dynamic"
    public_ip_address_id                    = "${var.pip_count == 0 ? "" : element(concat(azurerm_public_ip.vm_pip.*.id, list("")), count.index)}"
  }
}

resource "azurerm_managed_disk" "data_disk" {
  count                = "${var.instance_count == 0 ? 0 : var.instance_count * var.data_disk_count}"
  name                 = "${format("%s%03d-datadisk-%s", local.base_hostname, ceil((count.index + 1) * 1.0 / var.data_disk_count), element(random_string.datadisk_id.*.result, count.index))}"
  location             = "${var.azure_location}"
  resource_group_name  = "${var.resource_group_name}"
  storage_account_type = "${var.storage_type}"
  create_option        = "Empty"
  disk_size_gb         = "${var.data_disk_size}"
}

/* resource "azurerm_virtual_machine_data_disk_attachment" "data_disk_attach" {
  count =   "${var.instance_count == 0 ? 0 : var.instance_count * var.data_disk_count}"
  virtual_machine_id = "${element(azurerm_virtual_machine.vm.*.id, ceil((count.index + 1) * 1.0 / var.data_disk_count))}"
  managed_disk_id    = "${element(azurerm_managed_disk.data_disk.*.id, count.index)}"
  lun                = "${floor((count.index +1) / ceil((count.index + 1) * 1.0 / var.data_disk_count)) - 1}"
  caching            = "ReadOnly"
}  */

/* resource "azurerm_storage_account" "diag_storage_account" {
  count                    = "${var.enable_vm_diagnostics == 0 ? 0 : var.instance_count}"
  name                     = "${format("%sstg%03ddiag", local.base_hostname, count.index + 1)}"
  resource_group_name      = "${var.resource_group_name}"
  location                 = "${var.azure_location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  enable_blob_encryption   = "true"
} */

/* resource "azurerm_availability_set" "av_set" {
  count                        = "${var.number_of_vms_in_avset == 0 ? 0 : ceil(var.instance_count * 1.0 / (var.number_of_vms_in_avset == 0 ? 1 : var.number_of_vms_in_avset))}"
  name                         = "${var.number_of_vms_in_avset == var.instance_count ? format("%s-AVSet", local.base_hostname) : format("%s-AVSet%03d", local.base_hostname, count.index + 1)}"
  location                     = "${var.azure_location}"
  resource_group_name          = "${var.resource_group_name}"
  managed                      = true
  platform_fault_domain_count  = "${var.platform_fault_domain_count}"
  platform_update_domain_count = 20
} */

resource "azurerm_virtual_machine" "vm" {
  count               = "${ var.instance_count}"
  name                = "${format("%s%03d", local.base_hostname, count.index + 1)}"
  location            = "${var.azure_location}"
  resource_group_name = "${var.resource_group_name}"

  #availability_set_id   = "${var.number_of_vms_in_avset == 0 ? "" : element(concat(azurerm_availability_set.av_set.*.id, list("")), ceil(count.index / (var.number_of_vms_in_avset == 0 ? 1 : var.number_of_vms_in_avset)))}"
  vm_size               = "${var.vm_size}"
  network_interface_ids = ["${element(azurerm_network_interface.vm_nic.*.id, count.index)}"]

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  lifecycle {
    #prevent_destroy = true            # Throw an error if this is about to destroy the VM.
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${format("%s%03d", local.base_hostname, count.index + 1)}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "${var.storage_type}"
    disk_size_gb      = "${var.os_disk_size}"
  }

  os_profile {
    computer_name  = "${format("%s%03d", local.base_hostname, count.index + 1)}"
    admin_username = "uadmin"
  }

  /* boot_diagnostics {
    enabled     = "${var.enable_vm_diagnostics == 0 ? false : true }"
    storage_uri = "${var.enable_vm_diagnostics == 0 ? "" : element(concat(azurerm_storage_account.diag_storage_account.*.primary_blob_endpoint, list("")), count.index)}"
  } */

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys = [
      {
        path     = "/home/uadmin/.ssh/authorized_keys"
        key_data = "${var.ssh_key}"
      },
    ]
  }
}

/* resource "azurerm_virtual_machine_extension" "vm_extension" {
  count                = "${var.enable_log_analytics == 0 ? 0 : (var.instance_count > 0 ? 1 : 0)}"
  name                 = "LogAnalyticsMonitoring"
  location             = "${var.azure_location}"
  resource_group_name  = "${var.resource_group_name}"
  virtual_machine_name = "${format("%s%03d", local.base_hostname, count.index + 1)}"
  publisher            = "Microsoft.EnterpriseCloud.Monitoring"
  type                 = "OmsAgentForLinux"
  type_handler_version = "1.4"

  settings = <<SETTINGS
    {
        "workspaceId": "${var.log_analytics_worspace_id}"
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
        "workspaceKey": "${var.log_analytics_worspace_key}",
        "vmResourceId": "${element(azurerm_virtual_machine.vm.*.id, count.index)}"
    }
PROTECTED_SETTINGS
} */

