# GitOps Repository Notes

This note documents the GitOps structure and Argo CD self-management setup for the `proxmox-iac-k3s-lab` project.

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

## GitOps Structure

Current structure:

```text
_kubernetes/
├── bootstrap/
│   └── root-app.yaml
├── applications/
│   └── argocd.yaml
├── notes.md
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

This file is applied manually once with `kubectl`.

Its job is to point Argo CD to the GitOps applications defined in the repository.

### applications

```text
_kubernetes/applications/
```

This directory contains Argo CD `Application` manifests.

These files tell Argo CD what to manage.

Current file:

```text
argocd.yaml
```

This is used to make Argo CD manage itself.

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

Current structure:

```text
platform/
└── argocd/
    └── values.yaml
```

This keeps Argo CD Application manifests separate from Helm values and platform configuration.

## Argo CD Self-Management

The first GitOps goal was to make Argo CD self-managed.

Initial files created:

```text
_kubernetes/bootstrap/root-app.yaml
_kubernetes/applications/argocd.yaml
_kubernetes/platform/argocd/values.yaml
```

The first version does not use automatic sync.

Manual sync is safer for the first self-managed Argo CD setup.

## Private GitHub Repository Access

The GitHub repository is currently private.

Repository URL used by Argo CD:

```text
https://github.com/MosheAzraf/proxmox-iac-k3s-lab.git
```

A fine-grained GitHub token was created with access only to this repository.

Permissions used:

```text
Contents: Read-only
Metadata: Read-only
```

The token was added to Argo CD through the UI:

```text
Settings → Repositories → Connect Repo
```

Connection type:

```text
HTTPS
```

The token is not committed to Git.

A local zsh environment variable was also created for local reference:

```text
github_proxmox_iac_k3s_lab_token
```

## Root App

The Root App was applied manually:

```bash
kubectl apply -f bootstrap/root-app.yaml
```

Result:

```text
application.argoproj.io/root-app created
```

The Root App points to:

```text
_kubernetes/applications
```

Its job is to create and manage child Argo CD Applications from that directory.

## Argo CD Application

The first child application is:

```text
argocd
```

It uses the Argo CD Helm chart:

```text
repoURL: https://argoproj.github.io/argo-helm
chart: argo-cd
targetRevision: 9.5.14
```

It also references the local values file from the Git repository:

```text
_kubernetes/platform/argocd/values.yaml
```

The values file is currently minimal:

```yaml
# Argo CD Helm values
```

No custom Helm values are required at this stage.

## Current Sync Status

Applications were checked with:

```bash
kubectl get applications -n argocd
```

Current result:

```text
NAME       SYNC STATUS   HEALTH STATUS
argocd     Synced        Healthy
root-app   Synced        Healthy
```

This means the initial GitOps setup is working.

Argo CD is now self-managed at the first basic level.

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

## Current Status

Ansible bootstrap is considered mostly complete.

Initial Argo CD GitOps setup is working.

Current GitOps state:

```text
root-app: Synced / Healthy
argocd: Synced / Healthy
```

## Next Planned Phase

Next possible phase:

```text
Move cert-manager management into GitOps.
```

This should be done gradually and manually synced first, without automatic sync.
