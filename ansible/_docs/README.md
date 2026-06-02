# Ansible Docs

This folder contains the Ansible documentation for the `proxmox-iac-k3s-lab` project.

## Files

```text
ansible-overview.md
kubernetes-bootstrap.md
vault.md
vault-env-vars.md
runbook.md
```

## Current Status

Ansible is used for the initial bootstrap layer.

Current Ansible bootstrap includes:

```text
common node settings
k3s controller
k3s worker
MetalLB
Traefik
Argo CD
cert-manager
Vault LXC configuration
```

## Current Direction

Ansible handles bootstrap.

Argo CD gradually takes over GitOps-managed platform components.

Next planned phase:

```text
Move cert-manager management from Ansible to Argo CD.
```
