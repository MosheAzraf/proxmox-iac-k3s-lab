# Kubernetes / GitOps Docs

This folder contains the Kubernetes / GitOps documentation for the `proxmox-iac-k3s-lab` project.

The Kubernetes layer is managed through Argo CD from the `_kubernetes` directory.

## Files

```text
gitops.md
argocd.md
external-secrets.md
runbook.md
```

## Documentation Index

1. [GitOps](gitops.md)
   General notes about the GitOps structure and how Kubernetes resources are organized.

2. [Argo CD](argocd.md)
   Notes about Argo CD, self-management, and application management.

3. [External Secrets](external-secrets.md)
   Notes about External Secrets Operator and secret management integration.

4. [Runbook](runbook.md)
   Operational commands and workflow notes for the Kubernetes / GitOps layer.

## Scope

The Kubernetes / GitOps layer contains the manifests and Argo CD applications used to manage the cluster platform from Git.

This layer is intended to hold Kubernetes platform configuration and application definitions after the initial bootstrap phase is complete.
