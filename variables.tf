##### vSphere Access Credentials ######

variable "vsphere_user" { default = "___INSERT YOUR OWN____" }
variable "vsphere_password" { default = "___INSERT YOUR OWN____" }
variable "vsphere_server" { 
  description = "IP Address or FQDN of vsphere server"
  default = "___INSERT YOUR OWN____" 
}
variable "allow_unverified_ssl" { 
  description = "If the vsphere api server uses self signed certificates for https traffic, set to true"
  default = "true" 
}

##### vSphere deployment specifications ######
variable "vsphere_datacenter" { default = "___INSERT YOUR OWN____" }
variable "cluster" { default = "___INSERT YOUR OWN____"}
variable "resource_pool" { 
  description = "Full path of resource pool. i.e. <cluster>/Resources/<pool name>"
  default = "___INSERT YOUR OWN____" 
}
variable "network_label" { default = "___INSERT YOUR OWN____" }
variable "datastore" { default = "___INSERT YOUR OWN____" } 
variable "template" { 
  description = "VM template to provision servers from"
  default = "___INSERT YOUR OWN____" 
}
variable "folder" { 
  description = "VM Folder name. Later versions will provision all VMs to this folder"
  default = "ibmcloudprivate"
}

# Name of the ICP installation, will be used as basename for VMs
variable "instance_name" { default = "myicp" }

##### ICP Instance details ######
variable "master" {
  type = "map"
  
  default = {
    nodes       = "1"
    vcpu        = "2"
    memory      = "8192"
    disk_type   = "thin" # 'eager_zeroed', 'lazy', or 'thin' are supported options.
    keep_disk_on_remove = "false" # Set to 'true' to not delete a disk on removal.
  }
}

variable "proxy" {
  type = "map"
  
  default = {
    nodes       = "1"
    vcpu        = "1"
    memory      = "2048"
    disk_type   = "thin" # 'eager_zeroed', 'lazy', or 'thin' are supported options.

  }
}

variable "worker" {
  type = "map"
  
  default = {
    nodes       = "3"
    vcpu        = "2"
    memory      = "4096"
    disk_type   = "thin" # 'eager_zeroed', 'lazy', or 'thin' are supported options.
  }
}

# Username and password for the initial admin user
variable "icppassword" { default = "admin" }
