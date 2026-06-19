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

## Prerequisites

Before running Terraform, the following must be available:

```text
Proxmox API user and token
Local development Vault instance
SSH public key for the provisioned machines
```

Terraform reads the Proxmox API token from a local development Vault instance.

The Proxmox token is not stored in Git.

## Vault Instances

This project uses two separate Vault instances:

| Vault instance          | Location              | Purpose                                                                 |
| ----------------------- | --------------------- | ----------------------------------------------------------------------- |
| Local development Vault | Development machine   | Stores the Proxmox API token used by Terraform                          |
| Kubernetes Vault LXC    | Proxmox LXC container | Stores Kubernetes application secrets used by External Secrets Operator |

The local development Vault must exist before running Terraform.

The Kubernetes Vault LXC is created by Terraform and later configured by Ansible.

## Proxmox API Setup

Terraform uses a dedicated Proxmox API user and token.

Current Proxmox permission model:

| Setting   | Value           |
| --------- | --------------- |
| User      | `terraform@pam` |
| Role      | `TerraformProv` |
| Path      | `/`             |
| Propagate | Enabled         |

Run the following commands on the Proxmox host.

Create the custom Terraform role:

```bash
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate SDN.Use Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.GuestAgent.Audit VM.GuestAgent.Unrestricted VM.Migrate VM.PowerMgmt"
```

Create the dedicated Terraform user:

```bash
pveum user add terraform@pam
```

Assign the role at the Datacenter root path with propagation enabled:

```bash
pveum aclmod / -user terraform@pam -role TerraformProv
```

Create an API token for the Terraform user:

```bash
pveum user token add terraform@pam terraform
```

The token ID will be:

```text
terraform@pam!terraform
```

Copy the generated token secret when it is created.

The token secret is shown only once.

The custom `TerraformProv` role allows Terraform to create, clone, configure, power-manage, migrate, and audit the required Proxmox resources for this lab.

## Local Vault Secret

Terraform authenticates to Vault through the standard Vault environment variables.

Example:

```bash
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="<local-vault-token>"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
```

The Proxmox API token must be stored in the local development Vault under:

```text
secret/proxmox/proxmox
```

Expected keys:

| Key                    | Purpose                  |
| ---------------------- | ------------------------ |
| `proxmox_api_url`      | Proxmox API URL          |
| `proxmox_token_id`     | Proxmox API token ID     |
| `proxmox_token_secret` | Proxmox API token secret |

Store the token in Vault:

```bash
vault kv put secret/proxmox/proxmox \
  proxmox_api_url="https://<proxmox-host>:8006/api2/json" \
  proxmox_token_id="terraform@pam!terraform" \
  proxmox_token_secret="<token-secret>"
```

In the Vault UI, this secret is stored under:

```text
Vault
Secrets engines
secret
proxmox
proxmox
```

The secret should contain:

```text
proxmox_api_url
proxmox_token_id
proxmox_token_secret
```

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

Do not commit credentials, Vault tokens, Proxmox API tokens, local variable files, `.terraform/`, or Terraform state files.
