# Terraform Overview

This note documents the Terraform layer for the `proxmox-iac-k3s-lab` project.

## Project Goal

Infrastructure as Code project for creating a home or lab k3s environment on Proxmox.

The project uses Terraform to create virtual machines and infrastructure resources in Proxmox.

Ansible is then used to prepare the nodes, install k3s, and bootstrap the cluster components.

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

```text
HashiCorp Vault provider
Proxmox provider: bpg/proxmox
```

Terraform reads Proxmox credentials directly from Vault.

## Current Infrastructure

Terraform currently creates:

```text
Ubuntu VM: k3s-controller-01   10.0.20.101
Ubuntu VM: k3s-worker-01       10.0.20.102
Ubuntu 24.04 LXC: vault-k3s    10.0.20.110
```

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

```text
Successfully provisions k3s VMs
Successfully provisions the Vault LXC
Retrieves Proxmox credentials from Vault
Uses SSH public key authentication
Reports a clean plan with no pending changes
```

## Next Related Layers

After Terraform provisions the infrastructure:

```text
Ansible configures the nodes and installs platform components.
Argo CD manages the GitOps layer.
Vault provides secrets for Terraform and External Secrets Operator.
```
