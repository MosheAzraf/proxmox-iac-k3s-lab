resource "proxmox_virtual_environment_container" "vault_lxc" {
  node_name   = "pve"
  vm_id       = 210
  description = "Vault LXC"
  tags        = ["vault", "infra"]

  started       = true
  start_on_boot = true
  unprivileged  = true

  operating_system {
    template_file_id = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
    type             = "ubuntu"
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
    swap      = 512
  }

  disk {
    datastore_id = "local-lvm"
    size         = 20
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  initialization {
    hostname = "vault-k3s"

    ip_config {
      ipv4 {
        address = "10.0.20.110/24"
        gateway = "10.0.20.1"
      }
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }

  lifecycle {
    ignore_changes = [
      features
    ]
  }
}