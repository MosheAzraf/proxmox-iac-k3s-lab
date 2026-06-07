output "vm_names" {
  value = {
    for key, vm in proxmox_virtual_environment_vm.k3s_vm :
    key => vm.name
  }
}

output "vm_ids" {
  value = {
    for key, vm in proxmox_virtual_environment_vm.k3s_vm :
    key => vm.vm_id
  }
}

output "vm_ipv4_addresses" {
  value = {
    for key, vm in var.vms :
    key => vm.ipv4_address
  }
}