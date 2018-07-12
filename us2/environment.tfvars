subscription_id = "e9d43006-8dc3-41d6-9506-fdae2050b490"

environment_code = "s"

deployment_code = "us2"

location_code = "va1"

azure_location = "USGov Texas"

azure_network_octets = "10.8"

name_servers = [] # Array of DNS servers if you have 1:N of them. Ex ["8.8.8.8","16.16.16.16"] or leave blank to use Azure Default DNS.

platform_fault_domain_count = "2"

enable_vpn_scaffolding = 0

enable_log_analytics = 0

enable_vm_diagnostics = 0

instance_counts = {
  "lhtp" = 2
  "wbox" = 0
}

instance_sizes = {
  "lhtp" = "Standard_D16s_v3"
  "wbox" = "Standard_DS1_v3"
}

os_disk_sizes = {
  "lhtp" = "32"
  "wbox" = "5"
}

data_disk_sizes = {
  "lhtp" = "2"
}

data_disk_counts = {
  "lhtp" = 0
  "wbox" = 0
}

storage_type = {}
