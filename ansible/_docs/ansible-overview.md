# Ansible Overview

This note documents the Ansible structure and responsibility split for the `proxmox-iac-k3s-lab` project.

## Goal

The Ansible layer is responsible for the initial bootstrap of the servers and the base Kubernetes platform.

After the bootstrap phase, Argo CD manages the GitOps-owned Kubernetes platform components from the `_kubernetes` directory.

## Ansible Scope

Ansible is used for:

```text
common node settings
k3s controller installation
k3s worker installation
MetalLB bootstrap
Traefik bootstrap
Argo CD bootstrap
Vault LXC configuration
Vault local lab auto-unseal
```

cert-manager was originally installed during bootstrap by Ansible, but it is now managed by Argo CD.

## Required Ansible Collection

Install:

```bash
ansible-galaxy collection install kubernetes.core
```

Used modules:

```text
kubernetes.core.helm_repository
kubernetes.core.helm
kubernetes.core.k8s
```

## Optional Helm Plugin

To avoid Helm idempotency warnings and improve change detection:

```bash
helm plugin install https://github.com/databus23/helm-diff
```

This removes warnings like:

```text
The default idempotency check can fail to report changes in certain cases.
Install helm diff >= 3.4.1 for better results.
```

## KUBECONFIG

The local machine previously had multiple kubeconfig files configured:

```bash
$HOME/.kube/config:$HOME/.kube/config-pi
```

This caused Ansible to try connecting to an old Kubernetes API address.

The fix was to set:

```bash
export KUBECONFIG="$HOME/.kube/config"
```

This was added to:

```text
~/.zshrc
```

After reloading the shell:

```bash
source ~/.zshrc
```

The active kubeconfig points to the current Proxmox k3s cluster:

```text
https://10.0.20.101:6443
```

## Current Responsibility Split

Current approach:

```text
Ansible:
- configure base server settings
- install k3s controller
- install k3s worker
- bootstrap MetalLB
- bootstrap Traefik
- bootstrap Argo CD
- configure Vault LXC
- configure local lab auto-unseal for Vault

Argo CD:
- manage itself from Git
- manage cert-manager
- manage cert-manager internal CA configuration
- manage External Secrets Operator
- manage External Secrets configuration
- manage GitOps-owned Kubernetes platform components
```

## Important Notes

Ansible is the bootstrap layer, not the long-term GitOps management layer.

If Argo CD takes ownership of components that were initially installed by Ansible, avoid running the matching Ansible role repeatedly unless the action is intentional.

The Vault auto-unseal setup is for local lab convenience only. It is not intended to represent a production-grade Vault deployment.
