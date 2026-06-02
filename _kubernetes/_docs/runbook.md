# Kubernetes / GitOps Runbook

This file contains short operational commands for the Kubernetes / GitOps layer.

## Check Argo CD Applications

```bash
kubectl get applications -n argocd
```

Expected current state:

```text
root-app                  Synced / Healthy
argocd                    Synced / Healthy
cert-manager              Synced / Healthy
cert-manager-config       Synced / Healthy
external-secrets          Synced / Healthy
external-secrets-config   Synced / Healthy
```

## Open Argo CD UI with Port Forward

Argo CD currently runs behind Traefik with `server.insecure: true`.

Use HTTP when using port-forward:

```bash
kubectl port-forward svc/argocd-server -n argocd 8081:80
```

Open:

```text
http://localhost:8081
```

## Open Argo CD through Traefik

Argo CD is exposed internally through Traefik:

```text
https://argocd.home.lab
```

DNS should resolve to the Traefik LoadBalancer IP:

```bash
dig argocd.home.lab +short
```

Expected:

```text
10.0.20.200
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

## Check Traefik Service

```bash
kubectl get svc -n traefik
```

Expected Traefik LoadBalancer IP:

```text
10.0.20.200
```

## Check Argo CD Certificate

```bash
kubectl get certificate -n argocd
```

Expected:

```text
argocd-server-tls   True   argocd-server-tls
```

## Check Argo CD IngressRoute

```bash
kubectl get ingressroute -n argocd
```

Expected:

```text
argocd
```

## Check cert-manager Pods

```bash
kubectl get pods -n cert-manager
```

Expected pods:

```text
cert-manager
cert-manager-cainjector
cert-manager-webhook
```

## Check cert-manager ClusterIssuers

```bash
kubectl get clusterissuer
```

Expected:

```text
selfsigned-issuer   True
internal-ca         True
```

## Check Internal Root CA

```bash
kubectl get certificate -n cert-manager
```

Expected:

```text
internal-root-ca   True   internal-root-ca
```

Check the generated Secret:

```bash
kubectl get secret internal-root-ca -n cert-manager
```

Expected type:

```text
kubernetes.io/tls
```

## Check External Secrets Pods

```bash
kubectl get pods -n external-secrets
```

Expected pods:

```text
external-secrets
external-secrets-cert-controller
external-secrets-webhook
```

## Check External Secrets CRDs

```bash
kubectl get crd | grep external-secrets
```

Important CRDs:

```text
externalsecrets.external-secrets.io
secretstores.external-secrets.io
clustersecretstores.external-secrets.io
```

## Check ClusterSecretStore

```bash
kubectl get clustersecretstore
```

Expected:

```text
vault-k3s   Valid   ReadWrite   True
```

## Check Demo ExternalSecret

```bash
kubectl get externalsecret -n default
```

Expected:

```text
demo-secret   ClusterSecretStore   vault-k3s   SecretSynced   True
```

## Check Demo Kubernetes Secret

```bash
kubectl get secret demo-secret -n default
```

Expected:

```text
demo-secret   Opaque   2
```

## Recreate Vault Token Secret for ESO

Use only if the Kubernetes Secret was deleted or needs to be replaced.

```bash
kubectl create secret generic vault-token \
  -n external-secrets \
  --from-literal=token="PASTE_TOKEN_HERE"
```

Do not commit the real token to Git.
