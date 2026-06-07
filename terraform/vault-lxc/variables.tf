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