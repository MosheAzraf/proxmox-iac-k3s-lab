
# Ansible Layer

Project-specific notes for the Ansible bootstrap layer of `proxmox-iac-k3s-lab`.

Ansible configures the Terraform-provisioned hosts and bootstraps k3s, Vault, and the services required before Argo CD takes ownership.

## Source Of Truth

* `inventory.ini` - hosts and connection settings.
* `group_vars/all.yaml` - shared versions and configuration.
* `playbooks/` - runnable entry points.
* `roles/` - implementation.

Read these files for current addresses, versions, and component settings.

## Responsibilities

Ansible is responsible for the initial bootstrap phase.

It configures the provisioned machines, installs k3s, joins the worker node, and installs the initial platform components required before GitOps management is active.

Main responsibilities:

```text
Base host configuration
k3s controller setup
k3s worker setup
Traefik bootstrap
Argo CD bootstrap
Vault LXC configuration
Vault Kubernetes authentication for External Secrets
```

Some older playbooks are retained for rebuild or bootstrap scenarios, but ongoing platform management should happen through Argo CD and the `_kubernetes` directory.

## Prerequisites

The control machine needs Ansible, Helm, `kubectl`, an active kubeconfig, and the required Ansible collection:

```bash
ansible-galaxy collection install kubernetes.core
```

The Terraform layer should be applied before running the main Ansible playbooks.

## Run

Run commands from `ansible/`:

```bash
ansible all -m ping
ansible-playbook playbooks/common.yaml
ansible-playbook playbooks/k3s_controller.yaml
ansible-playbook playbooks/k3s_worker.yaml
ansible-playbook playbooks/traefik.yaml
ansible-playbook playbooks/argocd.yaml
ansible-playbook playbooks/vault.yaml --skip-tags vault-kubernetes-auth
```

The local Kubernetes playbooks use the current `kubectl` context.

Verify the current context before running Kubernetes-related playbooks:

```bash
kubectl config current-context
```

## Vault Kubernetes Authentication

Vault runs outside the k3s cluster in a Proxmox LXC container. External Secrets uses the Kubernetes auth method to authenticate to Vault without a permanent Vault token stored in Kubernetes.

### Configuration files

- `roles/vault/tasks/main.yaml` — installs Vault and imports the tagged Kubernetes authentication tasks.
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

Run from `ansible/` on the Mac, using a **Vault LXC administrator token**, not the token from the separate local development Vault:

```bash
read -s VAULT_TOKEN && export VAULT_TOKEN
ansible-playbook playbooks/vault.yaml --tags vault-kubernetes-auth
unset VAULT_TOKEN
```

The auth tasks read the Kubernetes CA certificate through the control machine's `kubectl` context. The Vault role is bound to the `vault-auth` ServiceAccount in `external-secrets`, with policy `eso-read` and the configured Kubernetes token audience.

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

**Scope:** k3s datastore and external Vault only. PVC data recovery and a full infrastructure rebuild from scratch were not tested.

## Legacy Bootstrap Playbooks

The following playbooks are retained only as legacy/bootstrap code:

```text
playbooks/cert_manager.yaml
playbooks/metallb.yaml
```

cert-manager, MetalLB, and other GitOps resources are managed from `_kubernetes/` after Argo CD takes ownership.

Do not manage GitOps-owned components with their old Ansible playbooks during normal operation.
