# Terraform Docs

This folder contains the Terraform documentation for the `proxmox-iac-k3s-lab` project.

## Files

```text
terraform-overview.md
proxmox-resources.md
vault-integration.md
runbook.md
```

## Current Terraform Infrastructure

Terraform currently creates:

```text
k3s-controller-01   10.0.20.101   VM ID 201
k3s-worker-01       10.0.20.102   VM ID 202
vault-k3s           10.0.20.110   LXC ID 210
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
