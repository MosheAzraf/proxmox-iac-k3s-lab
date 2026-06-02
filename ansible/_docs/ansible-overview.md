# Ansible Overview

This note documents the Ansible structure and responsibility split for the `proxmox-iac-k3s-lab` project.

## Goal

The Ansible layer is responsible for initial bootstrap.

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
- install common node settings
- install k3s controller
- install k3s worker
- bootstrap MetalLB
- bootstrap Traefik
- bootstrap Argo CD
- bootstrap cert-manager
- configure Vault LXC

Argo CD:
- manage itself from Git
- manage External Secrets Operator
- manage External Secrets configuration
- gradually take over platform components
```

Important note:

If Argo CD later takes ownership of Helm releases that were installed by Ansible, avoid running the matching Ansible role repeatedly unless it is intentionally still part of bootstrap.
