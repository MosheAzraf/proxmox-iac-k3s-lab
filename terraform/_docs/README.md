# Terraform Layer

Project-specific notes for the Terraform infrastructure layer of `proxmox-iac-k3s-lab`.

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

Read the Terraform files for the current resource configuration.

## Terraform Roots

### k3s Virtual Machines

Current VM layout:

| Name                | VM ID | IP address       | CPU       | Memory     | Disk     | Purpose        |
| ------------------- | ----- | ---------------- | --------- | ---------- | -------- | -------------- |
| `k3s-controller-01` | `201` | `10.0.20.101/24` | `4` cores | `8192 MB`  | `150 GB` | k3s controller |
| `k3s-worker-01`     | `202` | `10.0.20.102/24` | `4` cores | `16384 MB` | `150 GB` | k3s worker     |

Common VM settings:

| Setting          | Value       |
| ---------------- | ----------- |
| Proxmox node     | `pve`       |
| Gateway          | `10.0.20.1` |
| Network bridge   | `vmbr0`     |
| Template ID      | `9000`      |
| User             | `ubuntu`    |
| QEMU guest agent | Enabled     |
| Start on boot    | Enabled     |

### Vault LXC

Current Vault LXC layout:

| Name    | VM ID | IP address       | CPU       | Memory    | Disk    | Purpose      |
| ------- | ----- | ---------------- | --------- | --------- | ------- | ------------ |
| `vault` | `210` | `10.0.20.110/24` | `2` cores | `2048 MB` | `20 GB` | Vault server |

Common LXC settings:

| Setting                | Value        |
| ---------------------- | ------------ |
| Proxmox node           | `pve`        |
| Gateway                | `10.0.20.1`  |
| OS                     | Ubuntu 24.04 |
| Unprivileged container | Enabled      |

## Vault Requirements

Terraform authenticates to Vault through the standard environment variables.

Vault must contain the Proxmox credentials referenced by `providers.tf`.

```bash
export VAULT_ADDR="http://10.0.20.110:8200"
export VAULT_TOKEN="<token>"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
```

Expected Vault path for Proxmox credentials:

| Vault path            | Key        | Purpose              |
| --------------------- | ---------- | -------------------- |
| `secret/data/proxmox` | `endpoint` | Proxmox API endpoint |
| `secret/data/proxmox` | `username` | Proxmox API username |
| `secret/data/proxmox` | `password` | Proxmox API password |

Kubernetes application secrets are documented in the [Kubernetes / GitOps Layer](../../_kubernetes/_docs/README.md).

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
