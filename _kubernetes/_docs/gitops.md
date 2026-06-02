# GitOps Repository Notes

This note documents the GitOps structure for the `proxmox-iac-k3s-lab` project.

The goal is to keep the Kubernetes / GitOps layer clean, separated by responsibility, and managed by Argo CD.

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
Vault
```

cert-manager was originally installed by Ansible, but it has now been moved to Argo CD management.

After bootstrap, Argo CD manages the GitOps layer from the `_kubernetes` directory.

## Current Structure

```text
_kubernetes/
├── _docs/
│   ├── argocd.md
│   ├── external-secrets.md
│   ├── gitops.md
│   ├── README.md
│   └── runbook.md
├── applications/
│   ├── argocd.yaml
│   ├── cert-manager.yaml
│   ├── cert-manager-config.yaml
│   ├── external-secrets.yaml
│   └── external-secrets-config.yaml
├── bootstrap/
│   └── root-app.yaml
└── platform/
    ├── argocd/
    │   ├── config/
    │   │   ├── certificate.yaml
    │   │   └── ingress-route.yaml
    │   └── values.yaml
    ├── cert-manager/
    │   ├── config/
    │   │   ├── bootstrap-issuer.yaml
    │   │   ├── ca-issuer.yaml
    │   │   └── root-ca.yaml
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
cert-manager.yaml
cert-manager-config.yaml
external-secrets.yaml
external-secrets-config.yaml
```

### platform

```text
_kubernetes/platform/
```

This directory contains platform component configuration.

It includes Helm values, Kubernetes manifests, and component-specific config.

Current platform areas:

```text
argocd/
cert-manager/
external-secrets/
```

## Argo CD

Argo CD is self-managed by the `argocd` Application.

The `argocd` Application uses multiple sources:

```text
1. Argo CD Helm chart
2. Git repository values file
3. Git repository config manifests
```

The Helm values file is:

```text
_kubernetes/platform/argocd/values.yaml
```

The Argo CD config manifests are stored separately in:

```text
_kubernetes/platform/argocd/config
```

Current Argo CD config manifests:

```text
certificate.yaml
ingress-route.yaml
```

Argo CD is exposed internally through Traefik at:

```text
https://argocd.home.lab
```

The internal DNS wildcard points to Traefik:

```text
*.home.lab → 10.0.20.200
```

## cert-manager

cert-manager is now managed by Argo CD.

Application file:

```text
_kubernetes/applications/cert-manager.yaml
```

Helm values file:

```text
_kubernetes/platform/cert-manager/values.yaml
```

cert-manager config is managed separately by:

```text
_kubernetes/applications/cert-manager-config.yaml
```

The config path is:

```text
_kubernetes/platform/cert-manager/config
```

Current cert-manager config files:

```text
bootstrap-issuer.yaml
root-ca.yaml
ca-issuer.yaml
```

These create an internal CA flow:

```text
selfsigned-issuer
internal-root-ca
internal-ca
```

The `internal-ca` ClusterIssuer is used to issue internal certificates for services in the cluster.

## External Secrets

External Secrets Operator is managed by Argo CD.

Application files:

```text
_kubernetes/applications/external-secrets.yaml
_kubernetes/applications/external-secrets-config.yaml
```

Platform files:

```text
_kubernetes/platform/external-secrets/values.yaml
_kubernetes/platform/external-secrets/cluster-secret-store.yaml
_kubernetes/platform/external-secrets/demo-external-secret.yaml
```

The `vault-token` Kubernetes Secret is still created manually and is not committed to Git.

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

For components that need both Helm values and plain Kubernetes manifests, the manifests are placed under a `config/` directory.

Example:

```text
platform/argocd/
├── config/
└── values.yaml
```

This keeps Helm values separate from Kubernetes manifests and avoids accidental sync of non-manifest files.

## Current GitOps State

```text
root-app: Synced / Healthy
argocd: Synced / Healthy
cert-manager: Synced / Healthy
cert-manager-config: Synced / Healthy
external-secrets: Synced / Healthy
external-secrets-config: Synced / Healthy
```

The current GitOps setup is working.
