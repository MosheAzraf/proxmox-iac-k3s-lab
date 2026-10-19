# Installation — Proxmox IaC K3s Lab

This guide documents the **actual clean rebuild tested on 19 October 2026**, including manual steps and issues encountered. It assumes a new install on an existing Proxmox host, **not** the removal of unrelated machines. Commands use repository-relative paths unless noted.

> **Safety:** `terraform destroy` deletes the managed VMs/LXC, their data, and their local snapshots. Do not run it on an environment containing data you need. For a first-time install, skip the destroy step entirely. Check the plan before any destructive action.

## 1. Prerequisites

- Proxmox VE with node `pve`, network bridge `vmbr0`, `local-lvm`, Ubuntu VM template **9000**, and LXC template `local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst` available (see [Terraform configuration](terraform/_docs/README.md)).
- Development machine with Terraform, Ansible, `kubectl`, Helm, `jq`, `openssl`, and the Ansible `kubernetes.core` collection (`ansible-galaxy collection install kubernetes.core`).
- SSH keypair; access to the provisioned hosts and Kubernetes API; Proxmox API access configured as documented in [Terraform layer](terraform/_docs/README.md).
- A **local development Vault** running on the development machine, storing the Proxmox API credentials at `secret/proxmox/proxmox`. This is **not** the cluster's Vault LXC.
- On the development machine, supply the local Vault environment and Terraform SSH key variable (adapt the public key file if needed):

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
# Supply the LOCAL development Vault token securely; do not save it to Git.
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
```

For development Vault authentication use your existing local login/session, or provide `VAULT_TOKEN` securely. The Proxmox API token must be present there **before** Terraform is used. Full API user/role setup is in the Terraform layer documentation.

## 2. Infrastructure: Terraform

Terraform uses two independent roots and states: `terraform/vms` for k3s VMs **201/202** and `terraform/vault-lxc` for Vault LXC **210**. Default networking is `10.0.20.101`, `10.0.20.102`, `10.0.20.110` (see Terraform definitions for current values).

From the repository root, initialize and create:

```bash
terraform -chdir=terraform/vms init
terraform -chdir=terraform/vault-lxc init
terraform -chdir=terraform/vms plan
terraform -chdir=terraform/vms apply
terraform -chdir=terraform/vault-lxc plan
terraform -chdir=terraform/vault-lxc apply
```

### Optional: destructive rebuild tested during the session

**Do not perform this for an initial installation.** After ensuring no data needs saving and reviewing **both** plans:

```bash
terraform -chdir=terraform/vms plan -destroy
terraform -chdir=terraform/vault-lxc plan -destroy
terraform -chdir=terraform/vms destroy
terraform -chdir=terraform/vault-lxc destroy
```

The tested destroy removed only VM IDs 201/202 and LXC ID 210, then the normal `apply` recreated all three. Never remove or overwrite Terraform state merely to rebuild resources. `terraform.tfstate` contains sensitive infrastructure information; keep it out of Git.

**Observed during recreation:** Proxmox displayed `Systemd 255 detected. You may need to enable nesting` for the LXC, but Terraform finished successfully. Treat a failing service as a separate issue rather than assuming this warning is always harmless.

## 3. Bootstrap: Ansible

Wait until the new machines finish booting and SSH is accessible, then run from `ansible/`:

```bash
cd ansible
ansible-playbook site.yaml -e confirm_install=true
```

`site.yaml` performs the confirmation gate, common node setup, k3s controller + worker, local kubeconfig, Traefik, initial Argo CD, Vault service installation, and root Application creation.

**Observed startup behavior:** An immediate run after Terraform failed with SSH `Connection refused` on both fresh VMs. After SSH became ready, a retry proceeded. The fresh Vault LXC likewise initially timed out on SSH; once reachable, re-running `site.yaml` finished successfully. If needed, wait using the inventory groups:

```bash
ansible k3s_cluster -m wait_for_connection -a 'timeout=120'
ansible vault-k3s -m wait_for_connection -a 'timeout=120'
```

The successful second run reported no changes to already installed k3s nodes. Avoid running bootstrap against a healthy running cluster merely as a test.

## 4. Local Kubernetes CLI

The `kubeconfig` Ansible role reads the new controller credentials and merges a named cluster/user/context (`proxmox-iac-k3s`) into the **standard** `~/.kube/config`, preserving differently named entries and making the lab the current context. It backs up the previous file if it changes and uses file mode `0600`.

```bash
kubectl get nodes
```

Both `k3s-controller-01` and `k3s-worker-01` should be `Ready`. On the tested rebuild, the old default kubeconfig initially failed with `x509: certificate signed by unknown authority`; refreshing the local configuration fixed this. **Note:** legacy entries with other names (including `default`) are not automatically deleted. If running only the kubeconfig role:

```bash
ansible-playbook site.yaml --tags kubeconfig -e confirm_install=true
```

The `confirm_install=true` switch remains required, even for the tagged run.

## 5. GitOps synchronization

`site.yaml` creates the Argo CD root Application using `_kubernetes/bootstrap/root-app.yaml`. **A created Application is not proof that it has synced.** During the recorded rebuild, `root-app` remained `OutOfSync / Missing`; a hard refresh did not start sync. Explicit sync was required:

```bash
kubectl -n argocd patch application root-app --type merge -p '{"operation":{"sync":{"revision":"HEAD","prune":true}}}'
```

After that, Argo CD created the child Applications, including `external-secrets`. Later the `argocd` Application itself was `OutOfSync` because its Helm bootstrap and GitOps-managed manifests did not match. After reviewing its state, the operator triggered sync:

```bash
kubectl -n argocd patch application argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'
```

Some Applications were briefly `Progressing`, then all 19 reached `Synced / Healthy`.

**Current code note:** automatic self-healing sync was **added subsequently** to both `root-app` and the `argocd` child Application. The manual patch commands above document what actually happened and serve as fallback, **not** mandatory steps for every future run. These automated changes have not yet been validated in another full rebuild. Do not force-sync Argo CD without understanding possible resource ownership changes; it can update/restart the control plane components.

## 6. Initial Vault setup — manual

Terraform creates the cluster Vault LXC and Ansible installs the Vault service. **Vault does not initialize or populate secrets automatically.** The local development Vault (used by Terraform) is entirely separate.

### 6.1 Connect and check status

```bash
ssh root@10.0.20.110
export VAULT_ADDR=http://127.0.0.1:8200
vault status
```

For a newly provisioned Vault, `Initialized: false`, `Sealed: true`, and a nonzero `vault status` exit code are expected. After recreating the LXC, SSH may warn `REMOTE HOST IDENTIFICATION HAS CHANGED!`; verify the new host fingerprint through Proxmox **before** removing the stale known-hosts entry:

```bash
ssh-keygen -R 10.0.20.110
ssh root@10.0.20.110
```

### 6.2 Initialize and unseal

Run **once** on the Vault LXC:

```bash
vault operator init -key-shares=1 -key-threshold=1
vault operator unseal
```

Record the generated unseal key and initial root token **privately**, never in shell history, public logs or repository files. The unseal command prompts for the key without echoing it. The successful unseal shows `Sealed: false`.

These one-share settings and the documented lab disk-based unseal helper are **for the homelab only**, not recommended production security design. A rebuilt instance receives fresh credentials. Previously printed tokens/keys from destroyed instances must not be reused.

### 6.3 Authenticate, enable secrets engine, and policy

Still inside the cluster Vault LXC:

```bash
export VAULT_TOKEN="$(vault login -method=token -token-only)"
vault secrets enable -path=secret kv-v2
vault policy write eso-read - <<'POLICY'
path "secret/data/apps/*" {
  capabilities = ["read"]
}
path "secret/metadata/apps/*" {
  capabilities = ["list", "read"]
}
POLICY
```

The login prompts for the **cluster Vault initial root token**. These commands are for a fresh, uninitialized Vault; enabling an already enabled secrets engine again will fail.

### 6.4 Create the three application secrets

The three actual Vault KV **CLI paths** and required keys are:

| Vault CLI path | Key | Used by |
| --- | --- | --- |
| `secret/apps/homarr` | `db-encryption-key` | Homarr |
| `secret/apps/pgadmin` | `password` | pgAdmin |
| `secret/apps/renovate` | `RENOVATE_TOKEN` | Renovate |

The Vault API paths used by External Secrets are under `secret/data/apps/...` for KV v2; the `vault kv` CLI uses `secret/apps/...`.

Generate a new Homarr encryption key securely with `openssl rand -hex 32`. Choose a pgAdmin administrator password. Create a new GitHub **fine-grained personal access token** for Renovate, scoped to **only** `MosheAzraf/proxmox-iac-k3s-lab` (repository access: *Only select repositories*). During this rebuild, it was created without an expiration date as an explicit operator choice. The permissions used in the session were:

| Repository permission | Access |
| --- | --- |
| Commit statuses | Read and write |
| Contents | Read and write |
| Dependabot alerts | Read-only |
| Issues | Read and write |
| Metadata | Read-only (required) |
| Pull requests | Read and write |
| Workflows | Read and write |

Only grant permissions you actually need; these reproduce the session's selection, not a guarantee of minimum permissions for every Renovate configuration. Keep the token private and review/revoke unused tokens periodically, especially if using *No expiration*.

Avoid putting secret values in shell commands or chat. The commands below prompt without displaying secrets and pass the values to Vault through standard input:

```bash
read -rs -p 'Homarr key: ' HOMARR_KEY; echo
printf '%s' "$HOMARR_KEY" | vault kv put secret/apps/homarr db-encryption-key=-
unset HOMARR_KEY
read -rs -p 'pgAdmin password: ' PGADMIN_PASSWORD; echo
printf '%s' "$PGADMIN_PASSWORD" | vault kv put secret/apps/pgadmin password=-
unset PGADMIN_PASSWORD
read -rs -p 'Renovate GitHub token: ' RENOVATE_TOKEN; echo
printf '%s' "$RENOVATE_TOKEN" | vault kv put secret/apps/renovate RENOVATE_TOKEN=-
unset RENOVATE_TOKEN
vault kv list secret/apps/
```

**Shell note:** These prompts use Bash (`read -rs -p`), appropriate inside the Vault LXC. In the observed session, `vault kv list` showed `homarr`, `pgadmin`, `renovate`.

## 7. Configure Vault Kubernetes authentication

The Vault auth Playbook requires the namespace, `vault-auth` ServiceAccount and TokenReview binding created by GitOps. **Do not run it before Argo CD has actually deployed them.** The first attempt in the rebuild failed because namespace `external-secrets` did not exist yet.

From your **development machine**, return to `ansible/` and confirm the ServiceAccount exists:

```bash
kubectl get sa vault-auth -n external-secrets
```

Then run (the token is from the **cluster Vault LXC**, not the local Terraform Vault):

```bash
read -s VAULT_TOKEN && export VAULT_TOKEN
ansible-playbook playbooks/vault.yaml --tags vault-kubernetes-auth
unset VAULT_TOKEN
```

The `read -s` command is deliberately silent while waiting for pasted input; press Enter after pasting the token. This configures the Kubernetes auth backend and the `external-secrets` role tied to policy `eso-read`. No static Kubernetes Vault token is required.

## 8. Verify External Secrets

```bash
kubectl get clustersecretstore vault-k3s
kubectl get externalsecrets -A
```

Expected: Store `Valid / True` and all three ExternalSecrets `SecretSynced / True`. During the test, the store was already valid while three ExternalSecrets still showed `SecretSyncedError`. After adding their Vault values, a one-time force reconciliation resolved the stale statuses:

```bash
kubectl get externalsecrets -A -o json | jq -r '.items[] | [.metadata.namespace, .metadata.name] | @tsv' | while IFS=$'\t' read -r ns name; do kubectl annotate externalsecret "$name" -n "$ns" force-sync="$(date +%s)" --overwrite; done
```

This command uses `zsh`/`bash` shell syntax and reconciles **all current** ExternalSecrets; only use if appropriate. The actual test ended with three `SecretSynced / True` results.

## 9. Final Kubernetes / GitOps verification

```bash
kubectl get nodes
kubectl get applications -n argocd
kubectl get clustersecretstore vault-k3s
kubectl get externalsecrets -A
```

**Recorded result, 19 October 2026:** both k3s nodes `Ready`, 19/19 Argo CD Applications `Synced / Healthy`, 3/3 ExternalSecrets `SecretSynced / True`, and the ClusterSecretStore `Valid / True`. The Argo CD site `argocd.home.lab` became accessible. For a newly installed Argo CD, the initial account is `admin`; retrieve the bootstrap password privately:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode; echo
```

The initial admin Secret may no longer exist after credentials are changed. Do not share the password, and change/restrict the initial admin access after setup.

## 10. Known limits and security reminders

- The **rebuild recreates infrastructure and applications, not previous application data**. The earlier tested Ansible backup/restore covers k3s SQLite state, server token and Vault storage/unseal key; **no PVC recovery**. See [Ansible DR documentation](ansible/_docs/README.md).
- The first rebuild required SSH readiness retries, manual Vault setup and manual Argo CD sync. A later code change adds Argo CD automated sync, but a second unattended fresh rebuild has not been tested.
- `~/.kube/config` is merged by the Ansible role and backed up on changes. It uses named lab entries; differently named legacy entries remain unless manually removed.
- The development Vault's Proxmox API token should never be confused with the newly created Vault LXC root token. Keep all keys/tokens out of terminal transcripts and Git. Rotate any credentials inadvertently exposed in logs or chat; do not embed unseal keys, root tokens or CLI transcripts in Proxmox container descriptions.
- If using `rsync` to apply a downloaded code update, macOS may copy `.DS_Store` files and `--backup` can create `*.bak` files. Review `git status`, and stage only intended source files.
- GCP backup integration is a **future milestone**, not a completed feature.

For configuration detail see [Terraform](terraform/_docs/README.md), [Ansible](ansible/_docs/README.md) and [GitOps](_kubernetes/_docs/README.md).
