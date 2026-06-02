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
external-secrets          Synced / Healthy
external-secrets-config   Synced / Healthy
```

## Open Argo CD UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open:

```text
https://localhost:8080
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
