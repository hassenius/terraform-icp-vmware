#################################
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
  name          = "${var.vsphere_cluster}/Resources/${var.vsphere_resource_pool}"
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
  count = "${var.folder != "" ? 1 : 0}"
  path = "${var.folder}"
  type = "vm"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}


locals  {
  folder_path = "${var.folder != "" ?
        element(concat(vsphere_folder.icpenv.*.path, list("")), 0)
        : ""}"
}


##################################
#### Create the Master VM
##################################
resource "vsphere_virtual_machine" "icpmaster" {
  #depends_on = ["vsphere_folder.icpenv"]
  folder     = "${local.folder_path}"

  #####
  # VM Specifications
  ####
  count            = "${var.master["nodes"]}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"

  name      = "${format("${lower(var.instance_name)}-master%02d", count.index + 1) }"
  num_cpus  = "${var.master["vcpu"]}"
  memory    = "${var.master["memory"]}"

  scsi_controller_count = 1
  scsi_type = "lsilogic-sas"

  ####
  # Disk specifications
  ####
  datastore_id  = "${data.vsphere_datastore.datastore.id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"

  disk {
    label            = "${format("${lower(var.instance_name)}-master%02d.vmdk", count.index + 1) }"
    size             = "${var.master["disk_size"]        != "" ? var.master["disk_size"]        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${var.master["eagerly_scrub"]    != "" ? var.master["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.master["thin_provisioned"] != "" ? var.master["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.master["keep_disk_on_remove"]}"
    unit_number      = 0
  }

  disk {
    label            = "${format("${lower(var.instance_name)}-master%02d_docker.vmdk", count.index + 1) }"
    size             = "${var.master["docker_disk_size"]}"
    eagerly_scrub    = "${var.master["eagerly_scrub"]    != "" ? var.master["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.master["thin_provisioned"] != "" ? var.master["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.master["keep_disk_on_remove"]}"
    unit_number      = 1
  }


  disk {
    label            = "${format("${lower(var.instance_name)}-master%02d_db.vmdk", count.index + 1) }"
    size             = "${var.master["datastore_disk_size"]}"
    eagerly_scrub    = "${var.master["eagerly_scrub"]    != "" ? var.master["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.master["thin_provisioned"] != "" ? var.master["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.master["keep_disk_on_remove"]}"
    unit_number      = 2
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
        host_name = "${format("${lower(var.instance_name)}-master%02d", count.index + 1) }"
        domain    = "${var.domain != "" ? var.domain : format("%s.local", var.instance_name)}"
      }
      network_interface {
        ipv4_address  = "${var.staticipblock != "0.0.0.0/0" ? cidrhost(var.staticipblock, 1 + var.staticipblock_offset + count.index) : ""}"
        ipv4_netmask  = "${var.netmask}"
      }

      ipv4_gateway    = "${var.gateway}"
      dns_server_list = "${var.dns_servers}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/tmp/terraform_scripts"

    connection {
      user          = "${var.ssh_user}"
      private_key   = "${file(var.ssh_keyfile)}"
    }
  }

  provisioner "remote-exec" {
    connection {
      user          = "${var.ssh_user}"
      private_key   = "${file(var.ssh_keyfile)}"
    }

    inline = [
      "sudo chmod u+x /tmp/terraform_scripts/*.sh",
      "/tmp/terraform_scripts/install-docker.sh -d /dev/sdb -p ${var.docker_package_location}",
      "/tmp/terraform_scripts/create-part.sh -p /opt/ibm/cfc -d /dev/sdc",
      "sudo mkdir -p /var/lib/registry",
      "sudo mkdir -p /var/lib/icp/audit",
      "${var.registry_mount_src == "" ?
        "echo na"
        :
        "echo '${var.registry_mount_src} /var/lib/registry   ${var.registry_mount_type}  ${var.registry_mount_options}   0 0' | sudo tee -a /etc/fstab"
      }",
      "${var.audit_mount_src == "" ?
        "echo na"
        :
        "echo '${var.audit_mount_src} /var/lib/icp/audit   ${var.audit_mount_type}  ${var.audit_mount_options}  0 0' | sudo tee -a /etc/fstab"}",
      "sudo mount -a"
    ]
  }
}

##################################
### Create the Proxy VM
##################################
resource "vsphere_virtual_machine" "icpproxy" {
  #depends_on = ["vsphere_folder.icpenv"]
  folder     = "${local.folder_path}"

  #####
  # VM Specifications
  ####
  count            = "${var.proxy["nodes"]}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"

  name     = "${format("${lower(var.instance_name)}-proxy%02d", count.index + 1) }"
  num_cpus = "${var.proxy["vcpu"]}"
  memory   = "${var.proxy["memory"]}"


  ####
  # Disk specifications
  ####
  datastore_id  = "${data.vsphere_datastore.datastore.id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"

  disk {
    label            = "${format("${lower(var.instance_name)}-proxy%02d.vmdk", count.index + 1) }"
    size             = "${var.proxy["disk_size"]        != "" ? var.proxy["disk_size"]        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${var.proxy["eagerly_scrub"]    != "" ? var.proxy["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.proxy["thin_provisioned"] != "" ? var.proxy["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.proxy["keep_disk_on_remove"]}"
  }

  disk {
    label            = "${format("${lower(var.instance_name)}-proxy%02d_docker.vmdk", count.index + 1) }"
    size             = "${var.proxy["docker_disk_size"]}"
    eagerly_scrub    = "${var.proxy["eagerly_scrub"]    != "" ? var.proxy["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.proxy["thin_provisioned"] != "" ? var.proxy["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.proxy["keep_disk_on_remove"]}"
    unit_number      = 1
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
        host_name = "${format("${lower(var.instance_name)}-proxy%02d", count.index + 1) }"
        domain    = "${var.domain != "" ? var.domain : format("%s.local", var.instance_name)}"
      }
      network_interface {
        ipv4_address  = "${var.staticipblock != "0.0.0.0/0" ? cidrhost(var.staticipblock, 1 + var.staticipblock_offset + var.master["nodes"] + count.index) : ""}"
        ipv4_netmask  = "${var.netmask}"
      }

      ipv4_gateway    = "${var.gateway}"
      dns_server_list = "${var.dns_servers}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/tmp/terraform_scripts"

    connection {
      user          = "${var.ssh_user}"
      private_key   = "${file(var.ssh_keyfile)}"
    }
  }

  provisioner "remote-exec" {
    connection {
      user          = "${var.ssh_user}"
      private_key   = "${file(var.ssh_keyfile)}"
    }

    inline = [
      "sudo chmod u+x /tmp/terraform_scripts/*.sh",
      "/tmp/terraform_scripts/install-docker.sh -d /dev/sdb -p ${var.docker_package_location}"
    ]
  }
}

resource "vsphere_virtual_machine" "icpmanagement" {
  #depends_on = ["vsphere_folder.icpenv"]
  folder     = "${local.folder_path}"

  #####
  # VM Specifications
  ####
  count            = "${var.management["nodes"]}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"

  name      = "${format("${lower(var.instance_name)}-management%02d", count.index + 1) }"
  num_cpus  = "${var.management["vcpu"]}"
  memory    = "${var.management["memory"]}"

  ####
  # Disk specifications
  ####
  datastore_id  = "${data.vsphere_datastore.datastore.id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"

  disk {
    label            = "${format("${lower(var.instance_name)}-management%02d.vmdk", count.index + 1) }"
    size             = "${var.management["disk_size"]        != "" ? var.management["disk_size"]        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${var.management["eagerly_scrub"]    != "" ? var.management["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.management["thin_provisioned"] != "" ? var.management["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.management["keep_disk_on_remove"]}"
  }

  disk {
    label            = "${format("${lower(var.instance_name)}-management%02d_docker.vmdk", count.index + 1) }"
    size             = "${var.management["docker_disk_size"]}"
    eagerly_scrub    = "${var.management["eagerly_scrub"]    != "" ? var.management["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.management["thin_provisioned"] != "" ? var.management["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.management["keep_disk_on_remove"]}"
    unit_number      = 1
  }

  disk {
    label            = "${format("${lower(var.instance_name)}-management%02d_log.vmdk", count.index + 1) }"
    size             = "${var.management["log_disk_size"]}"
    eagerly_scrub    = "${var.management["eagerly_scrub"]    != "" ? var.management["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.management["thin_provisioned"] != "" ? var.management["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.management["keep_disk_on_remove"]}"
    unit_number      = 2
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
        host_name = "${format("${lower(var.instance_name)}-management%02d", count.index + 1) }"
        domain    = "${var.domain != "" ? var.domain : format("%s.local", var.instance_name)}"
      }
      network_interface {
        ipv4_address  = "${var.staticipblock != "0.0.0.0/0" ? cidrhost(var.staticipblock, 1 + var.staticipblock_offset + var.master["nodes"] + var.proxy["nodes"] + count.index) : ""}"
        ipv4_netmask  = "${var.netmask}"
      }
      ipv4_gateway    = "${var.gateway}"
      dns_server_list = "${var.dns_servers}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/tmp/terraform_scripts"

    connection {
      user          = "${var.ssh_user}"
      private_key   = "${file(var.ssh_keyfile)}"
    }
  }

  provisioner "remote-exec" {
    connection {
      user          = "${var.ssh_user}"
      private_key   = "${file(var.ssh_keyfile)}"
    }

    inline = [
      "sudo chmod u+x /tmp/terraform_scripts/*.sh",
      "/tmp/terraform_scripts/install-docker.sh -d /dev/sdb -p ${var.docker_package_location}",
      "/tmp/terraform_scripts/create-part.sh -p /opt/ibm/cfc -d /dev/sdc"
    ]
  }
}

resource "vsphere_virtual_machine" "icpva" {
  #depends_on = ["vsphere_folder.icpenv"]
  folder     = "${local.folder_path}"

  #####
  # VM Specifications
  ####
  count            = "${var.va["nodes"]}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"

  name      = "${format("${lower(var.instance_name)}-va%02d", count.index + 1) }"
  num_cpus  = "${var.va["vcpu"]}"
  memory    = "${var.va["memory"]}"

  ####
  # Disk specifications
  ####
  datastore_id      = "${data.vsphere_datastore.datastore.id}"
  guest_id          = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type         = "${data.vsphere_virtual_machine.template.scsi_type}"

  disk {
    label            = "${format("${lower(var.instance_name)}-va%02d.vmdk", count.index + 1) }"
    size             = "${var.va["disk_size"]        != "" ? var.va["disk_size"]        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${var.va["eagerly_scrub"]    != "" ? var.va["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.va["thin_provisioned"] != "" ? var.va["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.va["keep_disk_on_remove"]}"
  }

  disk {
    label            = "${format("${lower(var.instance_name)}-va%02d_docker.vmdk", count.index + 1) }"
    size             = "${var.va["docker_disk_size"]}"
    eagerly_scrub    = "${var.va["eagerly_scrub"]    != "" ? var.va["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.va["thin_provisioned"] != "" ? var.va["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.va["keep_disk_on_remove"]}"
    unit_number      = 1
  }

  disk {
    label            = "${format("${lower(var.instance_name)}-va%02d_es.vmdk", count.index + 1) }"
    size             = "${var.va["es_disk_size"]}"
    eagerly_scrub    = "${var.va["eagerly_scrub"]    != "" ? var.va["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.va["thin_provisioned"] != "" ? var.va["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.va["keep_disk_on_remove"]}"
    unit_number      = 2
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
        host_name = "${format("${lower(var.instance_name)}-va%02d", count.index + 1) }"
        domain    = "${var.domain != "" ? var.domain : format("%s.local", var.instance_name)}"
      }
      network_interface {
        ipv4_address  = "${var.staticipblock != "0.0.0.0/0" ? cidrhost(var.staticipblock, 1 + var.staticipblock_offset + var.master["nodes"] + var.proxy["nodes"] + var.management["nodes"] + count.index) : ""}"
        ipv4_netmask  = "${var.netmask}"
      }
      ipv4_gateway    = "${var.gateway}"
      dns_server_list = "${var.dns_servers}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/tmp/terraform_scripts"

    connection {
      user          = "${var.ssh_user}"
      private_key   = "${file(var.ssh_keyfile)}"
    }
  }

  provisioner "remote-exec" {
    connection {
      user          = "${var.ssh_user}"
      private_key   = "${file(var.ssh_keyfile)}"
    }

    inline = [
      "sudo chmod u+x /tmp/terraform_scripts/*.sh",
      "/tmp/terraform_scripts/install-docker.sh -d /dev/sdb -p ${var.docker_package_location}",
      "/tmp/terraform_scripts/create-part.sh -p /var/lib/icp -d /dev/sdc"
    ]
  }
}

##################################
### Create the Worker VMs
##################################
resource "vsphere_virtual_machine" "icpworker" {
  #depends_on = ["vsphere_folder.icpenv"]
  folder     = "${local.folder_path}"

  #####
  # VM Specifications
  ####
  count            = "${var.worker["nodes"]}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"

  name     = "${format("${lower(var.instance_name)}-worker%02d", count.index + 1) }"
  num_cpus = "${var.worker["vcpu"]}"
  memory   = "${var.worker["memory"]}"


  #####
  # Disk Specifications
  ####
  datastore_id  = "${data.vsphere_datastore.datastore.id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"

  disk {
    label            = "${format("${lower(var.instance_name)}-worker%02d.vmdk", count.index + 1) }"
    size             = "${var.worker["disk_size"]        != "" ? var.worker["disk_size"]        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${var.worker["eagerly_scrub"]    != "" ? var.worker["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.worker["thin_provisioned"] != "" ? var.worker["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.worker["keep_disk_on_remove"]}"
  }

  disk {
    label            = "${format("${lower(var.instance_name)}-worker%02d_docker.vmdk", count.index + 1) }"
    size             = "${var.worker["docker_disk_size"]}"
    eagerly_scrub    = "${var.worker["eagerly_scrub"]    != "" ? var.worker["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.worker["thin_provisioned"] != "" ? var.worker["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.worker["keep_disk_on_remove"]}"
    unit_number      = 1
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
        host_name = "${format("${lower(var.instance_name)}-worker%02d", count.index + 1) }"
        domain    = "${var.domain != "" ? var.domain : format("%s.local", var.instance_name)}"
      }

      network_interface {
        ipv4_address  = "${var.staticipblock != "0.0.0.0/0" ? cidrhost(var.staticipblock, 1 + var.staticipblock_offset + var.master["nodes"] + var.proxy["nodes"] + var.management["nodes"] + var.va["nodes"] + count.index) : ""}"
        ipv4_netmask  = "${var.netmask}"
      }

      ipv4_gateway    = "${var.gateway}"
      dns_server_list = "${var.dns_servers}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/tmp/terraform_scripts"

    connection {
      user          = "${var.ssh_user}"
      private_key   = "${file(var.ssh_keyfile)}"
    }
  }

  provisioner "remote-exec" {
    connection {
      user          = "${var.ssh_user}"
      private_key   = "${file(var.ssh_keyfile)}"
    }

    inline = [
      "sudo chmod u+x /tmp/terraform_scripts/*.sh",
      "/tmp/terraform_scripts/install-docker.sh -d /dev/sdb -p ${var.docker_package_location}"
    ]
  }
}
