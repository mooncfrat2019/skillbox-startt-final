
variable "username" {
  description = "VK Cloud username"
  type        = string
  sensitive   = true
}

variable "password" {
  description = "VK Cloud password"
  type        = string
  sensitive   = true
}

variable "project_id" {
  description = "VK Cloud project ID"
  type        = string
  sensitive   = true
}

variable "compute_flavor" {
  type = string
  default = "STD3-2-4"
}
variable "key_pair_name" {
  type = string
  default = "id_rsa_windows"
}
variable "availability_zone_name" {
  type = string
  default = "MS1"
}

variable "instance_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 1
}

variable "instance_name" {
  description = "Base name of instance"
  type        = string
  default     = "terraform-vm"
}

variable "external_network_name" {
  description = "Name of the external network"
  type        = string
  default     = "ext-net"
}

variable "vpn_instance_count" {
  description = "Number of vpn instances to create"
  default     = 1
}

variable "vpn_instance_name" {
  description = "Base name for etcd instances"
  default     = "terraform-vpn"
}

variable "center_instance_count" {
  description = "Number of cert center instances to create"
  default     = 1
}

variable "center_instance_name" {
  description = "Base name for Tarantool DB instances"
  default     = "terraform-center"
}