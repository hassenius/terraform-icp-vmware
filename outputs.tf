output "ICP Console URL" {
  value = "https://${vsphere_virtual_machine.icpmaster.0.default_ip_address}:8443"
}

output "ICP Admin Username" {
  value = "admin"
}

output "ICP Admin Password" {
  value = "${var.icppassword}"
}