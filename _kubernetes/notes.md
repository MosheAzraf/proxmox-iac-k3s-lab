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

For Helm-based components, this is where Helm values files should live.

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

## External Secrets Operator and Vault Integration

External Secrets Operator was added after Vault was initialized and unsealed.

Vault is running on the LXC:

```text
vault-k3s
10.0.20.110
```

Vault UI/API address:

```text
http://10.0.20.110:8200
```

Vault was initialized and unsealed manually.

The following were saved outside Git:

```text
Unseal Key
Initial Root Token
ESO Vault Token
```

Important:

```text
No Vault tokens or unseal keys are committed to Git.
```

The ESO token was also saved in Proxmox Notes for lab convenience.

## External Secrets Operator Application

External Secrets Operator is installed through Argo CD using the official Helm chart.

Application file:

```text
_kubernetes/applications/external-secrets.yaml
```

Helm chart source:

```text
https://charts.external-secrets.io
```

Chart:

```text
external-secrets
```

Version used:

```text
2.5.0
```

Because ESO CRDs are large, the Argo CD Application uses:

```yaml
syncOptions:
  - CreateNamespace=true
  - ServerSideApply=true
```

This fixed the Kubernetes annotation size error on the large CRDs:

```text
metadata.annotations: Too long: may not be more than 262144 bytes
```

## External Secrets Config Application

A second Argo CD Application was added to manage the ESO configuration.

Application file:

```text
_kubernetes/applications/external-secrets-config.yaml
```

It points to:

```text
_kubernetes/platform/external-secrets
```

This application manages:

```text
ClusterSecretStore / vault-k3s
ExternalSecret / demo-secret
```

## Vault Token Kubernetes Secret

The Vault token for ESO was created manually as a Kubernetes Secret.

Command used:

```bash
kubectl create secret generic vault-token \
  -n external-secrets \
  --from-literal=token="PASTE_TOKEN_HERE"
```

The secret exists in:

```text
namespace: external-secrets
name: vault-token
```

This secret is not stored in Git.

It is referenced by the ClusterSecretStore.

## ClusterSecretStore

The ClusterSecretStore is managed by Argo CD.

File:

```text
_kubernetes/platform/external-secrets/cluster-secret-store.yaml
```

Name:

```text
vault-k3s
```

Vault server:

```text
http://10.0.20.110:8200
```

Vault KV path:

```text
secret
```

KV version:

```text
v2
```

It references the manually created Kubernetes Secret:

```text
vault-token
```

Validation result:

```text
NAME        AGE   STATUS   CAPABILITIES   READY
vault-k3s   7s    Valid    ReadWrite      True
```

## Demo ExternalSecret

A test secret was created in the Vault UI under:

```text
secret/apps/demo
```

The demo ExternalSecret is managed by Argo CD.

File:

```text
_kubernetes/platform/external-secrets/demo-external-secret.yaml
```

It creates a Kubernetes Secret:

```text
name: demo-secret
namespace: default
```

Validation result:

```text
NAME          STORETYPE            STORE       REFRESH INTERVAL   STATUS         READY
demo-secret   ClusterSecretStore   vault-k3s   1m                 SecretSynced   True
```

The Kubernetes Secret was created successfully:

```text
NAME          TYPE     DATA
demo-secret   Opaque   2
```

## Current Sync Status

Applications were checked with:

```bash
kubectl get applications -n argocd
```

Current result:

```text
root-app                  Synced / Healthy
argocd                    Synced / Healthy
external-secrets          Synced / Healthy
external-secrets-config   Synced / Healthy
```

This means the current GitOps setup is working.

External Secrets is connected end-to-end:

```text
Vault -> External Secrets Operator -> Kubernetes Secret -> Argo CD GitOps
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

The only intentionally manual secret is:

```text
vault-token
```

This is kept out of Git because it contains the real Vault token.

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

## Current Status

Ansible bootstrap is considered mostly complete.

Initial Argo CD GitOps setup is working.

External Secrets Operator is installed and connected to Vault.

Current GitOps state:

```text
root-app: Synced / Healthy
argocd: Synced / Healthy
external-secrets: Synced / Healthy
external-secrets-config: Synced / Healthy
```

## Next Planned Phase

Next possible phases:

```text
Replace the demo ExternalSecret with a real application secret.
Move cert-manager management into GitOps.
Decide later whether demo-secret should stay as a lab test or be removed.
```
