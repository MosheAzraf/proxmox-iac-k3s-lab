# Kubernetes / GitOps Layer

Project-specific notes for the Kubernetes and GitOps layer of `proxmox-iac-k3s-lab`.

This directory is the GitOps source for the cluster. Ansible performs the initial bootstrap; Argo CD manages the resources declared here afterward.

## Layout

* `bootstrap/root-app.yaml` - one-time Argo CD entry point.
* `applications/` - Argo CD `Application` resources.
* `platform/` - Helm values and component manifests.

The manifests themselves are the source of truth for versions, namespaces, repository URLs, and configuration.

## Bootstrap

After Ansible has installed Argo CD and the local kubeconfig is active:

```bash
kubectl apply -f _kubernetes/bootstrap/root-app.yaml
```

Argo CD then discovers and reconciles everything under `applications/`.

## MetalLB

MetalLB is managed by Argo CD from `applications/metallb/` and `platform/metallb/`.

The current IP address pool is:

```text
10.0.20.200-10.0.20.230
```

## Renovate

Renovate is deployed as a self-hosted CronJob through Argo CD.

It runs weekly and opens pull requests for Helm chart updates found in:

```text
_kubernetes/applications/**/app.yaml
```

The GitHub token is stored in Vault and synced to Kubernetes with External Secrets.

## Secrets

Secrets are not stored in Git.

This Kubernetes layer uses the Vault LXC created for the cluster environment.

This is separate from the local development Vault used by Terraform to read the Proxmox API token.

External Secrets reads from the Vault LXC through the `ClusterSecretStore` defined in:

```text
_kubernetes/platform/external-secrets/cluster-secret-store.yaml
```

External Secrets authenticates with **Vault Kubernetes Authentication**, not a manually created Vault token Secret.

- `platform/external-secrets/vault-auth.yaml` defines the `vault-auth` ServiceAccount in `external-secrets` and its TokenReview ClusterRoleBinding.
- `platform/external-secrets/cluster-secret-store.yaml` uses `auth.kubernetes` with the `external-secrets` Vault role, ServiceAccount reference and configured audience.
- Ansible sets up the matching Vault Kubernetes auth backend and role with `eso-read` read permissions.

**Bootstrap order:** initialize and unseal the Vault LXC, provision the `secret` KV v2 engine, `eso-read` policy and required application secrets; bootstrap Argo CD so it creates the ServiceAccount; then run the tagged Vault Kubernetes auth tasks using Ansible (see [Ansible documentation](../../ansible/_docs/README.md)).

External Secrets requests short-lived Vault credentials automatically as required. No permanent `vault-token` Secret or periodic manual renewal is needed. Initial Vault setup and administrator credentials still require operator action.

### Vault Secret Examples

Example Vault paths and keys currently used by External Secrets:

| Vault path                  | Key                 | Kubernetes target | Purpose                        |
| --------------------------- | ------------------- | ----------------- | ------------------------------ |
| `secret/data/apps/homarr`   | `db-encryption-key` | `db-encryption`   | Homarr database encryption key |
| `secret/data/apps/pgadmin`  | `password`          | `pgadmin-secret`  | pgAdmin admin password         |
| `secret/data/apps/renovate` | `RENOVATE_TOKEN`    | `renovate-secret` | Renovate GitHub token          |

Only the ExternalSecret manifests are stored in Git.

The actual secret values are stored in Vault and are not committed to the repository.

Terraform and Proxmox API credentials are documented in the [Terraform Layer](../../terraform/_docs/README.md).

## Operations

```bash
kubectl get applications -n argocd
kubectl get pods -A
kubectl describe application <name> -n argocd
kubectl get clustersecretstore vault-k3s
kubectl get externalsecrets -A
```

When secret syncing fails, check the `vault-k3s` store first, then inspect the affected ExternalSecret:

```bash
kubectl describe externalsecret <name> -n <namespace>
```

If the store has recovered but an ExternalSecret is still showing a stale error, request a one-time reconciliation:

```bash
kubectl annotate externalsecret <name> -n <namespace> force-sync="$(date +%s)" --overwrite
```

Make ongoing platform changes in `applications/` or `platform/` and let Argo CD reconcile them.

Do not manage GitOps-owned components with their old Ansible playbooks.
