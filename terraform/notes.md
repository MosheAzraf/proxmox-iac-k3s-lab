# Proxmox IaC K3s Lab

Infrastructure as Code project for creating a home or lab k3s environment on Proxmox.

The project uses Terraform to create virtual machines and infrastructure resources in Proxmox, and Ansible to prepare the nodes, install k3s, and bootstrap the cluster components.

## Current Terraform Infrastructure

Terraform currently creates:

- Ubuntu VM: `k3s-controller-01` (`10.0.20.101`)
- Ubuntu VM: `k3s-worker-01` (`10.0.20.102`)
- Ubuntu 24.04 LXC: `vault-k3s` (`10.0.20.110`)

## Terraform Structure

```text
terraform/
├── providers.tf
├── variables.tf
├── vm.tf
├── vault_lxc.tf
└── outputs.tf
```

## Providers

The project uses:

- HashiCorp Vault provider
- Proxmox provider (`bpg/proxmox`)

Terraform reads Proxmox credentials directly from Vault.

## Vault Integration

Terraform reads the following values from:

```text
mount: secret
secret: proxmox
```

Expected fields:

```text
proxmox_api_url
proxmox_token_id
proxmox_token_secret
```

## Virtual Machines

Current VM definitions:

### k3s-controller-01

```text
VM ID: 201
IP: 10.0.20.101/24
CPU: 4 cores
RAM: 8192 MB
Disk: 150 GB
```

### k3s-worker-01

```text
VM ID: 202
IP: 10.0.20.102/24
CPU: 4 cores
RAM: 16384 MB
Disk: 150 GB
```

Both VMs:

- Clone from Ubuntu template VM ID `9000`
- Use cloud-init
- Use SSH public key authentication
- Have QEMU guest agent enabled
- Start automatically on boot

## Vault LXC Container

A dedicated Ubuntu 24.04 LXC container was added for Vault.

Configuration:

```text
Hostname: vault-k3s
VM ID: 210
IP: 10.0.20.110/24
Gateway: 10.0.20.1
CPU: 2 cores
RAM: 2048 MB
Swap: 512 MB
Disk: 20 GB
Bridge: vmbr0
Template: ubuntu-24.04-standard_24.04-2_amd64.tar.zst
```

Characteristics:

- Unprivileged container
- Starts automatically on boot
- Uses the same SSH public key as the k3s nodes
- Accessible through SSH as `root`
- Managed through Terraform

Example login:

```bash
ssh root@10.0.20.110
```

## Important Terraform Notes

A lifecycle rule was added to ignore Proxmox feature flag drift on the LXC container:

```hcl
lifecycle {
  ignore_changes = [
    features
  ]
}
```

This prevents Terraform from repeatedly attempting feature flag modifications that require elevated Proxmox permissions.

## Current Infrastructure Layout

```text
Proxmox
│
├── VM 201
│   └── k3s-controller-01
│
├── VM 202
│   └── k3s-worker-01
│
└── LXC 210
    └── vault-k3s
```

## Current Status

Terraform:

- Successfully provisions k3s VMs
- Successfully provisions the Vault LXC
- Retrieves Proxmox credentials from Vault
- Uses SSH public key authentication
- Reports a clean plan with no pending changes

Next planned step:

- Add the Vault LXC to the Ansible inventory
- Install and configure HashiCorp Vault
- Integrate Vault with External Secrets Operator (ESO)
- Manage ESO through Argo CD