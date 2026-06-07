resource "proxmox_virtual_environment_vm" "k3s_vm" {
  for_each = var.vms

  name      = each.value.name
  vm_id     = each.value.vm_id
  node_name = each.value.proxmox_node

  started = true
  on_boot = true

  clone {
    vm_id = each.value.ubuntu_template_id
  }

  cpu {
    cores = each.value.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory_mb
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = each.value.disk_size
  }

  network_device {
    bridge = each.value.vm_bridge
  }

  initialization {
    ip_config {
      ipv4 {
        address = each.value.ipv4_address
        gateway = each.value.vm_gateway
      }
    }

    user_account {
      username = each.value.vm_username
      keys     = [var.ssh_public_key]
    }
  }

  agent {
    enabled = true
  }

  lifecycle {
    ignore_changes = [
      initialization[0].user_account[0].keys
    ]
  }
}