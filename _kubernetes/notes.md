# GitOps Repository Notes

This note documents the planned GitOps structure for the `proxmox-iac-k3s-lab` project.

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

After this bootstrap layer is ready, Argo CD will manage the GitOps layer from the `_kubernetes` directory.

## GitOps Structure

Planned structure:

```text
_kubernetes/
├── bootstrap/
│   └── root-app.yaml
├── applications/
│   └── argocd.yaml
└── platform/
    └── argocd/
        └── values.yaml
```

## Directory Responsibilities

### bootstrap

```text
_kubernetes/bootstrap/
```

This directory contains the first manual entry point for Argo CD.

The main file is:

```text
root-app.yaml
```

This file will be applied manually once with `kubectl`.

Its job is to point Argo CD to the GitOps applications defined in the repository.

### applications

```text
_kubernetes/applications/
```

This directory contains Argo CD `Application` manifests.

These files tell Argo CD what to manage.

Initial file:

```text
argocd.yaml
```

This will be used to make Argo CD manage itself.

Later, more applications can be added here:

```text
cert-manager.yaml
traefik.yaml
metallb.yaml
```

### platform

```text
_kubernetes/platform/
```

This directory contains platform component configuration.

For Helm-based components, this is where Helm values files should live.

Initial structure:

```text
platform/
└── argocd/
    └── values.yaml
```

This keeps Argo CD Application manifests separate from Helm values and platform configuration.

## Future Expanded Structure

The structure can grow into this later:

```text
_kubernetes/
├── bootstrap/
│   └── root-app.yaml
├── applications/
│   ├── argocd.yaml
│   ├── cert-manager.yaml
│   ├── traefik.yaml
│   └── metallb.yaml
└── platform/
    ├── argocd/
    │   └── values.yaml
    ├── cert-manager/
    │   └── values.yaml
    ├── traefik/
    │   └── values.yaml
    └── metallb/
        ├── values.yaml
        ├── ip-address-pool.yaml
        └── l2-advertisement.yaml
```

## Important Design Decision

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

This avoids putting everything under a single `argocd` directory and keeps the repo easier to understand.

## First GitOps Goal

The first GitOps step will be Argo CD self-management.

Initial files to create:

```text
_kubernetes/bootstrap/root-app.yaml
_kubernetes/applications/argocd.yaml
_kubernetes/platform/argocd/values.yaml
```

The first version should not use automatic sync.

Manual sync is safer for the first self-managed Argo CD setup.

## Current Status

Ansible bootstrap is considered mostly complete.

Next planned phase:

```text
Start GitOps setup with Argo CD self-management.
```
