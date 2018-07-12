####################################
#### vSphere Access Credentials ####
####################################
variable "vsphere_server" { 
  description = "vsphere server to connect to"
  default = "___INSERT YOUR OWN____" 
}

variable "vsphere_user" {
  description = "Username to authenticate against vsphere"
  default     = "___INSERT YOUR OWN____"
}

variable "vsphere_password" { 
  description = "Password to authenticate against vsphere"
  default = "___INSERT YOUR OWN____" 
}

variable "allow_unverified_ssl" { 
  description = "Allows terraform vsphere provider to communicate with vsphere servers with self signed certificates"
  default = "true" 
} 



##############################################
##### vSphere deployment specifications ######
##############################################

variable "vsphere_datacenter" { 
  description = "Name of the vsphere datacenter to deploy to"
  default     = "___INSERT YOUR OWN____" 
}

variable "vsphere_cluster" { 
  description = "Name of vsphere cluster to deploy to"
  default     = "___INSERT YOUR OWN____"
}

variable "vsphere_resource_pool" { 
  description = "Path of resource pool to deploy to. i.e. <DC>/Resources/<pool name>"
  default     = "___INSERT YOUR OWN____" 
}

variable "network_label" { 
  description = "Name or label of network to provision VMs on. All VMs will be provisioned on the same network"
  default     = "___INSERT YOUR OWN____" 
}

variable "datastore" { 
  description = "Name of datastore to use for the VMs"
  default     = "___INSERT YOUR OWN____" 
} 

## Note 
# Because of https://github.com/terraform-providers/terraform-provider-vsphere/issues/271 templates must be converted to VMs on ESX 5.5 (and possibly other)
variable "template" { 
  description = "Name of template or VM to clone for the VM creations. Tested on Ubuntu 16.04 LTS"
  default     = "___INSERT YOUR OWN____" 
}

variable "folder" { 
  description = "Name of VM Folder to provision the new VMs in. The folder will be created"
  default     = "ibmcloudprivate"
}

variable "instance_name" { 
  description = "Name of the ICP installation, will be used as basename for VMs"
  default     = "icptest"
}

variable  "domain"  { 
  description = "Specify domain name to be used for linux customization on the VMs, or leave blank to use <instance_name>.icp"
  default     = "" 
}

variable  "gateway" { 
  description = "Default gateway for the newly provisioned VMs. Leave blank to use DHCP"
  default     = "" 
}

variable "netmask" {
  description = "Netmask in CIDR notation when using static IPs. For example 16 or 24. Leave blank for DHCP"
  default     = ""
}

variable  "dns_servers" { 
  description = "DNS Servers to configure on VMs"
  default = ["8.8.8.8", "8.8.4.4"]
}

#################################
##### ICP Instance details ######
#################################
variable "master" {
  type = "map"
  
  default = {
    nodes  = "1"
    vcpu   = "4"
    memory = "16384"

    disk_size           = "100"   # Specify size or leave empty to use same size as template.
    thin_provisioned    = ""      # True or false. Whether to use thin provisioning on the disk. Leave blank to use same as template
    eagerly_scrub       = ""      # True or false. If set to true disk space is zeroed out on VM creation. Leave blank to use same as template
    keep_disk_on_remove = "false" # Set to 'true' to not delete a disk on removal.

    start_iprange = ""            # Leave blank for DHCP, else masters will be allocated range starting from this address
  }
}

variable "proxy" {
  type = "map"
  
  default = {
    nodes   = "1"
    vcpu    = "1"
    memory  = "2048"

    disk_size           = ""      # Specify size or leave empty to use same size as template.
    thin_provisioned    = ""      # True or false. Whether to use thin provisioning on the disk. Leave blank to use same as template
    eagerly_scrub       = ""      # True or false. If set to true disk space is zeroed out on VM creation. Leave blank to use same as template
    keep_disk_on_remove = "false" # Set to 'true' to not delete a disk on removal.

    start_iprange = ""            # Leave blank for DHCP, else proxies will be allocated range starting from this address
  }
}

variable "worker" {
  type = "map"
  
  default = {
    nodes       = "3"
    vcpu        = "2"
    memory      = "4096"

    disk_size           = ""      # Specify size or leave empty to use same size as template.
    thin_provisioned    = ""      # True or false. Whether to use thin provisioning on the disk. Leave blank to use same as template
    eagerly_scrub       = ""      # True or false. If set to true disk space is zeroed out on VM creation. Leave blank to use same as template
    keep_disk_on_remove = "false" # Set to 'true' to not delete a disk on removal.

    start_iprange = ""            # Leave blank for DHCP, else workers will be allocated range starting from this address
  }
}

variable "icp_version" {
  description = "Supports the format 'org/repo:version', as well as just '2.1.0.X' version. 'ibmcom/icp-inception:2.1.0.3' and '2.1.0.3' provide the same outcome."
  default     = "2.1.0.3"
}

variable "icppassword" { 
  description = "Password for the initial admin user in ICP"
  default     = "MySecretPassw0rd" 
}

variable "ssh_user" {
  description = "Username which terraform will use to connect to newly created VMs during provisioning"
  default     = "root"
}

variable "ssh_keyfile" {
  description = "Location of private ssh key to connect to newly created VMs during provisioning"
  default     = "~/.ssh/id_rsa"
}
