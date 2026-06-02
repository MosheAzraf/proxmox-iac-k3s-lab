# Argo CD Notes

This note documents the Argo CD setup and self-management flow for the `proxmox-iac-k3s-lab` project.

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

## Argo CD Self-Management

The first GitOps goal was to make Argo CD self-managed.

Initial files created:

```text
_kubernetes/bootstrap/root-app.yaml
_kubernetes/applications/argocd.yaml
_kubernetes/platform/argocd/values.yaml
```

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
root-app                  Synced / Healthy
argocd                    Synced / Healthy
external-secrets          Synced / Healthy
external-secrets-config   Synced / Healthy
```

This means the current GitOps setup is working.
