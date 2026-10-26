# Terraform Layer

Project-specific notes for the Terraform infrastructure layer of `proxmox-iac-k3s-lab`.

Terraform provisions the Proxmox infrastructure consumed by the rest of the project.

The Terraform layer is split into three separate roots:

```text
terraform/vms
terraform/vault-lxc
terraform/gcp
```

This keeps the k3s virtual machines, Vault LXC container, and Google Cloud resources in separate Terraform states.

## Source Of Truth

`terraform/vms` manages the k3s virtual machines.

Main files:

```text
providers.tf
variables.tf
vm.tf
outputs.tf
```

`terraform/vault-lxc` manages the Vault LXC container.

Main files:

```text
providers.tf
variables.tf
vault_lxc.tf
```

`terraform/gcp` manages Google Cloud resources for the homelab integration.

Main files:

```text
provider.tf
main.tf
.terraform.lock.hcl
```

Read the Terraform files for the current resource configuration.

## Terraform Roots

### k3s Virtual Machines

Current VM layout:

| Name                | VM ID | IP address       | CPU       | Memory     | Disk     | Purpose        |
| ------------------- | ----- | ---------------- | --------- | ---------- | -------- | -------------- |
| `k3s-controller-01` | `201` | `10.0.20.101/24` | `4` cores | `8192 MB`  | `150 GB` | k3s controller |
| `k3s-worker-01`     | `202` | `10.0.20.102/24` | `4` cores | `16384 MB` | `150 GB` | k3s worker     |

Common VM settings:

| Setting          | Value       |
| ---------------- | ----------- |
| Proxmox node     | `pve`       |
| Gateway          | `10.0.20.1` |
| Network bridge   | `vmbr0`     |
| Template ID      | `9000`      |
| User             | `ubuntu`    |
| QEMU guest agent | Enabled     |
| Start on boot    | Enabled     |

### Vault LXC

Current Vault LXC layout:

| Name    | VM ID | IP address       | CPU       | Memory    | Disk    | Purpose      |
| ------- | ----- | ---------------- | --------- | --------- | ------- | ------------ |
| `vault` | `210` | `10.0.20.110/24` | `2` cores | `2048 MB` | `20 GB` | Vault server |

Common LXC settings:

| Setting                | Value        |
| ---------------------- | ------------ |
| Proxmox node           | `pve`        |
| Gateway                | `10.0.20.1`  |
| OS                     | Ubuntu 24.04 |
| Unprivileged container | Enabled      |

### Google Cloud (GCP)

The GCP project was created manually in the Google Cloud Console. Terraform manages resources inside that project, independently from the Proxmox Terraform roots.

| Setting         | Value                  |
| --------------- | ---------------------- |
| Project ID      | `proxmox-iac-k3s-lab`  |
| Organization    | `mosheaz-dev-org`      |
| Default region  | `me-west1`             |
| Authentication  | Local Google Cloud ADC |
| Terraform state | Local, excluded from Git |

`provider.tf` configures `hashicorp/google` (`~> 7.0`) and the project/region. The initial setup installed Google Provider `7.46.2`.

`main.tf` currently enables these project APIs using `google_project_service`:

| API | Purpose |
| --- | ------- |
| `iam.googleapis.com` | Identity and Access Management API |
| `storage.googleapis.com` | Cloud Storage API |

The resources use `disable_on_destroy = false` so that Terraform does not disable those APIs when the corresponding resources are removed from state or destroyed.

**Verified on 26 October 2026:** `terraform init`, `terraform validate`, and `terraform apply` succeeded; the apply enabled both APIs (`2 added, 0 changed, 0 destroyed`). A subsequent `terraform plan` reported **No changes**.

**Scope of IAM work:** The IAM API is enabled, but Terraform-managed Service Accounts, IAM role bindings, and least-privilege access have **not** been configured yet.

#### GCP security and cost controls

- The GCP project was created manually under the organization and linked to the existing billing account.
- The legacy organization policy `iam.disableServiceAccountKeyCreation` appeared **Active** in the Console. The managed successor policy appeared **Inactive**; no policy modifications were made during this session.
- Local Terraform authentication uses Application Default Credentials (ADC), without Service Account key files.
- A project-scoped monthly **₪30 budget with email alerts** was set up (50%, 90%, 100%). This budget **does not stop charges automatically**.
- GitGuardian's GitHub integration was enabled on the main repository. The initial historical scan showed no detected incidents, and automatic monitoring was enabled. This is an additional secret-detection control, not a replacement for proper secrets management.
- The GCP Terraform root uses local state. State files and variable files containing secrets are ignored by the repository `.gitignore`; `.terraform.lock.hcl` remains version-controlled.

Cloud Storage buckets, backup integration, Service Accounts, and IAM permissions are planned for later sessions; they have not been provisioned by this Terraform root yet.

## Prerequisites

Before running Terraform, the following must be available:

```text
Proxmox API user and token
Local development Vault instance
SSH public key for the provisioned machines
```

Terraform reads the Proxmox API token from a local development Vault instance.

The Proxmox token is not stored in Git.

For the GCP Terraform root, the GCP project must already exist, billing must be configured, and Google Cloud CLI authentication and ADC must be available locally.

Authenticate and select the project:

```bash
gcloud auth login
gcloud config set project proxmox-iac-k3s-lab
gcloud auth application-default login
gcloud auth application-default set-quota-project proxmox-iac-k3s-lab
```

`gcloud auth application-default login` is only needed if ADC credentials are not already present. Do not commit the local ADC credentials file.

## Vault Instances

This project uses two separate Vault instances:

| Vault instance          | Location              | Purpose                                                                 |
| ----------------------- | --------------------- | ----------------------------------------------------------------------- |
| Local development Vault | Development machine   | Stores the Proxmox API token used by Terraform                          |
| Kubernetes Vault LXC    | Proxmox LXC container | Stores Kubernetes application secrets used by External Secrets Operator |

The local development Vault must exist before running Terraform.

The Kubernetes Vault LXC is created by Terraform and later configured by Ansible.

## Proxmox API Setup

Terraform uses a dedicated Proxmox API user and token.

Current Proxmox permission model:

| Setting   | Value           |
| --------- | --------------- |
| User      | `terraform@pam` |
| Role      | `TerraformProv` |
| Path      | `/`             |
| Propagate | Enabled         |

Run the following commands on the Proxmox host.

Create the custom Terraform role:

```bash
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate SDN.Use Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.GuestAgent.Audit VM.GuestAgent.Unrestricted VM.Migrate VM.PowerMgmt"
```

Create the dedicated Terraform user:

```bash
pveum user add terraform@pam
```

Assign the role at the Datacenter root path with propagation enabled:

```bash
pveum aclmod / -user terraform@pam -role TerraformProv
```

Create an API token for the Terraform user:

```bash
pveum user token add terraform@pam terraform
```

The token ID will be:

```text
terraform@pam!terraform
```

Copy the generated token secret when it is created.

The token secret is shown only once.

The custom `TerraformProv` role allows Terraform to create, clone, configure, power-manage, migrate, and audit the required Proxmox resources for this lab.

## Local Vault Secret

Terraform authenticates to Vault through the standard Vault environment variables.

Example:

```bash
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="<local-vault-token>"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
```

The Proxmox API token must be stored in the local development Vault under:

```text
secret/proxmox/proxmox
```

Expected keys:

| Key                    | Purpose                  |
| ---------------------- | ------------------------ |
| `proxmox_api_url`      | Proxmox API URL          |
| `proxmox_token_id`     | Proxmox API token ID     |
| `proxmox_token_secret` | Proxmox API token secret |

Store the token in Vault:

```bash
vault kv put secret/proxmox/proxmox \
  proxmox_api_url="https://<proxmox-host>:8006/api2/json" \
  proxmox_token_id="terraform@pam!terraform" \
  proxmox_token_secret="<token-secret>"
```

In the Vault UI, this secret is stored under:

```text
Vault
Secrets engines
secret
proxmox
proxmox
```

The secret should contain:

```text
proxmox_api_url
proxmox_token_id
proxmox_token_secret
```

Kubernetes application secrets are documented in the [Kubernetes / GitOps Layer](../../_kubernetes/_docs/README.md).

## Tested fresh rebuild

On 19 October 2026, the two Terraform roots were used to destroy and recreate the k3s VMs (`201`, `202`) and Vault LXC (`210`). Both `destroy` and subsequent `apply` completed successfully. VM template `9000`, LXC Ubuntu template, Proxmox API access, local **development** Vault and SSH public key are prerequisites and were not destroyed. Run `plan -destroy` and review the exact resources before a deliberate teardown; deleting a guest also removes its guest-local snapshots. **Do not destroy the infrastructure just to perform an initial installation.**

The full [initial installation and optional destructive rebuild procedure](../../INSTALLATION.md) includes the post-Terraform SSH readiness delay and Ansible bootstrap.

## Run

Run commands from the repository root.

For the k3s virtual machines:

```bash
terraform -chdir=terraform/vms init
terraform -chdir=terraform/vms fmt -check
terraform -chdir=terraform/vms validate
terraform -chdir=terraform/vms plan
terraform -chdir=terraform/vms apply
```

For the Vault LXC container:

```bash
terraform -chdir=terraform/vault-lxc init
terraform -chdir=terraform/vault-lxc fmt -check
terraform -chdir=terraform/vault-lxc validate
terraform -chdir=terraform/vault-lxc plan
terraform -chdir=terraform/vault-lxc apply
```

For Google Cloud:

```bash
terraform -chdir=terraform/gcp init
terraform -chdir=terraform/gcp fmt -check
terraform -chdir=terraform/gcp validate
terraform -chdir=terraform/gcp plan
terraform -chdir=terraform/gcp apply
```

Review every plan before applying it.

Do not commit credentials, Vault tokens, Proxmox API tokens, local variable files, `.terraform/`, or Terraform state files.
