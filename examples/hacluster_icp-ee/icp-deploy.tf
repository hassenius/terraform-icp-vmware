##################################
### Deploy ICP to cluster
##################################
module "icpprovision" {
    source = "github.com/ibm-cloud-architecture/terraform-module-icp-deploy.git?ref=2.1.0"

    # Provide IP addresses for master, proxy and workers
    icp-master = ["${vsphere_virtual_machine.icpmaster.*.default_ip_address}"]
    icp-proxy = ["${vsphere_virtual_machine.icpproxy.*.default_ip_address}"]
    icp-worker = ["${vsphere_virtual_machine.icpworker.*.default_ip_address}"]
    icp-management = ["${vsphere_virtual_machine.icpmanagement.*.default_ip_address}"]

    # Provide desired ICP version to provision
    icp-version = "${var.icp_inception_image}"

    parallell-image-pull = true

    /* Workaround for terraform issue #10857
     When this is fixed, we can work this out autmatically */
    cluster_size  = "${var.master["nodes"] + var.worker["nodes"] + var.proxy["nodes"] + var.management["nodes"]}"

    ###################################################################################################################################
    ## You can feed in arbitrary configuration items in the icp_configuration map.
    ## Available configuration items availble from https://www.ibm.com/support/knowledgecenter/SSBS6K_2.1.0/installing/config_yaml.html
    icp_config_file = "./icp-config.yaml"
    icp_configuration = {
      "network_cidr"                    = "192.168.0.0/16"
      "service_cluster_ip_range"        = "10.10.10.0/24"
      "cluster_access_ip"               = "${var.cluster_vip}"
      "proxy_access_ip"                 = "${var.proxy_vip}"
      "cluster_vip"                     = "${var.cluster_vip}"
      "proxy_vip"                       = "${var.proxy_vip}"
      "vip_iface"                       = "${var.cluster_vip_iface}"
      "proxy_vip_iface"                 = "${var.proxy_vip_iface}"
      "cluster_name"                    = "${var.instance_name}-cluster"
      "vip_manager"                     = "etcd"
      "calico_ip_autodetection_method"  = "first-found"

      "default_admin_password"          = "${var.icppassword}"
    }

    # We will let terraform generate a new ssh keypair
    # for boot master to communicate with worker and proxy nodes
    # during ICP deployment
    generate_key = true

    # SSH user and key for terraform to connect to newly created VMs
    # ssh_key is the private key corresponding to the public assumed to be included in the template
    ssh_user        = "${var.ssh_user}"
    ssh_key_base64  = "${base64encode(file(var.ssh_keyfile))}"
    ssh_agent       = false
}
