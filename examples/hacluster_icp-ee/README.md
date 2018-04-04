# Terraform ICP VMware HA

This Terraform example configurations uses the [VMware vSphere provider](https://www.terraform.io/docs/providers/vsphere/index.html) to provision virtual machines on VMware
and [TerraForm Module ICP Deploy](https://github.com/ibm-cloud-architecture/terraform-module-icp-deploy) to prepare VMs and deploy [IBM Cloud Private](https://www.ibm.com/cloud-computing/products/ibm-cloud-private/) on them.

This template provisions an HA cluster with ICP 2.1.0.2 enterprise edition.


### Pre-requisites

* Working copy of [Terraform](https://www.terraform.io/intro/getting-started/install.html)
* The example assumes the VMs are provisioned from a template that has ssh keys loaded in /root/.ssh/authorized_keys
   After VM creation terraform will SSH into the VM to prepare and start installation of ICP using the SSH key provided
   If your VM template uses a different user from root, update the [`ssh_user` section in variables.tf](variables.tf#L154)
* The template is tested on vm templates based on Ubuntu 16.04

### VM Template image preparation

1. Create a VM image (RHEL or Ubuntu 16.04).
   * Ensure that the template has two virtual disks, `/dev/sda` and `/dev/sdb`.  The first disk must have at least 30GB free in the `/tmp` directory during installation.  Install the operating system onto the first disk.  The second disk will hold the local docker images and does not need to contain any filesystems.  Size it according to the predicted workload; but it may be expanded after the cluster is running.

1. Install Docker for the OS.  See the [documentation](https://www.ibm.com/support/knowledgecenter/en/SSBS6K_2.1.0.2/supported_system_config/supported_docker.html) for supported versions of Docker.

1. Configure Docker to use the `devicemapper` driver in the template.  See the [docker documentation](https://docs.docker.com/storage/storagedriver/device-mapper-driver/#configure-direct-lvm-mode-for-production) on how to do this.

   Here is a sample config file in `/etc/docker/daemon.json` where docker creates a thinpool on the `/dev/sdb` device:

    ```json
    {
      "storage-driver": "devicemapper",
      "storage-opts": [
        "dm.directlvm_device=/dev/sdb",
        "dm.thinp_percent=95",
        "dm.thinp_metapercent=1",
        "dm.thinp_autoextend_threshold=80",
        "dm.thinp_autoextend_percent=20",
        "dm.directlvm_device_force=false"
      ]
    }
   ```

   Restart docker and execute the following to ensure the `docker` volume group and the `thinpool` logical volume is created:

   ```bash
   sudo lvs
   ```

1. Install any other needed packages:
   1. Shared storage clients, e.g. if the shared storage is NFS for the registry and audit directories, install NFS clients.
   1. Install VMware Tools or `open-vm-tools`

1. Pre-load the docker images from the ICP package you wish to install.

   ```bash
   tar xf ibm-cloud-private-x86_64-2.1.0.2.tar.gz -O | sudo docker load
   ```

1. Shutdown the VM Convert to a template, make note the name of the template.

### Using the Terraform templates

1. git clone or download the templates

1. Create a `terraform.tfvars` file to reflect your environment.  Please see [variables.tf](variables.tf) for variable names and descriptions.  Here are some important ones:

| name | required                        | value        |
|----------------|------------|--------------|
| vsphere_server   | yes          | IP or hostname of vSphere server |
| vsphere_user   | yes          | Username for vSphere server |
| vsphere_password     | yes          | Password for vSphere user     |
| allow_unverified_ssl   | yes           | Ignore SSL certificate verification when connecting to vSphere |
| vsphere_datacenter | yes         | Name of the vSphere datacenter to deploy VMs to |
| cluster | yes         | Name of the vSphere cluster to deploy VMs to (must be under the vSohere datacenter) |
| resource_pool | yes         | Path of the Resource Pool to deploy VMs to (must be under the vSohere cluster), will be in the format like `<DC>/Resources/path/to/target` |
| network_label | yes         | Network label to place all VMs on |
| datastore | yes         | Name of the datastore to place all disk images in |
| folder | yes         | Name of the VM folder to place all created VMs in |
| template | yes         | Name of the VM template to use to create all VM images |
| staticipblock | no           | Subnet to place all VMs in, in CIDR notation.  Ensure that the subnet has enough useable address for all created VMs.  For example, 192.168.0.0/24 will contain 256 addresses.   Leave blank to retrieve from DHCP. |
| gateway | no           | default gateway to configure for all VMs.  Leave blank to retrieve from DHCP. |
| netmask | no           | Number of bits, in CIDR notation, of the subnet netmask  (e.g. 16).  Leave blank to retrieve from DHCP. |
| dns_servers | no | List of DNS servers to configure in the VMs.  By default, uses Google public DNS (`8.8.8.8` and `8.8.4.4`).  Set to blank to retrieve from DHCP. |
| proxy_vip | yes | Virtual IP address for the Proxy Nodes. |
| proxy_vip_iface | no | Network interface to use for the Proxy Node virtual IP.  `eth0` by default. |
| cluster_vip | yes | Virtual IP address for the Master node console. |
| cluster_vip_iface | no | Network Interface to use for the Master node console.  `eth0` by default. |
| icp_inception_image | no | Name of the `icp-inception` image to use.  Uses `ibmcom/icp-inception:2.1.0.2-ee` by default. |
|registry_mount_src | yes | Source of the shared storage for the registry directory `/var/lib/registry` |
| registry_mount_type | no | Type of mountpoint for the registry shared storage directory.  `nfs` by default. |
| registry_mount_options | no | Mount options to pass to the registry mountpoint.  `defaults` by default. |
| audit_mount_src | yes | Source of the shared storage for the audit directory `/var/lib/icp/audit` |
| audit_mount_type | no | Type of mountpoint for the audit shared storage directory.  `nfs` by default. |
| audit_mount_options | no | Mount options to pass to the audit mountpoint.  `defaults` by default. |


1. Run `terraform init` to download depenencies (modules and plugins)

1. Run `terraform plan` to investigate deployment plan

1. Run `terraform apply` to start deployment
