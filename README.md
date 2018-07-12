A set of Terraform scripts to create an multi-vm environment in Azure.

Security
========

#### Azure
Set the Azure cloud environment  to the appropriate value to the deployment.
Use `az cloud set --name ` and either AzureCloud for commercial or AzureUSGovernment for US government
e.g.
```az cloud set --name AzureCloud```

NB: You can list which cloud environment is currently selected with:
```az cloud list -o table```

With the cloud environment set use `az login` to authenticate with your own credentials and MFA before running Terraform. 

Global resources:
=====

* network.tf - defines the virtual network, subnets and local DNS server addresses
* provider.tf - specifies that the AzureRM provider is used, with creds held in secrets.tfvars
* resource_groups.tf - defines the high level resource groups that all resources must be in
* storage_accounts.tf - defines application-tier storage accounts and containers
* variables.tf - defines private IP ranges and other global defaults


Type-specific resources <environment>:

* lhtp.tf
* wbox.tf
* _...etc..._

Examples:
=====

* Plan: terraform plan -var-file=us2/environment.tfvars -var-file=us2/secrets.tfvars -state us2/terraform.tfstate
* Apply: terraform apply -var-file=us2/environment.tfvars -var-file=us2/secrets.tfvars -state us2/terraform.tfstate -parallelism=400  
* Delete: terraform destroy -var-file=us2/environment.tfvars -var-file=us2/secrets.tfvars -state us2/terraform.tfstate
* NOTE:  The use of parallelism (see Apply example) dramatically affects deployment speed.  By default terraform will utilize 10 parallel operations.  For large deployments this will signifigantly slow down deployment time. 