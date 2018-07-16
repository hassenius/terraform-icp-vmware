
locals {
    registry_split = "${split("@", var.icp_inception_image)}"
    registry_creds = "${length(local.registry_split) > 1 ? "${element(local.registry_split, 0)}" : ""}"
    image          = "${length(local.registry_split) > 1 ? "${replace(var.icp_inception_image, "/.*@/", "")}" : "${var.icp_inception_image}" }"
}

##################################
### Deploy ICP to cluster
##################################
module "icpprovision" {
    source = "github.com/ibm-cloud-architecture/terraform-module-icp-deploy.git?ref=2.3.3"

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
    icp-version = "${var.icp_inception_image}"
    image_location = "${var.image_location}"

    parallell-image-pull = true

    /* Workaround for terraform issue #10857
     When this is fixed, we can work this out autmatically */
    cluster_size  = "${var.master["nodes"] +
        var.worker["nodes"] +
        var.proxy["nodes"] +
        var.management["nodes"] +
        var.va["nodes"]}"

    ###################################################################################################################################
    ## You can feed in arbitrary configuration items in the icp_configuration map.
    ## Available configuration items availble from https://www.ibm.com/support/knowledgecenter/SSBS6K_2.1.0/installing/config_yaml.html
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
      "disabled_management_services"    = [ "${var.va["nodes"] == 0 ? "va" : "" }" ]
      "image_repo"                      = "${dirname(local.image)}"
      "private_registry_enabled"        = "${local.registry_creds != "" ? "true" : "false" }"
      "private_registry_server"         = "${local.registry_creds != "" ? "${dirname(dirname(local.image))}" : "" }"
      "docker_username"                 = "${local.registry_creds != "" ? "${replace(local.registry_creds, "/:.*/", "")}" : "" }"
      "docker_password"                 = "${local.registry_creds != "" ? "${replace(local.registry_creds, "/.*:/", "")}" : "" }"
    }

        hooks = {
        "cluster-preconfig" = [
            "sudo apt-get update",
            "sudo apt-get -y install --only-upgrade docker-ce"
       ]
       }

    # We will let terraform generate a new ssh keypair
    # for boot master to communicate with worker and proxy nodes
    # during ICP deployment
    generate_key = true

    # SSH user and key for terraform to connect to newly created VMs
    # ssh_key is the private key corresponding to the public assumed to be included in the template
    ssh_user        = "${var.ssh_user}"
    #ssh_key_base64  = "${base64encode(file(var.ssh_keyfile))}"
    ssh_key_base64 = ${var.ssh_key_base64 != "" ? var.ssh_key_base64 : base64encode(file(var.ssh_keyfile))}"
    ssh_agent       = false
}
