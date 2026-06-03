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
Settings -> Repositories -> Connect Repo
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

The Root App is the first manual GitOps entry point.

It is applied once with:

```bash
kubectl apply -f _kubernetes/bootstrap/root-app.yaml
```

The Root App points to:

```text
_kubernetes/applications
```

Its job is to create and manage child Argo CD Applications from that directory.

## Argo CD Self-Management

Argo CD is managed through Argo CD itself after the initial bootstrap.

Main files:

```text
_kubernetes/bootstrap/root-app.yaml
_kubernetes/applications/argocd.yaml
_kubernetes/platform/argocd/values.yaml
```

The Argo CD Application uses the official Helm chart:

```text
repoURL: https://argoproj.github.io/argo-helm
chart: argo-cd
```

It also references the local values file from the Git repository:

```text
_kubernetes/platform/argocd/values.yaml
```

Current values include:

```yaml
configs:
  params:
    server.insecure: true
```

The `server.insecure: true` setting is used because Argo CD is exposed through Traefik, and TLS is terminated at Traefik.

## Argo CD Config Manifests

Argo CD also manages additional configuration manifests from:

```text
_kubernetes/platform/argocd/config
```

Current files:

```text
certificate.yaml
ingress-route.yaml
```

The `argocd` Application uses multiple sources:

```text
1. Argo CD Helm chart
2. Git repository values file
3. Git repository config manifests
```

The config source points to:

```text
_kubernetes/platform/argocd/config
```

This keeps the Helm values file separate from regular Kubernetes manifests.

## Internal TLS Certificate

A cert-manager Certificate is used for Argo CD:

```text
argocd-server-tls
```

It is stored in the `argocd` namespace and uses the internal ClusterIssuer:

```text
internal-ca
```

The certificate is created from:

```text
_kubernetes/platform/argocd/config/certificate.yaml
```

Validation command:

```bash
kubectl get certificate -n argocd
```

Expected certificate:

```text
argocd-server-tls
```

Expected state:

```text
Ready = True
```

## Traefik IngressRoute

Argo CD is exposed through Traefik using an IngressRoute.

The route is defined in:

```text
_kubernetes/platform/argocd/config/ingress-route.yaml
```

Hostname:

```text
argocd.home.lab
```

The internal DNS wildcard points to Traefik:

```text
*.home.lab -> 10.0.20.200
```

The IngressRoute sends traffic to the existing Argo CD service:

```text
argocd-server
```

Service port:

```text
80
```

Validation command:

```bash
kubectl get ingressroute -n argocd
```

Expected resource:

```text
argocd
```

## Browser Access

Argo CD can be accessed through:

```text
https://argocd.home.lab
```

If DNS resolution fails in the browser, test directly with:

```bash
curl -vk --resolve argocd.home.lab:443:10.0.20.200 https://argocd.home.lab
```

Expected result:

```text
HTTP/2 200
<title>Argo CD</title>
```

A browser certificate warning is expected until the internal root CA is trusted by the local machine.

## Application Health

Argo CD applications can be checked with:

```bash
kubectl get applications -n argocd
```

Expected general state for platform applications:

```text
Synced / Healthy
```

The exact list of applications may change as the lab evolves.
