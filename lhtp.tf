resource "azurerm_network_security_group" "lhtp" {
  name                = "${var.environment_code}${var.deployment_code}${var.location_code}lhtp-nsg"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.web.name}"
  count               = "${lookup(var.instance_counts, "lhtp", 0) == 0 ? 0 : 1}"

  security_rule {
    name                       = "HTTPS"
    priority                   = 107
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 105
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

/* resource "azurerm_lb" "lb_lhtp" {
  name                = "${var.environment_code}${var.deployment_code}${var.location_code}-lb-lhtp"
  resource_group_name = "${azurerm_resource_group.data.name}"
  count               = "${lookup(var.instance_counts, "lhtp", 0) == 0 ? 0 : 1}"
  location            = "${var.azure_location}"

  frontend_ip_configuration {
    name                          = "loadBalancerFrontEnd"
    subnet_id                     = "${azurerm_subnet.web.id}"
    private_ip_address_allocation = "dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "lb_backend_pool_lhtp" {
  name                = "${var.environment_code}${var.deployment_code}${var.location_code}-pool-lhtp"
  resource_group_name = "${azurerm_resource_group.data.name}"
  count               = "${lookup(var.instance_counts, "lhtp", 0) == 0 ? 0 : 1}"
  loadbalancer_id     = "${azurerm_lb.lb_lhtp.id}"
}

resource "azurerm_lb_probe" "lb_probe_lhtp" {
  resource_group_name = "${azurerm_resource_group.data.name}"
  count               = "${lookup(var.instance_counts, "lhtp", 0) == 0 ? 0 : 1}"
  loadbalancer_id     = "${azurerm_lb.lb_lhtp.id}"
  name                = "${var.environment_code}${var.deployment_code}${var.location_code}-pool-lhtp"
  port                = 443
  interval_in_seconds = 5
}

resource "azurerm_lb_rule" "lb_rule_lhtp" {
  resource_group_name            = "${azurerm_resource_group.data.name}"
  count                          = "${lookup(var.instance_counts, "lhtp", 0) == 0 ? 0 : 1}"
  loadbalancer_id                = "${azurerm_lb.lb_lhtp.id}"
  name                           = "${var.environment_code}${var.deployment_code}${var.location_code}-rule-lhtp"
  protocol                       = "TCP"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "loadBalancerFrontEnd"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.lb_backend_pool_lhtp.id}"
  probe_id                       = "${azurerm_lb_probe.lb_probe_lhtp.id}"
} */

module "lhtp" {
  source        = "modules/create_vm_linux"
  os_code       = "l"
  instance_type = "htp"
  ssh_key       = "${var.ssh_key}"

  enable_log_analytics        = "${var.enable_log_analytics}"
  enable_vm_diagnostics       = "${var.enable_vm_diagnostics}"
  number_of_vms_in_avset      = "${lookup(var.instance_counts, "lhtp", 0)}"
  platform_fault_domain_count = "${var.platform_fault_domain_count}"
  environment_code            = "${var.environment_code}"
  deployment_code             = "${var.deployment_code}"
  location_code               = "${var.location_code}"
  azure_location              = "${var.azure_location}"
  resource_group_name         = "${azurerm_resource_group.web.name}"
  instance_count              = "${lookup(var.instance_counts, "lhtp", 0)}"
  pip_count                   = "0"
  vm_size                     = "${lookup(var.instance_sizes, "lhtp", "")}"
  subnet_id                   = "${azurerm_subnet.web.id}"

  #lb_pools_ids                = ["${lookup(var.instance_counts, "lhtp", 0) == 0 ? "" : element(concat(azurerm_lb_backend_address_pool.lb_backend_pool_lhtp.*.id, list("")), 0)}"]
  network_security_group_id  = "${lookup(var.instance_counts, "lhtp", 0) == 0 ? "" : element(concat(azurerm_network_security_group.lhtp.*.id, list("")), 0)}"
  storage_type               = "${lookup(var.storage_type, "lhtp", var.storage_type_default)}"
  os_disk_image_id           = "${data.azurerm_image.ubuntu.id}"
  os_disk_size               = "${lookup(var.os_disk_sizes, "lhtp", var.os_disk_size_default)}"
  data_disk_count            = "${lookup(var.data_disk_counts, "lhtp", 0)}"
  data_disk_size             = "${lookup(var.data_disk_sizes, "lhtp", 0)}"
  log_analytics_worspace_id  = "${var.enable_log_analytics == 1 ? element(concat(azurerm_log_analytics_workspace.workspace.*.workspace_id, list("")), 0) : ""}"
  log_analytics_worspace_key = "${var.enable_log_analytics == 1 ? element(concat(azurerm_log_analytics_workspace.workspace.*.primary_shared_key, list("")), 0) : ""}"
}
