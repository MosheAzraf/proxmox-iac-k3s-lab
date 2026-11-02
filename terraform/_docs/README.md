# Terraform — Proxmox & Google Cloud Infrastructure

Terraform provisions the homelab guests and GCP backup resources. **For first-time setup**, follow [INSTALLATION.md](../../INSTALLATION.md) in order; it includes Proxmox API user/role/token creation and storing the token in the local development Vault.

## Infrastructure roots

Each root maintains **its own Terraform state**:

| Directory | What it manages |
| --- | --- |
| `terraform/vms` | k3s Controller VM `201` (`10.0.20.101`) and Worker VM `202` (`10.0.20.102`) |
| `terraform/vault-lxc` | Cluster Vault LXC `210` (`10.0.20.110`) |
| `terraform/gcp` | GCP API services, backup bucket, prefixes, and Service Account IAM |

The VM root clones Ubuntu template ID `9000` on Proxmox node `pve`; the LXC root uses the configured Ubuntu 24.04 template. The lab defaults to `vmbr0` and `local-lvm`. Read the corresponding `*.tf` files for exact current specifications.

## Credentials and access

**Proxmox:** The Terraform roots read these three fields from **development-machine Vault** KV v2 path `secret/proxmox/proxmox`:

- `proxmox_api_url`
- `proxmox_token_id`
- `proxmox_token_secret`

The Proxmox identity is `terraform@pam` with custom role `TerraformProv`; the token ID is `terraform@pam!terraform`. The token secret is not committed or hardcoded into Terraform. The provider uses ephemeral Vault secret reads.

```bash
export VAULT_ADDR="http://127.0.0.1:8200"
vault login
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
```

**GCP:** Terraform authenticates using local Google Cloud Application Default Credentials (ADC). The Google Cloud project and billing must be created outside this Terraform root. The `ansible-backup` Service Account has bucket-scoped `roles/storage.objectCreator` and `roles/storage.objectViewer`. It does not use a JSON key.

To permit the currently authenticated user to impersonate that Service Account **after the first apply**, run:

```bash
gcloud iam service-accounts add-iam-policy-binding \
  ansible-backup@proxmox-iac-k3s-lab.iam.gserviceaccount.com \
  --member="user:$(gcloud auth list --filter='status:ACTIVE' --format='value(account)')" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project="proxmox-iac-k3s-lab"
```

The impersonation binding is intentionally managed outside Terraform so the personal email is not written into its state. Repeat the binding if the Service Account is deleted and recreated.

## Infrastructure commands

Run from the **repository root**:

```bash
terraform -chdir=terraform/vms init
terraform -chdir=terraform/vms plan
terraform -chdir=terraform/vms apply

terraform -chdir=terraform/vault-lxc init
terraform -chdir=terraform/vault-lxc plan
terraform -chdir=terraform/vault-lxc apply

terraform -chdir=terraform/gcp init
terraform -chdir=terraform/gcp plan
terraform -chdir=terraform/gcp apply
```

Apply each root only when it is needed, after reviewing the plan. `terraform fmt -check` and `terraform validate` can be run with the same `-chdir` path for a selected root.

**Destructive operation:** `terraform destroy` removes managed resources and can permanently delete guest data and local snapshots. It is **not** part of normal installation. Backups and independent recovery points are required before intentional teardown. Preserve the correct Terraform state; do not delete state to attempt a rebuild.

## GCS backup layout and retention

```text
gs://proxmox-iac-lab-backups/
├── k3s/      # Encrypted k3s backup objects
└── vault/    # Encrypted cluster Vault backup objects
```

Terraform provisions the bucket in `me-west1` with STANDARD storage, uniform bucket-level access, public access prevention, and soft delete disabled. A lifecycle rule deletes matching `.tar.gz` objects under `k3s/` and `vault/` after **30 days**. The prefixes are object names created by Terraform, not independent buckets.

The GCP root enables `iam.googleapis.com`, `iamcredentials.googleapis.com`, and `storage.googleapis.com` with API-disable-on-destroy disabled. The project's ₪30 budget alert is configured separately; it **does not automatically stop billing**.

GCP credentials on the development machine:

```bash
gcloud auth login
gcloud config set project proxmox-iac-k3s-lab
gcloud auth application-default login
gcloud auth application-default set-quota-project proxmox-iac-k3s-lab
```

## Verify

For infrastructure, review a normal `terraform plan` and confirm whether it reports expected changes or no changes. To validate GCS authentication from `ansible/`:

```bash
ansible-playbook playbooks/gcp_connection.yaml
```

For backup and restore commands, use the [Ansible operations guide](../../ansible/_docs/README.md). For cluster status, see the [GitOps guide](../../_kubernetes/_docs/README.md).

## Security and tested scope

Terraform local state/credentials must remain out of Git. Never publish the Proxmox API token, Vault tokens/unseal keys, ADC files, or state. GitGuardian monitors the GitHub repository as an additional safeguard, not a replacement for protecting secrets.

**Verified:** Proxmox infrastructure was rebuilt on **19 October 2026**. The GCP bucket, Service Account, permissions, lifecycle and backup/restore workflows were exercised by **2 November 2026**. The reduced Kubernetes platform has not undergone a new fully unattended clean rebuild.
