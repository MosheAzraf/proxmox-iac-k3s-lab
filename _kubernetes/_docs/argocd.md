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

Current values:

```yaml
# Argo CD Helm values
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

A cert-manager Certificate was created for Argo CD:

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

Expected result:

```text
argocd-server-tls   True   argocd-server-tls
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

The internal DNS record is configured on the MikroTik router:

```text
*.home.lab → 10.0.20.200
```

Traefik LoadBalancer IP:

```text
10.0.20.200
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

Expected result:

```text
argocd
```

## Browser Access

Argo CD can be accessed through:

```text
https://argocd.home.lab
```

The route was tested with:

```bash
curl -vk --resolve argocd.home.lab:443:10.0.20.200 https://argocd.home.lab
```

The response returned:

```text
HTTP/2 200
<title>Argo CD</title>
```

This confirms that DNS, Traefik, TLS routing, and Argo CD are working.

The internal CA is not trusted by the Mac yet, so a browser certificate warning is expected.

## Current Sync Status

Applications were checked with:

```bash
kubectl get applications -n argocd
```

Current applications:

```text
root-app
argocd
cert-manager
cert-manager-config
external-secrets
external-secrets-config
```

Current working state:

```text
root-app                  Synced / Healthy
argocd                    Synced / Healthy
cert-manager              Synced / Healthy
cert-manager-config       Synced / Healthy
external-secrets          Synced / Healthy
external-secrets-config   Synced / Healthy
```

This means the current GitOps setup is working.
