# Ansible Layer

Project-specific notes for the Ansible bootstrap layer of `proxmox-iac-k3s-lab`.

Ansible configures the Terraform-provisioned hosts and bootstraps k3s, Vault, and the services required before Argo CD takes ownership.

## Source Of Truth

* `site.yaml` - central entry point for initial bootstrap.
* `inventory.ini` - hosts and connection settings.
* `group_vars/all.yaml` - shared versions and configuration.
* `playbooks/` - individual runnable entry points.
* `roles/` - implementation.

Read these files for current addresses, versions, and component settings.

## Responsibilities

Ansible is responsible for the initial bootstrap phase.

It configures the provisioned machines, installs k3s, joins the worker node, creates a local kubeconfig, and installs the initial platform components required before GitOps management is active.

Main responsibilities:

```text
Base host configuration
k3s controller setup
k3s worker setup
Local kubeconfig generation
Traefik bootstrap
Argo CD bootstrap
Vault LXC configuration
Argo CD root application bootstrap
Vault Kubernetes authentication for External Secrets (separate step)
```

Some older playbooks are retained for rebuild or bootstrap scenarios, but ongoing platform management should happen through Argo CD and the `_kubernetes` directory.

## Prerequisites

The control machine needs Ansible, Helm, `kubectl`, and the required Ansible collection:

```bash
ansible-galaxy collection install kubernetes.core
```

The Terraform layer should be applied before running Ansible. The control machine must be able to reach the provisioned hosts and the Kubernetes API.

## Central Bootstrap: `site.yaml`

Run commands from `ansible/`.

The central playbook imports the existing playbooks and runs the following in order:

1. Configure common settings on k3s nodes.
2. Install the k3s controller and join worker nodes.
3. Copy the controller's kubeconfig to the control machine.
4. Bootstrap Traefik and Argo CD.
5. Install/configure the Vault LXC service.
6. Apply the Argo CD root application to start GitOps reconciliation.

The entry point requires an explicit `confirm_install=true` variable. **It is intended for fresh installations, not routine execution against the running cluster.** Approval is not a guarantee that existing resources will be preserved.

For a planned fresh installation, after verifying backups and the target environment, the invocation is:

```bash
ansible-playbook site.yaml -e confirm_install=true
```

Do **not** run this command against an existing lab merely to test it: bootstrap tasks can modify live resources. A fresh infrastructure rebuild was completed on **19 October 2026** with manual Vault initialization, application secret provisioning, and GitOps sync. Follow the step-by-step [installation guide](../../INSTALLATION.md).

### Local kubeconfig

The `kubeconfig` role reads `/etc/rancher/k3s/k3s.yaml` from the controller, replaces the loopback API endpoint with the controller's inventory address, and merges a named `proxmox-iac-k3s` cluster, user and context into the standard `~/.kube/config` on the control machine. It selects this context, keeps differently named entries, saves mode `0600`, and makes a backup when content changes. The configuration can be used directly:

```bash
kubectl get nodes
```

On a rebuild, the earlier kubeconfig may produce `x509: certificate signed by unknown authority` until new cluster credentials are merged. Run only the kubeconfig role from `ansible/` if needed:

```bash
ansible-playbook site.yaml --tags kubeconfig -e confirm_install=true
```

This merge does **not** delete older entries with a different name (such as `default`), even if they belong to the previously destroyed cluster. Preserve unrelated contexts deliberately. The kubeconfig contains credentials; never commit it.

The bootstrap playbooks and root-app bootstrap now use `~/.kube/config`.

### Bootstrap limitations

- The `site.yaml` flow includes Vault service installation but **does not automate Vault initialization**, initial unseal, secret creation, or creation of the `eso-read` policy.
- Vault Kubernetes authentication is excluded from ordinary Vault installation and must be configured separately **after** the required Vault and Argo CD resources exist.
- Argo CD bootstrap checks for an existing Helm release and skips reinstallation. GitOps later reconciles the Argo CD Application itself; automatic sync was added after the recorded rebuild and has not been revalidated in another fresh rebuild.
- Once Argo CD has taken ownership of platform resources, normal updates belong in `_kubernetes/`, not the original bootstrap playbooks.

## Validation Performed (18 October 2026)

The following checks were completed on the existing lab:

- `ansible-playbook site.yaml --syntax-check` — passed.
- `ansible-playbook site.yaml --list-tasks` — loaded the expected bootstrap plays and tasks in order.
- Generated kubeconfig — tested with `kubectl get nodes`; both k3s nodes reported `Ready`.
- `ansible-playbook site.yaml --check --diff -e confirm_install=true` — completed with zero reported changes and zero failures. Some shell/command and bootstrap tasks were skipped by check mode, so this is **not** evidence of a complete installation.

Proxmox snapshots named `pre-site-test` were created for controller VM 201, worker VM 202 and Vault CT 210 before the planned rebuild exercise. Thin-pool capacity warnings were reported during snapshot creation. Snapshots are recovery points, not substitutes for independent backups, and may not provide application-consistent recovery.

**19 October 2026:** Terraform destroyed and recreated VMs `201`, `202` and Vault LXC `210`; `site.yaml` completed after initial SSH readiness retries. Vault was initialized and configured manually, GitOps was explicitly synced, both nodes became `Ready`, all 19 Argo CD Applications reached `Synced / Healthy`, and three ExternalSecrets reported `SecretSynced / True`. This was a clean rebuild, **not** a restoration of prior application data or PVCs. Full steps and errors: [INSTALLATION.md](../../INSTALLATION.md).

## Vault Kubernetes Authentication

Vault runs outside the k3s cluster in a Proxmox LXC container. External Secrets uses the Kubernetes auth method to authenticate to Vault without a permanent Vault token stored in Kubernetes.

### Configuration files

- `roles/vault/tasks/main.yaml` — installs Vault and imports the tagged Kubernetes authentication tasks, excluded by default with `never`.
- `roles/vault/tasks/kubernetes-auth.yaml` — enables the Kubernetes auth method, configures the Kubernetes API and cluster CA certificate, and creates the `external-secrets` Vault role.
- `group_vars/all.yaml` — supplies the Kubernetes API address, Vault role, namespace, ServiceAccount, policy and audience.
- `playbooks/vault.yaml` — obtains the Vault administrator token from the local `VAULT_TOKEN` environment variable.
- `_kubernetes/platform/external-secrets/vault-auth.yaml` — GitOps-managed ServiceAccount and TokenReview ClusterRoleBinding.
- `_kubernetes/platform/external-secrets/cluster-secret-store.yaml` — references the Vault Kubernetes auth role.

### Initial manual prerequisites

A fresh Vault LXC requires one-time operator setup before running these auth tasks:

1. Initialize and unseal Vault; securely retain the administrator token and unseal key, outside the repository.
2. Ensure the `secret` KV v2 engine is enabled and create the application's secret entries in Vault.
3. Create the `eso-read` Vault policy (the current playbook **uses** this policy but does not create it).
4. Install Argo CD, apply the root application, and wait for Argo CD to deploy the `vault-auth` ServiceAccount in `external-secrets`.
5. Ensure the control machine's `kubectl` context points to the correct k3s cluster and Vault LXC can reach its Kubernetes API.

Required Vault policy:

```hcl
path "secret/data/apps/*" {
  capabilities = ["read"]
}

path "secret/metadata/apps/*" {
  capabilities = ["list", "read"]
}
```

The lab's disk-based unseal helper in `roles/vault/` is a convenience for a local learning environment, **not** a production security mechanism.

### Configure through Ansible

Run from `ansible/` on the control machine, using a **Vault LXC administrator token**, not the token from the separate local development Vault. The kubeconfig role sets the current context in `~/.kube/config`:

```bash
read -s VAULT_TOKEN && export VAULT_TOKEN
ansible-playbook playbooks/vault.yaml --tags vault-kubernetes-auth
unset VAULT_TOKEN
```

Run this only when the prerequisites above are met. The auth tasks read the Kubernetes CA certificate through the control machine's `kubectl` context. The Vault role is bound to the `vault-auth` ServiceAccount in `external-secrets`, with policy `eso-read` and the configured Kubernetes token audience.

After the initial setup, External Secrets obtains short-lived Vault tokens by authenticating with Kubernetes ServiceAccount credentials. There is no ongoing manual Vault token renewal. The initial Vault setup, administrator credential supply and application secret creation are **not yet unattended**.

### Verify

```bash
kubectl get sa vault-auth -n external-secrets
kubectl get clustersecretstore vault-k3s
kubectl get externalsecrets -A
```

The store should report `Valid` / `Ready=True` and the secrets should report `SecretSynced` / `Ready=True`.

## Backup and Disaster Recovery

Backups cover the k3s controller's SQLite datastore and server token, plus the external Vault LXC's file storage and unseal key. **Application PVC data is not included.**

### Backup

Run from `ansible/`:

```bash
ansible-playbook playbooks/backup.yaml
```

Backups are saved to `~/k3s-backups/` on the control machine:

- `k3s-backup.tar.gz` — k3s SQLite datastore and server token (not encrypted).
- `vault-backup.tar.gz` — Vault file storage and unseal key, encrypted with Ansible Vault.

Keep `~/.k3s-backup-password` secure and separate from the backups. Do not commit backups, tokens or encryption passwords to Git.

### Restore

Run from `ansible/` after confirming the local backups are available and taking Proxmox snapshots or equivalent independent recovery points:

In the tested workflow, Proxmox snapshots were created **before updating** k3s (`before-updates-2026-10-05` on VMs 201 and 202) and **before restoring** (`pre-restore` on VMs 201 and 202 and Vault CT 210). Snapshots were not a step performed before the backup command itself.

```bash
ansible-playbook playbooks/restore.yaml --syntax-check
ansible-playbook playbooks/restore.yaml -e confirm_restore=true
```

The restore temporarily stops the k3s worker, controller and Vault services as needed, preserves existing server data using `.pre-restore` paths, and attempts rollback on task failures. Rollback is **not guaranteed** for every failure; the restore also requires downtime.

### Verification

```bash
kubectl get nodes
kubectl get applications -n argocd
kubectl get clustersecretstore vault-k3s
kubectl get externalsecrets -A
```

A real restore was successfully executed on the existing lab: both nodes returned to `Ready`, all 19 Argo CD applications reported `Synced / Healthy`, and all three ExternalSecrets reported `SecretSynced / Ready=True` when checked. The ExternalSecrets last-sync timestamps were not refreshed during that check.

**Scope:** k3s datastore and external Vault only; PVC data recovery has not been tested. A **separate clean infrastructure rebuild** was successfully performed on 19 October 2026, without restoring the prior application data.

## Legacy Bootstrap Playbooks

The following playbooks are retained only as legacy/bootstrap code:

```text
playbooks/cert_manager.yaml
playbooks/metallb.yaml
```

cert-manager, MetalLB, and other GitOps resources are managed from `_kubernetes/` after Argo CD takes ownership.

Do not manage GitOps-owned components with their old Ansible playbooks during normal operation.
