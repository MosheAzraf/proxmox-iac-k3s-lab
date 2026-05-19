# secrets
variable "vault_mount" {
  type    = string
  default = "secret"
}

variable "proxmox_secret" {
  type    = string
  default = "proxmox"
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

# vm values
variable "vms" {
  type = map(object({
    proxmox_node       = string
    ubuntu_template_id = number
    vm_id              = number
    name               = string
    ipv4_address       = string
    vm_gateway         = string
    vm_bridge          = string
    vm_username        = string
    cpu_cores          = number
    memory_mb          = number
    disk_size          = number
  }))

  default = {
    "k3s-controller-01" = {
      proxmox_node       = "pve"
      ubuntu_template_id = 9000
      vm_id              = 201
      name               = "k3s-controller-01"
      ipv4_address       = "10.0.20.101/24"
      vm_gateway         = "10.0.20.1"
      vm_bridge          = "vmbr0"
      vm_username        = "ubuntu"
      cpu_cores          = 4
      memory_mb          = 8192
      disk_size          = 150
    }

    "k3s-worker-01" = {
      proxmox_node       = "pve"
      ubuntu_template_id = 9000
      vm_id              = 202
      name               = "k3s-worker-01"
      ipv4_address       = "10.0.20.102/24"
      vm_gateway         = "10.0.20.1"
      vm_bridge          = "vmbr0"
      vm_username        = "ubuntu"
      cpu_cores          = 4
      memory_mb          = 16384
      disk_size          = 150
    }
  }
}