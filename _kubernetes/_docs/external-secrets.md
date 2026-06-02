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

## End-to-End Flow

```text
Vault -> External Secrets Operator -> Kubernetes Secret -> Argo CD GitOps
```

The only intentionally manual secret is:

```text
vault-token
```

This is kept out of Git because it contains the real Vault token.
