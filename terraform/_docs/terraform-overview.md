# Terraform Overview

This note documents the Terraform layer for the `proxmox-iac-k3s-lab` project.

## Project Goal

Infrastructure as Code project for creating a home or lab k3s environment on Proxmox.

Terraform is used to provision the infrastructure resources required before the servers are configured by Ansible and later managed through the Kubernetes / GitOps workflow.

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

Terraform reads Proxmox credentials from Vault instead of storing them directly in the repository.

## Infrastructure Scope

Terraform is responsible for provisioning the Proxmox infrastructure layer.

This includes:

```text
k3s virtual machines
Vault LXC container
network configuration
cloud-init configuration
SSH public key access
Proxmox resource settings
```

## Infrastructure Layout

```text
Proxmox
│
├── k3s controller VM
│
├── k3s worker VM
│
└── Vault LXC
```

Specific resource details are documented in:

```text
terraform/_docs/proxmox-resources.md
```

## Secret Handling

Terraform retrieves Proxmox credentials from Vault.

The expected Vault integration is documented in:

```text
terraform/_docs/vault-integration.md
```

Real Proxmox tokens, Vault tokens, and Terraform state files should not be committed to Git.

## Related Layers

After Terraform provisions the infrastructure:

```text
Ansible configures the servers and bootstraps the cluster.
Argo CD manages the Kubernetes / GitOps layer.
Vault provides secrets for infrastructure and cluster integrations.
```
