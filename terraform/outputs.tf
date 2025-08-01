output "vpn_instances" {
  value = {
    for idx, instance in vkcs_compute_instance.vpn :
    instance.name => {
      public_ip  = vkcs_networking_floatingip.vpn_fip[idx].address
      private_ip = instance.network[0].fixed_ip_v4
    }
  }
}

output "center_instances" {
  value = {
    for idx, instance in vkcs_compute_instance.center :
    instance.name => {
      public_ip  = vkcs_networking_floatingip.center_fip[idx].address
      private_ip = instance.network[0].fixed_ip_v4
    }
  }
}