# Terraform

Terraform provisions the Proxmox infrastructure consumed by Ansible: the k3s
virtual machines and the Vault container.

## Source Of Truth

- `providers.tf` - provider configuration and Vault-backed credentials.
- `variables.tf` - VM definitions and input values.
- `vm.tf` - k3s virtual machines.
- `vault_lxc.tf` - Vault container.
- `outputs.tf` - provisioned host details.

Read the Terraform files for current addresses, sizing, versions, and resource
configuration.

## Prerequisites

Terraform authenticates to Vault through the standard environment variables.
Vault must contain the Proxmox fields referenced by `providers.tf`.

```bash
export VAULT_ADDR="https://<vault-address>"
export VAULT_TOKEN="<token>"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
```

## Run

Run commands from `terraform/`:

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Review every plan before applying it. Do not commit credentials, local variable
files, or Terraform state.
