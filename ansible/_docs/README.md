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

Do **not** run this command against the existing lab simply to verify the playbook: bootstrap Helm tasks and the root application can modify cluster resources. A full fresh installation has **not yet been tested**.

### Local kubeconfig

The `kubeconfig` role reads `/etc/rancher/k3s/k3s.yaml` from the controller, replaces its localhost API server address with the controller's inventory address, and writes a separate local file:

```text
~/.kube/proxmox-iac-k3s.yaml
```

This file has permission mode `0600` and does not overwrite the default `~/.kube/config`. The Traefik and Argo CD bootstrap playbooks use this kubeconfig, and the root application bootstrap sets `KUBECONFIG` to this path.

To use it manually:

```bash
KUBECONFIG="$HOME/.kube/proxmox-iac-k3s.yaml" kubectl get nodes
```

The kubeconfig contains cluster credentials: keep it outside the repository and do not commit it to Git.

### Bootstrap limitations

- The `site.yaml` flow includes Vault service installation but **does not automate Vault initialization**, initial unseal, secret creation, or creation of the `eso-read` policy.
- Vault Kubernetes authentication is excluded from ordinary Vault installation and must be configured separately **after** the required Vault and Argo CD resources exist.
- Argo CD's bootstrap Helm logic checks for an existing Helm release and skips installation when one is found. This does not prove a clean installation will succeed or prevent every ownership conflict involving existing resources.
- Once Argo CD has taken ownership of platform resources, normal updates belong in `_kubernetes/`, not the original bootstrap playbooks.

## Validation Performed (18 October 2026)

The following checks were completed on the existing lab:

- `ansible-playbook site.yaml --syntax-check` — passed.
- `ansible-playbook site.yaml --list-tasks` — loaded the expected bootstrap plays and tasks in order.
- Generated kubeconfig — tested with `kubectl get nodes`; both k3s nodes reported `Ready`.
- `ansible-playbook site.yaml --check --diff -e confirm_install=true` — completed with zero reported changes and zero failures. Some shell/command and bootstrap tasks were skipped by check mode, so this is **not** evidence of a complete installation.

Proxmox snapshots named `pre-site-test` were created for controller VM 201, worker VM 202 and Vault CT 210 before the planned rebuild exercise. Thin-pool capacity warnings were reported during snapshot creation. Snapshots are recovery points, not substitutes for independent backups, and may not provide application-consistent recovery.

**Next planned test:** a controlled rebuild of the environment from scratch, with a separately verified recovery path. This test has not been executed yet.

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

Run from `ansible/` on the Mac, using a **Vault LXC administrator token**, not the token from the separate local development Vault. Set `KUBECONFIG` so the local `kubectl` lookup uses the generated file:

```bash
read -s VAULT_TOKEN && export VAULT_TOKEN
export KUBECONFIG="$HOME/.kube/proxmox-iac-k3s.yaml"
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

**Scope:** k3s datastore and external Vault only. PVC data recovery and a full infrastructure rebuild from scratch were not tested.

## Legacy Bootstrap Playbooks

The following playbooks are retained only as legacy/bootstrap code:

```text
playbooks/cert_manager.yaml
playbooks/metallb.yaml
```

cert-manager, MetalLB, and other GitOps resources are managed from `_kubernetes/` after Argo CD takes ownership.

Do not manage GitOps-owned components with their old Ansible playbooks during normal operation.
