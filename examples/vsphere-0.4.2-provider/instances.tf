# Configure the VMware vSphere Provider
provider "vsphere" {
  version        = "0.4.2"
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"
  vsphere_server = "${var.vsphere_server}"

  # if you have a self-signed cert
  allow_unverified_ssl = "${var.allow_unverified_ssl}"
}

data "vsphere_datacenter" "dc" {
  name = "${var.vsphere_datacenter}"
}


# Create a folder
resource "vsphere_folder" "icpenv" {
  path = "${var.folder}"
  type = "vm"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_virtual_machine" "icpmaster" {
  depends_on = ["vsphere_folder.icpenv"]
  count  = "${var.master["nodes"]}" 
  name   = "${format("${lower(var.instance_name)}-master%01d", count.index + 1) }"
  vcpu   = "${var.master["vcpu"]}"
  memory = "${var.master["memory"]}"
  
  ##Currently a bug with folders in vsphere 0.4 provider 
  ## Leave unset until fixed
  #folder = "${vsphere_folder.icpenv.path}"
  
  cluster       = "${var.cluster}"
  resource_pool = "${var.resource_pool}"

  network_interface {
    label = "${ var.network_label }"
  }

  disk {
    datastore = "${var.datastore}"
    template  = "${var.template}"
    type      = "${var.master["disk_type"]}"
    keep_on_remove = "${var.master["keep_disk_on_remove"]}"
  }
}

resource "vsphere_virtual_machine" "icpproxy" {
  depends_on = ["vsphere_folder.icpenv"]
  count       = "${var.proxy["nodes"]}"
  name   = "${format("${lower(var.instance_name)}-proxy%01d", count.index + 1) }"
  vcpu   = "${var.proxy["vcpu"]}"
  memory = "${var.proxy["memory"]}"
  
  ##Currently a bug with folders in vsphere 0.4 provider 
  ## Leave unset until fixed
  #folder = "${vsphere_folder.icpenv.path}"

  cluster       = "${var.cluster}"
  resource_pool = "${var.resource_pool}"

  network_interface {
    label = "${ var.network_label }"
  }

  disk {
    datastore = "${var.datastore}"
    template  = "${var.template}"
    type      = "${var.proxy["disk_type"]}"  }
}

resource "vsphere_virtual_machine" "icpworker" {
  depends_on = ["vsphere_folder.icpenv"]
  count       = "${var.worker["nodes"]}"
  name   = "${format("${lower(var.instance_name)}-worker%01d", count.index + 1) }"
  vcpu   = "${var.worker["vcpu"]}"
  memory = "${var.worker["memory"]}"
  
  ##Currently a bug with folders in vsphere 0.4 provider 
  ## Leave unset until fixed
  #folder = "${vsphere_folder.icpenv.path}"

  cluster       = "${var.cluster}"
  resource_pool = "${var.resource_pool}"

  network_interface {
    label = "${ var.network_label }"
  }

  disk {
    datastore = "${var.datastore}"
    template  = "${var.template}"
    type      = "${var.worker["disk_type"]}"
  }
}


module "icpprovision" {
    source = "github.com/ibm-cloud-architecture/terraform-module-icp-deploy"
    
    icp-master = ["${vsphere_virtual_machine.icpmaster.*.network_interface.0.ipv4_address}"]
    icp-proxy = ["${vsphere_virtual_machine.icpproxy.*.network_interface.0.ipv4_address}"]
    icp-worker = ["${vsphere_virtual_machine.icpworker.*.network_interface.0.ipv4_address}"]
    
    icp-version = "ibmcom/icp-inception:2.1.0"

    /* Workaround for terraform issue #10857
     When this is fixed, we can work this out autmatically */
    cluster_size  = "${var.master["nodes"] + var.worker["nodes"] + var.proxy["nodes"]}"

    # You can feed in arbitrary configuration items in the icp_configuration map.
    # Available configuration items availble from https://www.ibm.com/support/knowledgecenter/SSBS6K_2.1.0/installing/config_yaml.html
    icp_configuration = {
      "network_cidr"              = "192.168.0.0/16"
      "service_cluster_ip_range"  = "172.30.0.1/24"
      "default_admin_password"    = "${var.icppassword}"
    }

    # We will let terraform generate a new ssh keypair 
    # for boot master to communicate with worker and proxy nodes
    # during ICP deployment
    generate_key = true
    
    # SSH user and key for terraform to connect to newly created VMs
    # ssh_key is the private key corresponding to the public assumed to be included in the template
    ssh_user  = "root"
    ssh_key   = "~/.ssh/id_rsa"
    
} 

