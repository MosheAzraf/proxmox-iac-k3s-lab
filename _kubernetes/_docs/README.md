# Kubernetes / GitOps

This directory is the GitOps source for the cluster. Ansible performs the
initial bootstrap; Argo CD manages the resources declared here afterward.

## Layout

- `bootstrap/root-app.yaml` - one-time Argo CD entry point.
- `applications/` - Argo CD `Application` resources.
- `platform/` - Helm values and component manifests.

The manifests themselves are the source of truth for versions, namespaces,
repository URLs, and configuration.

## Bootstrap

After Ansible has installed Argo CD and the local kubeconfig is active:

```bash
kubectl apply -f _kubernetes/bootstrap/root-app.yaml
```

Argo CD then discovers and reconciles everything under `applications/`.

## Secrets

Secrets are not stored in Git. External Secrets reads from Vault through the
`ClusterSecretStore` in `platform/external-secrets/`.

Create the Vault authentication secret manually in the namespace referenced by
that manifest:

```bash
kubectl create secret generic vault-token \
  --from-literal=token="$VAULT_TOKEN" \
  --namespace external-secrets
```

## Operations

```bash
kubectl get applications -n argocd
kubectl get pods -A
kubectl describe application <name> -n argocd
```

Make ongoing platform changes in `applications/` or `platform/` and let Argo CD
reconcile them. Do not manage GitOps-owned components with their old Ansible
playbooks.
