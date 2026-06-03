# External Secrets Operator and Vault Integration

This note documents the External Secrets Operator setup and its connection to Vault.

## Vault Instance

Vault is running on the LXC:

```text
vault-k3s
10.0.20.110
```

Vault UI/API address:

```text
http://10.0.20.110:8200
```

Vault was initialized and unsealed manually during the initial setup.

The following values are saved outside Git:

```text
Unseal Key
Initial Root Token
ESO Vault Token
```

Important:

```text
No Vault tokens or unseal keys are committed to Git.
```

The ESO token may be stored locally outside the repository for lab convenience.

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

Because ESO CRDs are large, the Argo CD Application uses:

```yaml
syncOptions:
  - CreateNamespace=true
  - ServerSideApply=true
```

This avoids Kubernetes annotation size issues on large CRDs.

## External Secrets Config Application

A second Argo CD Application manages the ESO configuration.

Application file:

```text
_kubernetes/applications/external-secrets-config.yaml
```

It points to:

```text
_kubernetes/platform/external-secrets
```

This application currently manages the Vault-backed ClusterSecretStore configuration.

## Vault Token Kubernetes Secret

The Vault token for ESO is created manually as a Kubernetes Secret.

Command:

```bash
kubectl create secret generic vault-token \
  -n external-secrets \
  --from-literal=token="<vault-token>"
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

Expected validation result:

```text
vault-k3s   Valid   ReadWrite   True
```

## End-to-End Flow

```text
Vault
   ↓
External Secrets Operator
   ↓
Kubernetes Secrets
   ↓
GitOps-managed applications
```

The only intentionally manual secret in this flow is:

```text
vault-token
```

This is kept out of Git because it contains the real Vault token.
