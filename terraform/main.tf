terraform {
    required_providers {
        vkcs = {
            source = "vk-cs/vkcs"
            version = "< 1.0.0"
        }
    }
}


provider "vkcs" {
    # Your user account.
    username = var.username

    # The password of the account
    password = var.password

    # The tenant token can be taken from the project Settings tab - > API keys.
    # Project ID will be our token.
    project_id = var.project_id

    # Region name
    region = "RegionOne"

    auth_url = "https://infra.mail.ru:35357/v3/"
}

data "vkcs_compute_flavor" "compute" {
    name = var.compute_flavor
}

data "vkcs_images_image" "compute" {
    visibility = "public"
    default    = true
    properties = {
        mcs_os_distro  = "ubuntu"
        mcs_os_version = "22.04"
    }
}
# etcd instances
resource "vkcs_compute_instance" "vpn" {
    count                   = var.vpn_instance_count
    name                    = "${var.vpn_instance_name}-${count.index + 1}"
    flavor_id               = data.vkcs_compute_flavor.compute.id
    key_pair                = var.key_pair_name
    security_groups         = ["default","ssh", "all"]
    availability_zone       = var.availability_zone_name

    block_device {
        uuid                  = data.vkcs_images_image.compute.id
        source_type           = "image"
        destination_type      = "volume"
        volume_type           = "ceph-ssd"
        volume_size           = 20
        boot_index            = 0
        delete_on_termination = true
    }

    network {
        uuid = data.vkcs_networking_network.tcf-test.id
    }
}

resource "vkcs_networking_floatingip" "vpn_fip" {
    count = var.vpn_instance_count
    pool = var.external_network_name
}

resource "vkcs_compute_floatingip_associate" "vpn_fip" {
    count = var.vpn_instance_count
    floating_ip = vkcs_networking_floatingip.vpn_fip[count.index].address
    instance_id = vkcs_compute_instance.vpn[count.index].id
}

# Tarantool DB instances
resource "vkcs_compute_instance" "center" {
    count                   = var.center_instance_count
    name                    = "${var.center_instance_name}-${count.index + 1}"
    flavor_id               = data.vkcs_compute_flavor.compute.id
    key_pair                = var.key_pair_name
    security_groups         = ["default","ssh", "all"]
    availability_zone       = var.availability_zone_name

    block_device {
        uuid                  = data.vkcs_images_image.compute.id
        source_type           = "image"
        destination_type      = "volume"
        volume_type           = "ceph-ssd"
        volume_size           = 20
        boot_index            = 0
        delete_on_termination = true
    }

    network {
        uuid = data.vkcs_networking_network.tcf-test.id
    }
}

resource "vkcs_networking_floatingip" "center_fip" {
    count = var.center_instance_count
    pool = var.external_network_name
}

resource "vkcs_compute_floatingip_associate" "center_fip" {
    count = var.center_instance_count
    floating_ip = vkcs_networking_floatingip.center_fip[count.index].address
    instance_id = vkcs_compute_instance.center[count.index].id
}

