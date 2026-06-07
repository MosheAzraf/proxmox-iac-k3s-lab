# Terraform

Terraform provisions the Proxmox infrastructure consumed by the rest of the project.

The Terraform layer is split into two separate roots:

```text
terraform/vms
terraform/vault-lxc
```

This keeps the k3s virtual machines and the Vault LXC container in separate Terraform states.

## Source Of Truth

`terraform/vms` manages the k3s virtual machines.

Main files:

```text
providers.tf
variables.tf
vm.tf
outputs.tf
```

`terraform/vault-lxc` manages the Vault LXC container.

Main files:

```text
providers.tf
variables.tf
vault_lxc.tf
```

Read the Terraform files for current addresses, sizing, versions, and resource configuration.

## Prerequisites

Terraform authenticates to Vault through the standard environment variables.

Vault must contain the Proxmox fields referenced by `providers.tf`.

```bash
export VAULT_ADDR="https://<vault-address>"
export VAULT_TOKEN="<token>"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
```

## Run

Run commands from the repository root.

For the k3s virtual machines:

```bash
terraform -chdir=terraform/vms init
terraform -chdir=terraform/vms fmt -check
terraform -chdir=terraform/vms validate
terraform -chdir=terraform/vms plan
terraform -chdir=terraform/vms apply
```

For the Vault LXC container:

```bash
terraform -chdir=terraform/vault-lxc init
terraform -chdir=terraform/vault-lxc fmt -check
terraform -chdir=terraform/vault-lxc validate
terraform -chdir=terraform/vault-lxc plan
terraform -chdir=terraform/vault-lxc apply
```

Review every plan before applying it.

Do not commit credentials, local variable files, `.terraform/`, or Terraform state files.
