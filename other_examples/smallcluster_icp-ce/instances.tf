##################################
# Configure the VMware vSphere Provider
##################################
provider "vsphere" {
  version        = "~> 1.1"
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"
  vsphere_server = "${var.vsphere_server}"

  # if you have a self-signed cert
  allow_unverified_ssl = "${var.allow_unverified_ssl}"
  
}

##################################
#### Collect resource IDs
##################################
data "vsphere_datacenter" "dc" {
  name = "${var.vsphere_datacenter}"
}

data "vsphere_datastore" "datastore" {
  name          = "${var.datastore}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_resource_pool" "pool" {
  name          = "${var.resource_pool}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "${var.network_label}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "${var.template}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

# Create a folder
resource "vsphere_folder" "icpenv" {
  path = "${var.folder}"
  type = "vm"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

##################################
#### Create the Master VM
##################################
resource "vsphere_virtual_machine" "icpmaster" {
  depends_on = ["vsphere_folder.icpenv"]
  folder     = "${vsphere_folder.icpenv.path}"
  
  #####  
  # VM Specifications
  ####
  count            = "${var.master["nodes"]}" 
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  
  name      = "${format("${lower(var.instance_name)}-master%01d", count.index + 1) }"
  num_cpus  = "${var.master["vcpu"]}"
  memory    = "${var.master["memory"]}"
  
  ####
  # Disk specifications
  ####
  datastore_id  = "${data.vsphere_datastore.datastore.id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"

  disk {
    label             = "${format("${lower(var.instance_name)}-master%01d.vmdk", count.index + 1) }"
    size             = "${var.master["disk_size"]        != "" ? var.master["disk_size"]        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${var.master["eagerly_scrub"]    != "" ? var.master["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.master["thin_provisioned"] != "" ? var.master["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.master["keep_disk_on_remove"]}"
  }

  ####
  # Network specifications
  ####
  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }
  
  ####
  # VM Customizations
  ####
  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
    
    customize {
      linux_options {
        host_name = "${format("${lower(var.instance_name)}-master%01d", count.index + 1) }"
        domain    = "${var.domain != "" ? var.domain : format("%s.local", var.instance_name)}"
      }
      network_interface {
        #ipv4_address  = "${var.master["start_iprange"]}"
        #ipv4_netmask  = "${var.netmask}"
      }
      
      #ipv4_gateway    = "${var.gateway}"
      #dns_server_list = "${var.dns_servers}"
    }
  }
}


##################################
### Create the Proxy VM
##################################
resource "vsphere_virtual_machine" "icpproxy" {
  depends_on = ["vsphere_folder.icpenv"]
  folder     = "${vsphere_folder.icpenv.path}"
  
  #####  
  # VM Specifications
  ####
  count            = "${var.proxy["nodes"]}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  
  name     = "${format("${lower(var.instance_name)}-proxy%01d", count.index + 1) }"
  num_cpus = "${var.proxy["vcpu"]}"
  memory   = "${var.proxy["memory"]}"
  
  
  ####
  # Disk specifications
  ####
  datastore_id  = "${data.vsphere_datastore.datastore.id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"

  disk {
    label             = "${format("${lower(var.instance_name)}-proxy%01d.vmdk", count.index + 1) }"
    size             = "${var.proxy["disk_size"]        != "" ? var.proxy["disk_size"]        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${var.proxy["eagerly_scrub"]    != "" ? var.proxy["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.proxy["thin_provisioned"] != "" ? var.proxy["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.proxy["keep_disk_on_remove"]}"
  }


  ####
  # Network specifications
  ####
  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }
  
    
  ####
  # VM Customizations
  ####
  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
    
    customize {
      linux_options {
        host_name = "${format("${lower(var.instance_name)}-proxy%01d", count.index + 1) }"
        domain    = "${var.domain != "" ? var.domain : format("%s.local", var.instance_name)}"
      }
      network_interface { }
      dns_server_list = "${var.dns_servers}"
    }
  }
}

##################################
### Create the Worker VMs
##################################
resource "vsphere_virtual_machine" "icpworker" {
  depends_on = ["vsphere_folder.icpenv"]
  folder     = "${vsphere_folder.icpenv.path}"


  #####  
  # VM Specifications
  ####  
  count            = "${var.worker["nodes"]}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  
  name     = "${format("${lower(var.instance_name)}-worker%01d", count.index + 1) }"
  num_cpus = "${var.worker["vcpu"]}"
  memory   = "${var.worker["memory"]}"
  
  
  #####  
  # Disk Specifications
  ####
  datastore_id  = "${data.vsphere_datastore.datastore.id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"

  disk {
    label             = "${format("${lower(var.instance_name)}-worker%01d.vmdk", count.index + 1) }"
    size             = "${var.worker["disk_size"]        != "" ? var.worker["disk_size"]        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${var.worker["eagerly_scrub"]    != "" ? var.worker["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.worker["thin_provisioned"] != "" ? var.worker["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.worker["keep_disk_on_remove"]}"
  }

  
  ####
  # Network specifications
  ####
  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }
  

  #####  
  # VM Customizations
  ####
  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
    
    customize {
      linux_options {
        host_name = "${format("${lower(var.instance_name)}-worker%01d", count.index + 1) }"
        domain    = "${var.domain != "" ? var.domain : format("%s.local", var.instance_name)}"
      }
      network_interface { }

      dns_server_list = "${var.dns_servers}"
    }
  }
}


##################################
### Deploy ICP to cluster
##################################
module "icpprovision" {
    source = "github.com/ibm-cloud-architecture/terraform-module-icp-deploy.git?ref=2.3.3"

    # Provide IP addresses for master, proxy and workers
    icp-master = ["${vsphere_virtual_machine.icpmaster.*.default_ip_address}"]
    icp-proxy = ["${vsphere_virtual_machine.icpproxy.*.default_ip_address}"]
    icp-worker = ["${vsphere_virtual_machine.icpworker.*.default_ip_address}"]
    
    # Provide desired ICP version to provision
    icp-version = "${var.icp_version}"


    /* Workaround for terraform issue #10857
     When this is fixed, we can work this out automatically */
    cluster_size  = "${var.master["nodes"] + var.worker["nodes"] + var.proxy["nodes"]}"

    ###################################################################################################################################
    ## You can feed in arbitrary configuration items in the icp_configuration map.
    ## Available configuration items available from https://www.ibm.com/support/knowledgecenter/SSBS6K_2.1.0/installing/config_yaml.html
    icp_configuration = {
      "network_cidr"              = "192.168.0.0/16"
      "service_cluster_ip_range"  = "10.10.10.0/24"
     
      "default_admin_password"    = "${var.icppassword}"
    }

    # We will let terraform generate a new ssh keypair 
    # for boot master to communicate with worker and proxy nodes
    # during ICP deployment
    generate_key = true
    
    # SSH user and key for terraform to connect to newly created VMs
    # ssh_key is the private key corresponding to the public assumed to be included in the template
    ssh_user  = "${var.ssh_user}"
    ssh_key_file   = "${var.ssh_keyfile}"
    ssh_agent = false
} 
