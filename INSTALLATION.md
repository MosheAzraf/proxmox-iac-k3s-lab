# Installation — Proxmox IaC K3s Lab

Follow these steps **in order** for a first-time installation. Commands are run from the repository root unless a different location is stated. The Proxmox node and networking below are the values configured in this lab; adjust Terraform and Ansible inventory for another environment.

**Do not run `terraform destroy` as part of installation.** The project is an IaC learning lab, not a fully unattended production deployment.

## 1. Prerequisites

- Proxmox VE node `pve` with `vmbr0`, `local-lvm`, Ubuntu VM template ID `9000`, and the Ubuntu 24.04 LXC template referenced by `terraform/vault-lxc`.
- Development machine with Git, Terraform, Ansible, `kubectl`, Helm, `openssl`, SSH keypair, and the `kubernetes.core` Ansible collection.
- Network/SSH access from the development machine to the provisioned guests.
- **Local development Vault** installed, initialized, unsealed, and accessible on the development machine. This Vault stores the Proxmox API credential; it is **not** the cluster Vault LXC.

```bash
ansible-galaxy collection install kubernetes.core
git clone https://github.com/MosheAzraf/proxmox-iac-k3s-lab.git
cd proxmox-iac-k3s-lab
```

## 2. Create the Proxmox API identity

Run on the **Proxmox host** as an administrator. Create the project's custom role, a dedicated user, assign the role at `/` with propagation, and create its API token:

```bash
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate SDN.Use Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.GuestAgent.Audit VM.GuestAgent.Unrestricted VM.Migrate VM.PowerMgmt"
pveum user add terraform@pam
pveum aclmod / -user terraform@pam -role TerraformProv
pveum user token add terraform@pam terraform
```

The token ID is `terraform@pam!terraform`. **Save its generated secret immediately:** it is only displayed at creation. The token and effective privileges must permit the Terraform actions defined for the lab. Never commit the secret.

## 3. Store the Proxmox token in local development Vault

Authenticate to your **local development Vault**. The following commands assume a KV v2 engine mounted at `secret/`; enable/configure that engine once if it does not already exist.

```bash
export VAULT_ADDR="http://127.0.0.1:8200"
vault login
vault kv put secret/proxmox/proxmox \
  proxmox_api_url="https://<proxmox-host>:8006/api2/json" \
  proxmox_token_id="terraform@pam!terraform" \
  proxmox_token_secret=-
```

The last field prompts for the secret on standard input. Replace the endpoint placeholder with your Proxmox address; do not paste actual credentials into Git or documentation.

Terraform reads `proxmox_api_url`, `proxmox_token_id`, and `proxmox_token_secret` from this path using an ephemeral Vault resource. Make the public SSH key available to Terraform:

```bash
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
```

## 4. Provision infrastructure with Terraform

The three Terraform roots have **separate state**:

| Root | Provisioned resources |
| --- | --- |
| `terraform/vms` | k3s controller VM 201 and worker VM 202 |
| `terraform/vault-lxc` | Cluster Vault LXC 210 |
| `terraform/gcp` | Optional GCS backup bucket, IAM, and API services |

From the repository root:

```bash
terraform -chdir=terraform/vms init
terraform -chdir=terraform/vms plan
terraform -chdir=terraform/vms apply

terraform -chdir=terraform/vault-lxc init
terraform -chdir=terraform/vault-lxc plan
terraform -chdir=terraform/vault-lxc apply
```

Review plans before approving. The default guests are `10.0.20.101`, `10.0.20.102`, and `10.0.20.110`. Keep `terraform.tfstate` and credentials outside Git. See [Terraform operations](terraform/_docs/README.md).

## 5. Bootstrap hosts and platform with Ansible

Wait for the new guests to accept SSH (especially the freshly provisioned Vault LXC). Run from `ansible/`:

```bash
cd ansible
ansible-playbook site.yaml -e confirm_install=true
```

`site.yaml` configures hosts, installs k3s controller/worker, merges the local kubeconfig, bootstraps Traefik and Argo CD, installs the cluster Vault service, and applies Argo CD's root Application. This is for **initial bootstrap**, not routine reconciliation.

Confirm Kubernetes access:

```bash
kubectl get nodes
```

Expect both nodes to be `Ready`. The local kubeconfig role uses the named context `proxmox-iac-k3s`.

## 6. Initialize the cluster Vault LXC

The cluster Vault is independent of the development-machine Vault. Initial Vault initialization, KV setup, policy, and application secret values remain manual.

Connect to the **LXC**:

```bash
ssh root@10.0.20.110
export VAULT_ADDR="http://127.0.0.1:8200"
vault status
```

On a fresh instance, initialize **once** and unseal interactively:

```bash
vault operator init -key-shares=1 -key-threshold=1
vault operator unseal
vault login
vault secrets enable -path=secret kv-v2
```

Keep the initial root token and unseal key secure and separate from the repository. These single-share and disk-based unseal arrangements are **lab-only**, not production recommendations.

Create the External Secrets read policy:

```bash
vault policy write eso-read - <<'POLICY'
path "secret/data/apps/*" {
  capabilities = ["read"]
}
path "secret/metadata/apps/*" {
  capabilities = ["list", "read"]
}
POLICY
```

Create the required KV v2 values using interactive input; do **not** put actual secret values on the command line. The two current secrets are:

| Vault CLI path | Required key |
| --- | --- |
| `secret/apps/homarr` | `db-encryption-key` |
| `secret/apps/renovate` | `RENOVATE_TOKEN` |

Use a securely generated **64-character hex** Homarr encryption key and an appropriately scoped GitHub fine-grained token for Renovate. Within the Vault LXC's Bash shell, generate and store the key **without a trailing newline**:

```bash
HOMARR_KEY="$(openssl rand -hex 32)"
printf '%s' "$HOMARR_KEY" | vault kv put secret/apps/homarr db-encryption-key=-
unset HOMARR_KEY

read -rs -p 'Renovate token: ' RENOVATE_TOKEN; echo
printf '%s' "$RENOVATE_TOKEN" | vault kv put secret/apps/renovate RENOVATE_TOKEN=-
unset RENOVATE_TOKEN
```

The lab's Ansible bootstrap installs the `vault-unseal` helper and unit, but **does not install a newly generated key automatically**. After initialization, configure the optional lab-only auto-unseal using the existing Ansible Vault role. Back on the development machine in `ansible/` (zsh):

```bash
read -rs "VAULT_UNSEAL_KEY?Vault unseal key: "; echo
ansible-playbook playbooks/vault.yaml \
  -e '{"vault_unseal_key": "'"$VAULT_UNSEAL_KEY"'"}'
unset VAULT_UNSEAL_KEY
```

Do not paste or log the key. The role writes it to `/etc/vault.d/unseal.key` on the LXC and starts the helper.  **This disk-stored key is a homelab convenience, not secure production auto-unseal.** Preserve a separate recovery copy of the original unseal key.

## 7. Bring Argo CD / GitOps into sync

Return to the development machine, in `ansible/`:

```bash
kubectl get applications -n argocd
kubectl get pods -n external-secrets
```

The root Application is created by `site.yaml` and currently has automated sync configured. Wait for GitOps to create its child Applications and External Secrets resources. If the root app remains `OutOfSync` after reviewing the issue, an operator can trigger a manual sync:

```bash
kubectl -n argocd patch application root-app --type merge -p '{"operation":{"sync":{"revision":"HEAD","prune":true}}}'
```

The manual command is a **fallback**, not a normal required installation step. The initial root Application synced during the 3 November 2026 rebuild.

## 8. Configure Vault Kubernetes authentication

After GitOps creates the `external-secrets` namespace and `vault-auth` ServiceAccount:

```bash
kubectl get sa vault-auth -n external-secrets
read -rs "VAULT_TOKEN?Cluster Vault root token: "; echo
export VAULT_TOKEN
ansible-playbook playbooks/vault.yaml --tags vault-kubernetes-auth
unset VAULT_TOKEN
```

Use the **cluster Vault administrator token**, not the development Vault credential. This configures Vault's Kubernetes auth method and the `external-secrets` Vault role using `eso-read`, without a long-lived Kubernetes Vault token.

## 9. Optional: configure encrypted GCP backups

The GCP project `proxmox-iac-k3s-lab` and billing must already exist. Install the Google Cloud CLI and authenticate on the development machine:

```bash
gcloud auth login
gcloud config set project proxmox-iac-k3s-lab
gcloud auth application-default login
gcloud auth application-default set-quota-project proxmox-iac-k3s-lab
```

From the repository root, create the bucket, `k3s/` and `vault/` prefixes, Service Account, IAM bindings, and lifecycle rule through Terraform:

```bash
terraform -chdir=terraform/gcp init
terraform -chdir=terraform/gcp plan
terraform -chdir=terraform/gcp apply
```

Grant your authenticated user impersonation of the dedicated Service Account (one-time, **repeat if that Service Account is recreated**):

```bash
gcloud iam service-accounts add-iam-policy-binding \
  ansible-backup@proxmox-iac-k3s-lab.iam.gserviceaccount.com \
  --member="user:$(gcloud auth list --filter='status:ACTIVE' --format='value(account)')" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project="proxmox-iac-k3s-lab"
```

**Create the backup encryption password once**, on the development machine. Preserve an existing password—it is required for decrypting previous backups:

```bash
test -e ~/.k3s-backup-password || (umask 077; openssl rand -base64 32 > ~/.k3s-backup-password)
```

Keep a separate secure copy of this password. No Service Account JSON key is used. Check GCP connectivity from `ansible/`:

```bash
cd ansible
ansible-playbook playbooks/gcp_connection.yaml
```

See [Ansible backup/restore commands](ansible/_docs/README.md) and [Terraform GCP notes](terraform/_docs/README.md).

## 10. Final verification

Run from the development machine with the intended Kubernetes context:

```bash
kubectl get nodes
kubectl get applications -n argocd
kubectl get clustersecretstore vault-k3s
kubectl get externalsecrets -A
```

Expected for the current reduced platform: two nodes `Ready`, all 13 Argo CD Applications `Synced / Healthy`, Vault ClusterSecretStore `Valid / Ready=True`, and two ExternalSecrets `SecretSynced / Ready=True`.

**Evidence:** all these statuses were observed on 3 November 2026 after a clean rebuild and successful encrypted GCS restores of both k3s and Vault. This was a **guided rebuild**, not a fully unattended installation: the local development Vault/API credential and the GCP project were retained, while cluster Vault initialization, application secrets, and a one-time GCP IAM impersonation binding required manual steps. On the first LXC attempt Terraform stalled and the resource was recreated successfully on retry.

## Operational guides and limits

- [Terraform](terraform/_docs/README.md) — infrastructure operations and cloud IAM.
- [Ansible](ansible/_docs/README.md) — updates, local and GCS backup/restore, and validation.
- [Kubernetes / GitOps](_kubernetes/_docs/README.md) — application reconciliation and secrets.

Backup/restore covers **k3s SQLite and server token**, plus **cluster Vault data and unseal key**; it does not recover application PVC data. Recovery steps require downtime and may not automatically roll back from every failure.
