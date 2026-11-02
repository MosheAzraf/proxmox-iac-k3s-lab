# Kubernetes & GitOps Operations

This directory contains the **declarative source of truth** for the platform after the initial Ansible bootstrap. For full first-time setup and dependency order, follow [INSTALLATION.md](../../INSTALLATION.md).

## Layout and ownership

| Directory | Responsibility |
| --- | --- |
| `bootstrap/root-app.yaml` | Argo CD root Application |
| `applications/` | Child Argo CD Applications |
| `platform/` | Component configuration and Helm values |

**Ansible bootstraps** k3s, Traefik, and the initial Argo CD service. **Argo CD then reconciles** the declared platform resources in Git. Do not use legacy bootstrap playbooks to maintain GitOps-owned applications.

## Managed components

- Argo CD
- cert-manager and certificate configuration
- External Secrets Operator and Vault integration
- MetalLB (pool `10.0.20.200–10.0.20.230`)
- kube-prometheus-stack / Prometheus / Grafana
- Homarr
- Renovate (scheduled GitOps dependency updates)

Longhorn, CloudNativePG, pgAdmin, and Reloader were deliberately removed to keep this an infrastructure-focused lab.

## Argo CD bootstrap and reconciliation

The initial Ansible `site.yaml` flow applies `bootstrap/root-app.yaml`. For a separately initialized Argo CD installation, from the **repository root**:

```bash
kubectl apply -f _kubernetes/bootstrap/root-app.yaml
```

The root Application is configured for automated sync and self-healing; check its state:

```bash
kubectl get applications -n argocd
```

The October 2026 clean rebuild required a manual sync before automatic synchronization was added. If reconciliation remains stuck **after reviewing the cause**, use this fallback:

```bash
kubectl -n argocd patch application root-app --type merge -p '{"operation":{"sync":{"revision":"HEAD","prune":true}}}'
```

That command is not a normal step for every installation. The current automatic bootstrap behavior has **not yet been tested in a subsequent completely clean rebuild**.

## Vault and External Secrets

The **cluster Vault LXC** stores application secrets. It is separate from the development-machine Vault that Terraform uses for Proxmox API credentials.

External Secrets Operator authenticates to cluster Vault via **Kubernetes authentication**, using the `vault-auth` ServiceAccount and Vault role `external-secrets` with `eso-read` policy. No permanent Vault token is committed to Kubernetes.

Current KV v2 secrets:

| Vault CLI path | Key | Consumer |
| --- | --- | --- |
| `secret/apps/homarr` | `db-encryption-key` | Homarr |
| `secret/apps/renovate` | `RENOVATE_TOKEN` | Renovate |

The corresponding API paths are `secret/data/apps/...`. Initial Vault setup, policy, values, and Kubernetes authentication configuration are documented **in order** in [INSTALLATION.md](../../INSTALLATION.md#6-initialize-the-cluster-vault-lxc).

For routine validation:

```bash
kubectl get sa vault-auth -n external-secrets
kubectl get clustersecretstore vault-k3s
kubectl get externalsecrets -A
```

Expected: `vault-k3s` reports `Valid / Ready=True`; both ExternalSecrets report `SecretSynced / Ready=True`. If the store is healthy but a Secret is stale, inspect the affected resource first:

```bash
kubectl describe externalsecret <name> -n <namespace>
```

To request a one-time reconciliation when appropriate:

```bash
kubectl annotate externalsecret <name> -n <namespace> force-sync="$(date +%s)" --overwrite
```

The displayed ExternalSecret ready state does **not** alone prove that a fresh sync has occurred.

## Routine operations

```bash
kubectl get nodes
kubectl get pods -A
kubectl get applications -n argocd
kubectl get clustersecretstore vault-k3s
kubectl get externalsecrets -A
```

Argo CD owns platform configuration after installation. Update declarative manifests in `applications/` or `platform/` and let GitOps reconcile the changes. Renovate runs as a CronJob and proposes dependency updates through GitHub; its token comes from Vault/External Secrets.

## Validated state and recovery limits

**26 October 2026:** The reduced platform was reconciled in place following the removal of unused services.

**2 November 2026:** After tested local/GCS recovery operations, **two k3s nodes were Ready**, **13 Argo CD Applications were Synced / Healthy**, the Vault ClusterSecretStore was **Valid / Ready=True**, and both ExternalSecrets reported **SecretSynced / Ready=True** (their last-sync timestamps were not refreshed by that check).

This confirms working cluster/platform status after recovery exercises, not a complete fresh rebuild of the current platform. Ansible's backup/restore workflows cover **k3s datastore/server token and cluster Vault storage/unseal key**, **not PVC data**. See the [Ansible backup/restore guide](../../ansible/_docs/README.md).
