# Terraform Docs

This folder contains the Terraform documentation for the `proxmox-iac-k3s-lab` project.

The Terraform layer is responsible for provisioning the Proxmox infrastructure used by the lab.

## Files

```text
terraform-overview.md
proxmox-resources.md
vault-integration.md
runbook.md
```

## Documentation Index

1. [Terraform Overview](terraform-overview.md)
   General overview of the Terraform layer and how it fits into the project.

2. [Proxmox Resources](proxmox-resources.md)
   Notes about the Proxmox resources managed by Terraform.

3. [Vault Integration](vault-integration.md)
   Notes about how Terraform retrieves Proxmox credentials from Vault.

4. [Runbook](runbook.md)
   Operational commands and workflow notes for the Terraform layer.

## Scope

Terraform is used as the infrastructure provisioning layer.

It manages the Proxmox resources required before the servers can be configured by Ansible and later managed through the Kubernetes / GitOps workflow.
