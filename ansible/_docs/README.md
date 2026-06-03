# Ansible Docs

This folder contains the Ansible documentation for the `proxmox-iac-k3s-lab` project.

The Ansible layer is responsible for server configuration and initial cluster bootstrap.

## Files

```text
ansible-overview.md
kubernetes-bootstrap.md
vault.md
vault-env-vars.md
runbook.md
```

## Documentation Index

1. [Ansible Overview](ansible-overview.md)
   General overview of the Ansible layer and how it fits into the project.

2. [Kubernetes Bootstrap](kubernetes-bootstrap.md)
   Notes about the k3s bootstrap process and initial Kubernetes setup.

3. [Vault](vault.md)
   Notes about the Vault setup managed by Ansible.

4. [Vault Environment Variables](vault-env-vars.md)
   Notes about the local environment variables used for Vault-related workflows.

5. [Runbook](runbook.md)
   Operational commands and workflow notes for the Ansible layer.

## Scope

Ansible is used as the bootstrap layer.

It configures the servers, installs k3s, and prepares the initial platform components required before the Kubernetes / GitOps layer can take over ongoing management.
