locals {
    image          = "${length(var.private_registry) > 1 ? "${var.private_registry}/${var.icp_inception_image}" : "${var.icp_inception_image}"}"
    icp_pub_key    = "${tls_private_key.ssh.public_key_openssh}"
    icp_priv_key   = "${tls_private_key.ssh.private_key_pem}"
    ssh_user       = "${var.ssh_user}"
    ssh_key_base64 = "${base64encode(tls_private_key.ssh.private_key_pem)}"

    # This is just to have a long list of disabled items to use in icp-deploy.tf
    disabled_list = "${list("disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled")}"
    disabled_management_services = "${zipmap(var.disabled_management_services, slice(local.disabled_list, 0, length(var.disabled_management_services)))}"
}

##################################
### Deploy ICP to cluster
##################################
module "icpprovision" {
    source = "github.com/ibm-cloud-architecture/terraform-module-icp-deploy.git?ref=2.3.4"

    # Provide IP addresses for master, proxy and workers
    boot-node = "${vsphere_virtual_machine.icpmaster.0.default_ip_address}"
    icp-host-groups = {
        master = ["${vsphere_virtual_machine.icpmaster.*.default_ip_address}"]
        proxy = ["${vsphere_virtual_machine.icpproxy.*.default_ip_address}"]
        worker = ["${vsphere_virtual_machine.icpworker.*.default_ip_address}"]
        management = ["${vsphere_virtual_machine.icpmanagement.*.default_ip_address}"]
        va = ["${vsphere_virtual_machine.icpva.*.default_ip_address}"]
    }

    # Provide desired ICP version to provision
    icp-version = "${length(var.registry_username) > 1 ?  "${var.registry_username}:${var.registry_password}@${local.image}" : "${local.image}"}"
    image_location = "${var.image_location}"

    parallell-image-pull = "${var.parallel_image_pull}"

    /* Workaround for terraform issue #10857
     When this is fixed, we can work this out autmatically */
    cluster_size  = "${var.master["nodes"] +
        var.worker["nodes"] +
        var.proxy["nodes"] +
        var.management["nodes"] +
        var.va["nodes"]}"

    ###################################################################################################################################
    ## You can feed in arbitrary configuration items in the icp_configuration map.
    ## Available configuration items availble from https://www.ibm.com/support/knowledgecenter/SSBS6K_2.1.0.3/installing/config_yaml.html
    icp_config_file = "./icp-config.yaml"
    icp_configuration = {
      "network_cidr"                    = "${var.network_cidr}"
      "service_cluster_ip_range"        = "${var.service_network_cidr}"
      "cluster_access_ip"               = "${var.cluster_vip}"
      "proxy_access_ip"                 = "${var.proxy_vip}"
      "cluster_vip"                     = "${var.cluster_vip}"
      "proxy_vip"                       = "${var.proxy_vip}"
      "vip_iface"                       = "${var.cluster_vip_iface}"
      "proxy_vip_iface"                 = "${var.proxy_vip_iface}"
      "cluster_lb_address"              = "${var.cluster_lb_address}"
      "proxy_lb_address"                = "${var.proxy_lb_address}"
      #"vip_manager"                     = "etcd"
      "cluster_name"                    = "${var.instance_name}-cluster"
      "calico_ip_autodetection_method"  = "first-found"
      "default_admin_password"          = "${var.icppassword}"
      # This is the list of disabled management services
      "management_services"             = "${local.disabled_management_services}"
      "private_registry_enabled"        = "${length(var.private_registry) > 1 ? "true" : "false"}"
      "private_registry_server"         = "${var.private_registry}"
      "image_repo"                      = "${length(var.private_registry) > 1 ? "${dirname(local.image)}" : ""}"
      "docker_username"                 = "${length(var.registry_username) > 1 ? "${var.registry_username}" : "'null'"}"
      "docker_password"                 = "${length(var.registry_password) > 1 ? "${var.registry_password}" : "'null'"}"
    }

    # We will let terraform generate a new ssh keypair
    # for boot master to communicate with worker and proxy nodes
    # during ICP deployment
    generate_key    = false
    icp_pub_key     = "${local.icp_pub_key}"
    icp_priv_key    = "${local.icp_priv_key}"

    # SSH user and key for terraform to connect to newly created VMs
    # ssh_key is the private key corresponding to the public assumed to be included in the template
    ssh_user        = "${local.ssh_user}"
    ssh_key_base64  = "${local.ssh_key_base64}"
    ssh_agent       = false
}
