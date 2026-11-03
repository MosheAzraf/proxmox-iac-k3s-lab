# Ansible — Bootstrap, Maintenance & Recovery

Ansible configures the Proxmox-provisioned hosts, bootstraps k3s/Vault/Argo CD, performs updates, and provides **separate local and GCP backup/restore workflows**.

For first-time setup, follow [INSTALLATION.md](../../INSTALLATION.md). **All commands below run from `ansible/`** unless stated otherwise.

## Organization

- `site.yaml` — initial infrastructure/platform bootstrap, guarded by `confirm_install=true`.
- `inventory.ini` and `group_vars/all.yaml` — nodes, settings, and version pins.
- `playbooks/` — task entry points; `roles/` — implementations.
- `_kubernetes/` — Argo CD's source of truth after bootstrap; do not use bootstrap roles for routine application management.

## Bootstrap and updates

```bash
# Initial installation ONLY (requires Terraform guests to exist)
ansible-playbook site.yaml -e confirm_install=true

# Existing update playbooks
ansible-playbook playbooks/update_k3s.yaml
ansible-playbook playbooks/update_vault.yaml
```

`update_vault_version` in `group_vars/all.yaml` selects the desired Vault package version. The update role restarts Vault and its lab unseal service only if the package changes, then checks status/version. **Vault 1.21.2 → 1.21.4 was successfully tested on 2 November 2026.** The pinned `vault_version` value belongs to initial installation.

`update_k3s_version` in `group_vars/all.yaml` controls the k3s update target. Do not rerun `site.yaml` as an update mechanism.

## Backup coverage and security

| System | Included | Excluded |
| --- | --- | --- |
| k3s | Controller SQLite datastore and server token | PVC contents and external Vault data |
| Vault LXC | File-based Vault data and unseal key | Development-machine Vault and application PVCs |

Local k3s backup is an unencrypted archive. **Local Vault backup and both GCP backups are encrypted with Ansible Vault.** The password file `~/.k3s-backup-password` must be securely preserved independently of backups. Create it only once, if missing:

```bash
test -e ~/.k3s-backup-password || (umask 077; openssl rand -base64 32 > ~/.k3s-backup-password)
```

Backups stop and restart the relevant service for a consistent archive. Perform restores only against the intended lab and maintain an independent recovery point (such as a Proxmox snapshot).

## Local backup

```bash
ansible-playbook playbooks/backup_k3s_local.yaml
ansible-playbook playbooks/backup_vault_local.yaml
```

Backups are saved on the development machine under `~/k3s-backups/` as `k3s-backup.tar.gz` and encrypted `vault-backup.tar.gz`. Subsequent runs overwrite these local filenames; copy them securely elsewhere if previous generations are needed.

## Local restore

**Both restore playbooks replace live service data and require explicit confirmation.** Run independently:

```bash
ansible-playbook playbooks/restore_k3s_local.yaml -e confirm_restore=true
ansible-playbook playbooks/restore_vault_local.yaml -e confirm_restore=true
```

A restore preserves the prior data in `*.pre-restore` locations for attempted rollback. It will refuse to run again while those files exist. Only remove them **after independently confirming the restored services work**. See the cleanup commands below.

## GCP setup and connection

GCS backups use a Terraform-managed bucket, dedicated `ansible-backup` Service Account, and **Service Account Impersonation**—not JSON keys. Complete the one-time GCP Terraform, impersonation permission, and password setup in [INSTALLATION.md](../../INSTALLATION.md#9-optional-configure-encrypted-gcp-backups).

```bash
ansible-playbook playbooks/gcp_connection.yaml
```

## GCP backup

```bash
ansible-playbook playbooks/backup_k3s_gcp.yaml
ansible-playbook playbooks/backup_vault_gcp.yaml
```

Each playbook archives its own service, encrypts the archive using Ansible Vault, uploads a timestamped object, and removes temporary files. Objects are stored under:

- `gs://proxmox-iac-lab-backups/k3s/`
- `gs://proxmox-iac-lab-backups/vault/`

Terraform configures deletion of matching `.tar.gz` backups after **30 days**. This is an automatic deletion rule, not a retention guarantee.

## GCP restore

**Choose the exact backup object** to recover. The roles require `confirm_restore=true`, restrict the object URI to the correct service's GCS prefix and timestamped filename, and verify decryption/archive integrity **before** stopping the service.

First list available objects:

```bash
gcloud storage ls gs://proxmox-iac-lab-backups/k3s/ --impersonate-service-account=ansible-backup@proxmox-iac-k3s-lab.iam.gserviceaccount.com
gcloud storage ls gs://proxmox-iac-lab-backups/vault/ --impersonate-service-account=ansible-backup@proxmox-iac-k3s-lab.iam.gserviceaccount.com
```

Select an object and substitute it below:

```bash
ansible-playbook playbooks/restore_k3s_gcp.yaml \
  -e confirm_restore=true \
  -e gcp_backup_object=gs://proxmox-iac-lab-backups/k3s/k3s-backup-<YYYYMMDDTHHMMSSZ>.tar.gz

ansible-playbook playbooks/restore_vault_gcp.yaml \
  -e confirm_restore=true \
  -e gcp_backup_object=gs://proxmox-iac-lab-backups/vault/vault-backup-<YYYYMMDDTHHMMSSZ>.tar.gz
```

The date-shaped filename placeholders are examples, not literal valid paths. **Do not paste a placeholder command without selecting a real backup.** Both operations cause service downtime. Rollback is attempted on failure but is not guaranteed in every scenario.

## Verify recovery

```bash
kubectl get nodes
kubectl get applications -n argocd
kubectl get clustersecretstore vault-k3s
kubectl get externalsecrets -A
ssh root@10.0.20.110 "VAULT_ADDR=http://127.0.0.1:8200 vault status"
```

`vault status` returns success when Vault is initialized and unsealed; keep its administrator credentials private. The ExternalSecrets `Ready=True` status is useful but does not alone prove that a new secret sync occurred after recovery.

### Remove restore leftovers after successful validation

Only if corresponding restore files exist and the restored services have been verified:

```bash
ansible controllers -b -m ansible.builtin.file -a "path=/var/lib/rancher/k3s/server/db.pre-restore state=absent"
ansible controllers -b -m ansible.builtin.file -a "path=/var/lib/rancher/k3s/server/token.pre-restore state=absent"
ansible vault -b -m ansible.builtin.file -a "path=/opt/vault/data.pre-restore state=absent"
ansible vault -b -m ansible.builtin.file -a "path=/etc/vault.d/unseal.key.pre-restore state=absent"
```

## Verified recovery results — 2 November 2026

| Workflow | Evidence |
| --- | --- |
| Local k3s backup / restore | Backup `ok=9 failed=0`; restore `ok=19 failed=0`; node readiness check passed |
| Local Vault backup / restore | Backup `ok=14 failed=0`; restore `ok=18 failed=0`; Vault status passed |
| GCP k3s backup / restore | Encrypted upload verified; restore `ok=21 failed=0`; node readiness passed |
| GCP Vault backup / restore | Backup `ok=12 failed=0`; restore `ok=23 failed=0`; Vault unseal/status passed |

After GCP recovery, both nodes were `Ready`, all 13 Argo CD Applications `Synced / Healthy`, Vault ClusterSecretStore `Valid / Ready=True`, and the two ExternalSecrets `SecretSynced / Ready=True`. This is evidence of successful **in-place recovery**, not a production DR test or PVC data recovery.

## Verified clean rebuild and GCS recovery — 3 November 2026

After Terraform recreated the Proxmox guests and nine GCP resources, Ansible bootstrapped k3s, Traefik, Argo CD, and Vault. Initial host SSH readiness required a second `site.yaml` run. Cluster Vault was initialized and unsealed manually, then the lab auto-unseal helper was configured by Ansible.

| Workflow | Observed result |
| --- | --- |
| k3s encrypted GCS backup | `ok=11 failed=0` |
| Vault encrypted GCS backup | `ok=12 failed=0` |
| k3s GCS restore | `ok=23 failed=0`; both nodes Ready |
| Vault GCS restore | `ok=23 failed=0`; Vault status passed |

**Post-restore validation:** both nodes `Ready`; all 13 Argo CD Applications `Synced / Healthy`; Vault ClusterSecretStore `Valid / Ready=True`; Homarr and Renovate ExternalSecrets `SecretSynced / Ready=True`.

During the run, the k3s GCS restore role's malformed/duplicated YAML was repaired and the corrected playbook was syntax-checked before the successful restore. Homarr initially failed with an invalid encryption key containing a trailing newline; a 64-character key without the newline restored startup. Its embedded Redis cache also required a recovery/restart before the application could be used. Neither CloudNativePG nor a separate Redis service was added.

The GCP project's creation, development-machine Vault and Proxmox API credential were **not** recreated during this run; GCP Service Account impersonation was granted again after its recreation. This was a guided rebuild, not a fully unattended deployment. The post-restore ExternalSecrets status confirms readiness but does not by itself prove a new sync after restore.

**Restore leftovers:** the successful restore playbooks retain `*.pre-restore` copies for rollback. After verifying recovery, use the cleanup commands above before attempting another restore.

## Limitations

Recovery is scoped to the state above, **not PVCs** or a fully automated site rebuild. The local unseal helper is for the lab only. Protect all archive passwords, Vault keys, tokens, and Terraform/Kubernetes credentials; never commit them.
