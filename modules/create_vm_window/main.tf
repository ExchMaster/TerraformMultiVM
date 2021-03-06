
locals {
  base_hostname = "${format("%s%s%s%s%s", var.environment_code, var.deployment_code, var.location_code, var.os_code, var.instance_type)}"
}

resource "azurerm_public_ip" "vm_pip" {
  count = "${var.pip_count}"
  name = "${format("%s%03d", local.base_hostname, count.index + 1)}"
  location = "${var.azure_location}"
  resource_group_name = "${var.resource_group_name}"
  public_ip_address_allocation = "static"
  domain_name_label = "${var.instance_type == "net" ? format("%s%s-%d", var.deployment_code, var.location_code, count.index + 1) : format("%s%03d", local.base_hostname, count.index + 1)}"
}

resource "azurerm_network_interface" "vm_nic" {
  count = "${var.instance_count}"
  name = "${format("%s%03dNetworkInterface", local.base_hostname, count.index + 1)}"
  location = "${var.azure_location}"
  resource_group_name = "${var.resource_group_name}"
  network_security_group_id = "${var.network_security_group_id}"
  enable_ip_forwarding = "${var.ip_forwarding}"
  #enable_accelerated_networking = true

  ip_configuration {
    name = "ipconfig"
    load_balancer_backend_address_pools_ids = ["${compact(split(",", contains(var.load_balancer_pool_exclusions, "${format("%s%03d", local.base_hostname, count.index + 1)}") ? "" : join(",", var.lb_pools_ids)))}"]
    subnet_id = "${var.subnet_id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id = "${var.pip_count == 0 ? "" : element(concat(azurerm_public_ip.vm_pip.*.id, list("")), count.index)}"
  }
}

resource "azurerm_managed_disk" "data_disk" {
  count = "${var.instance_count == 0 ? 0 : var.data_disk_count}"
  name = "${format("%s-DataDisk-%03d", local.base_hostname, count.index + 1)}"
  location = "${var.azure_location}"
  resource_group_name = "${var.resource_group_name}"
  storage_account_type = "${var.storage_type}"
  create_option = "Empty"
  disk_size_gb = "${var.data_disk_size}"
}

resource "azurerm_storage_account" "diag_storage_account" {
  count = "${var.instance_count}"
  name = "${format("%sstg%03ddiag", local.base_hostname, count.index + 1)}"
  resource_group_name = "${var.resource_group_name}"
  location = "${var.azure_location}"
  account_tier = "Standard"
  account_replication_type = "LRS"
  enable_blob_encryption = "true"
}

resource "azurerm_availability_set" "av_set" {
 count =   "${var.number_of_vms_in_avset == 0 ? 0 : ceil(var.instance_count * 1.0 / (var.number_of_vms_in_avset == 0 ? 1 : var.number_of_vms_in_avset))}"
 name = "${var.number_of_vms_in_avset == var.instance_count ? format("%s-AVSet", local.base_hostname) : format("%s-AVSet%03d", local.base_hostname, count.index + 1)}"
 location = "${var.azure_location}"
 resource_group_name = "${var.resource_group_name}"
 managed = true
 platform_fault_domain_count = "${var.platform_fault_domain_count}"
 platform_update_domain_count = 20
}

resource "azurerm_virtual_machine" "vm" {
  count = "${ var.instance_count}"
  name = "${format("%s%03d", local.base_hostname, count.index + 1)}"
  location = "${var.azure_location}"
  resource_group_name = "${var.resource_group_name}"
  #availability_set_id = "${ceil(count.index / (var.number_of_vms_in_avset == 0 ? 1 : var.number_of_vms_in_avset))}"
  availability_set_id = "${var.number_of_vms_in_avset == 0 ? "" : element(concat(azurerm_availability_set.av_set.*.id, list("")), ceil(count.index / (var.number_of_vms_in_avset == 0 ? 1 : var.number_of_vms_in_avset)))}"
  vm_size = "${var.vm_size}"
  network_interface_ids = ["${element(azurerm_network_interface.vm_nic.*.id, count.index)}"]

  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  lifecycle {
    ignore_changes = [
      "storage_os_disk",              # Ignore os disk changes here.
      "storage_image_reference",      # Ignore original image changes (e.g. CentOS 7.2 to 7.3)
      "os_profile",                   # We don't need Azure to manage the name or login.
      "os_profile_linux_config",      # This seems completely broken - miscounts ssh keys, keeps recreating.
      "storage_data_disk",            # This tries to "adjust" all existing data disks. Dangerous.
      "resource_group_name"           # Case mismatch problems.
    ]
  #  prevent_destroy = true            # Throw an error if this is about to destroy the VM.
  }

  storage_image_reference {
    id = "${var.os_disk_image_id}"
  }

  storage_os_disk {
    name = "${format("%s%03d", local.base_hostname, count.index + 1)}-osdisk"
    caching = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "${var.storage_type}"
  }

  os_profile {
    computer_name = "${format("%s%03d", local.base_hostname, count.index + 1)}"
    admin_username = "${var.windows_admin_username}"
    admin_password = "${var.windows_admin_password}"
  }

  boot_diagnostics {
    enabled = false
    storage_uri = "${element(azurerm_storage_account.diag_storage_account.*.primary_blob_endpoint, count.index)}"
  }

  os_profile_windows_config {
    enable_automatic_upgrades = true
    provision_vm_agent = true
  }
}

 resource "azurerm_virtual_machine_extension" "vm_extension" {
  count                = "${var.instance_count > 0 ? 1 : 0}"
  name                 = "${format("%s%03d", local.base_hostname, count.index + 1)}"
  location             = "${var.azure_location}"
  resource_group_name  = "${var.resource_group_name}"
  virtual_machine_name = "${element(azurerm_virtual_machine.vm.*.name, count.index)}"
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.8"
  auto_upgrade_minor_version = "true"

  settings = <<EOF
    {
        "commandToExecute": "Powershell sc.exe config puppet start=auto; sc.exe start puppet;"
    }
EOF
} 

