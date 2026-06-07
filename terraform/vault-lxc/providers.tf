terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.9.0"
    }

    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.106.0"
    }
  }
}

ephemeral "vault_kv_secret_v2" "proxmox" {
  mount = var.vault_mount
  name  = var.proxmox_secret
}

provider "proxmox" {
  endpoint  = ephemeral.vault_kv_secret_v2.proxmox.data["proxmox_api_url"]
  api_token = "${ephemeral.vault_kv_secret_v2.proxmox.data["proxmox_token_id"]}=${ephemeral.vault_kv_secret_v2.proxmox.data["proxmox_token_secret"]}"
  insecure  = true
}