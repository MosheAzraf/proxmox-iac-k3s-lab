# GitOps Repository Notes

This note documents the GitOps structure for the `proxmox-iac-k3s-lab` project.

The goal is to keep the Kubernetes / GitOps layer clean, separated by responsibility, and ready for Argo CD management.

## Current Direction

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
```

After this bootstrap layer is ready, Argo CD manages the GitOps layer from the `_kubernetes` directory.

## Current Structure

```text
_kubernetes/
├── bootstrap/
│   └── root-app.yaml
├── applications/
│   ├── argocd.yaml
│   ├── external-secrets.yaml
│   └── external-secrets-config.yaml
├── notes.md
└── platform/
    ├── argocd/
    │   └── values.yaml
    └── external-secrets/
        ├── cluster-secret-store.yaml
        ├── demo-external-secret.yaml
        └── values.yaml
```

## Directory Responsibilities

### bootstrap

```text
_kubernetes/bootstrap/
```

This directory contains the first manual entry point for Argo CD.

Main file:

```text
root-app.yaml
```

This file is applied manually once with `kubectl`.

Its job is to point Argo CD to the GitOps applications defined in the repository.

### applications

```text
_kubernetes/applications/
```

This directory contains Argo CD `Application` manifests.

Current files:

```text
argocd.yaml
external-secrets.yaml
external-secrets-config.yaml
```

### platform

```text
_kubernetes/platform/
```

This directory contains platform component configuration.

Current structure:

```text
platform/
├── argocd/
│   └── values.yaml
└── external-secrets/
    ├── cluster-secret-store.yaml
    ├── demo-external-secret.yaml
    └── values.yaml
```

## Design Decision

The repository separates these concerns:

```text
bootstrap/
```

Manual one-time Argo CD bootstrap entry point.

```text
applications/
```

Argo CD Application manifests only.

```text
platform/
```

Actual platform configuration, Helm values, and Kubernetes resources.

This avoids putting everything under a single `argocd` directory and keeps the repository easier to understand.

## Current GitOps State

```text
root-app: Synced / Healthy
argocd: Synced / Healthy
external-secrets: Synced / Healthy
external-secrets-config: Synced / Healthy
```

## Future Expanded Structure

```text
_kubernetes/
├── bootstrap/
│   └── root-app.yaml
├── applications/
│   ├── argocd.yaml
│   ├── cert-manager.yaml
│   ├── traefik.yaml
│   ├── metallb.yaml
│   ├── external-secrets.yaml
│   └── external-secrets-config.yaml
└── platform/
    ├── argocd/
    │   └── values.yaml
    ├── cert-manager/
    │   └── values.yaml
    ├── traefik/
    │   └── values.yaml
    ├── metallb/
    │   ├── values.yaml
    │   ├── ip-address-pool.yaml
    │   └── l2-advertisement.yaml
    └── external-secrets/
        ├── cluster-secret-store.yaml
        ├── demo-external-secret.yaml
        └── values.yaml
```
