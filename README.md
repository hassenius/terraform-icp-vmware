# Terraform ICP VMware

This Terraform example configurations uses the [VMware vSphere provider](https://www.terraform.io/docs/providers/vsphere/index.html) to provision virtual machines on VMware
and [TerraForm Module ICP Deploy](https://github.com/ibm-cloud-architecture/terraform-module-icp-deploy) to prepare VMs and deploy [IBM Cloud Private](https://www.ibm.com/cloud-computing/products/ibm-cloud-private/) on them.


### Pre-requisits

* Working copy of [Terraform](https://www.terraform.io/intro/getting-started/install.html)
* The example assumes the VMs are provisioned from a template that has ssh keys loaded in /root/.ssh/authorized_keys
   After VM creation terraform will SSH into the VM to prepare and start installation of ICP using the SSH key provided
* The recipe is tested on templates based on Ubuntu 16.04

### Using the recipes

1. git clone or download the recipe 
1. Update the [variables.tf](variables.tf) file to reflect your environment
1. Run `terraform init` to download depenencies (modules and plugins)
1. Run `terraform plan` to investigate deployment plan
1. Run `terraform apply` to start deployment


### Known limitations
1. As of VMware vSphere provider 0.4.2 there is a bug which prevents _vm folders_ working properly. 
   For now we create a VM folder, but the VMs will not be provisioned inside the folder. They can be moved there manually in vSphere until this bug is resolved.

