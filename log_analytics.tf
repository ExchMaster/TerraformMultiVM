resource "azurerm_log_analytics_workspace" "workspace" {
  count = "${var.enable_log_analytics == 0 ? 0 : 1}"
  name = "${format("%s%s%s-Analytics", upper(var.environment_code), upper(var.deployment_code), upper(var.location_code))}"
  location = "${var.azure_log_analytics_location_override == "" ? var.azure_location : var.azure_log_analytics_location_override}"
  resource_group_name = "${azurerm_resource_group.operations.name}"
  sku = "PerNode"
  retention_in_days = 30
}

 resource "azurerm_automation_account" "automation" {
  count = "${var.enable_log_analytics == 0 ? 0 : 1}"
  name = "${format("%s%s%s-Automation", upper(var.environment_code), upper(var.deployment_code), upper(var.location_code))}"
  location = "${var.azure_log_analytics_location_override == "" ? var.azure_location : var.azure_log_analytics_location_override}"
  resource_group_name = "${azurerm_resource_group.operations.name}"
  sku {
    name = "Basic"
  }
} 

resource "azurerm_log_analytics_solution" "update_management" {
  count = "${var.enable_log_analytics == 0 ? 0 : 1}"
  solution_name         = "Updates"
  location              = "${var.azure_log_analytics_location_override == "" ? var.azure_location : var.azure_log_analytics_location_override}"
  resource_group_name   = "${azurerm_resource_group.operations.name}"
  workspace_resource_id = "${azurerm_log_analytics_workspace.workspace.id}"
  workspace_name        = "${azurerm_log_analytics_workspace.workspace.name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Updates"
  }
}