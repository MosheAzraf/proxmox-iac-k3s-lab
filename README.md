# Proxmox IaC K3s Lab

A hands-on Infrastructure as Code homelab built on Proxmox. It demonstrates the full lifecycle of a small Kubernetes environment: provisioning, bootstrapping, GitOps reconciliation, secrets management, updates, and local disaster recovery. The project also includes an initial Google Cloud integration managed with Terraform.

**This is an infrastructure experimentation and portfolio lab, not a production-ready application hosting platform.** Its purpose is to demonstrate reproducible infrastructure, automation, and operational practices, rather than running as many services as possible.

## Architecture

| Layer | Technology | Responsibility |
| --- | --- | --- |
| Virtualization | Proxmox VE | Runs the lab hosts |
| Infrastructure | Terraform | Provisions k3s VMs and the Vault LXC; manages initial GCP project services |
| Bootstrap | Ansible | Configures hosts, installs k3s, Traefik, initial Argo CD and Vault |
| Container orchestration | k3s | Kubernetes cluster |
| GitOps | Argo CD | Reconciles platform applications from Git |
| Secrets | Vault + External Secrets Operator | Synchronizes application secrets using Kubernetes authentication |
| Secret scanning | GitGuardian | Monitors the GitHub repository for exposed secrets |
| Maintenance | Ansible + Renovate | Host/k3s updates and Helm dependency updates |
| Observability | Prometheus + Grafana | Monitors cluster infrastructure |
| Recovery | Ansible | Local backup and restore of k3s and Vault |

The project uses **two separate Vault instances**: a development-machine Vault for Terraform's Proxmox API token and a dedicated Proxmox Vault LXC for Kubernetes application secrets.

## Repository

```text
terraform/          # Proxmox VMs, Vault LXC and GCP (separate Terraform states)
ansible/            # Central bootstrap, roles, maintenance, backup/restore
_kubernetes/        # Argo CD root app, applications and platform manifests
renovate.json       # Helm/Argo CD dependency update policy
```

## GitOps-managed components

Argo CD, cert-manager, External Secrets, MetalLB, kube-prometheus-stack/Grafana, Homarr and Renovate. Traefik is bootstrapped with Ansible.

Homarr provides a simple dashboard for users who want one. Its current manifest is included in the standard Argo CD deployment; making it optional at deployment time is a possible future refinement.

## Intentional scope and simplification

This lab focuses on **infrastructure lifecycle and automation**, not operating a local production-like application stack. Each component should support a concrete scenario: provisioning, configuration, GitOps, networking, secrets, monitoring, maintenance, or recovery.

The project previously included Longhorn, CloudNativePG, pgAdmin, and Reloader. These components were removed from the GitOps manifests to reduce operational overhead and keep the architecture aligned with its actual use cases:

| Removed component | Reason |
| --- | --- |
| Longhorn | No application PVC in the reviewed manifests required Longhorn; the identified persistent workloads use Kubernetes `local-path` storage. Maintaining a separate distributed storage layer did not support the current lab goals. |
| CloudNativePG | No PostgreSQL cluster was being used by the project's applications. Running an operator without a real database workload added complexity without demonstrating an active requirement. |
| pgAdmin | With no PostgreSQL workload to manage, the administration UI and its associated Secret, ingress route, and certificate were unnecessary. |
| Reloader | No remaining workload was configured to use it; Renovate runs as a CronJob, which the installed Reloader configuration excluded. |

**Reducing unused services is an engineering decision, not a reduction in the project's technical scope.** It demonstrates the ability to evaluate dependencies, remove unjustified infrastructure, and prioritize a system that is easier to understand, rebuild, validate, and maintain.

Vault and External Secrets remain because they have real consumers, including Renovate's GitHub token and Homarr's encryption key. Homarr is retained as a convenient dashboard, without making dashboards the purpose of the lab.

The cleanup was applied to both Git and the running cluster on **26 October 2026**, including removal of the retired applications and their remaining Kubernetes resources. The running reduced platform was subsequently validated.

## What has been tested

### Reduced platform validation — 26 October 2026

- Both k3s nodes reported `Ready` (`v1.35.8+k3s1`).
- Argo CD root application and all **12 child Applications** reported `Synced / Healthy` (**13/13** in total).
- Vault was unsealed using the existing Ansible-managed `vault-unseal` systemd service after supplying its missing key file through the Vault playbook.
- The `vault-k3s` ClusterSecretStore returned to `Valid / Ready=True`.
- Homarr and Renovate ExternalSecrets both reported `SecretSynced / Ready=True`.
- Retired Longhorn, CloudNativePG, pgAdmin and Reloader applications and their namespaces were removed from the running cluster. The pgAdmin PVC and its PV were also deleted; the cleanup required manual handling of stale Longhorn webhooks/finalizers and a PVC finalizer.

This confirms **in-place GitOps reconciliation and operational cleanup** of the reduced environment, not a new clean installation or a repeat of the full disaster-recovery procedure.

### Previous clean rebuild — 19 October 2026

The following are historical results from before the component cleanup:

- Terraform **destroy and clean apply** for k3s controller VM **201**, worker VM **202**, and Vault LXC **210** (19 October 2026).
- Ansible `site.yaml` bootstrapped a fresh k3s cluster and platform services. Initial SSH readiness required retrying after the new machines finished starting.
- Local `kubectl` works through `~/.kube/config`; both nodes reached `Ready`.
- Vault was initialized and unsealed; Kubernetes auth and three initial application secrets were configured. All three ExternalSecrets reached `SecretSynced / Ready=True` **in the earlier configuration**.
- All **19 Argo CD Applications** reached `Synced / Healthy` **in the earlier configuration**.
- A separate, earlier **local backup/restore test** recovered the k3s SQLite datastore/server token and Vault data. **PVC data is not covered.**
- Terraform enabled the GCP IAM API (`iam.googleapis.com`) and Cloud Storage API (`storage.googleapis.com`) in the manually created `proxmox-iac-k3s-lab` project. A subsequent `terraform plan` returned **No changes** (26 October 2026).
- GitGuardian's GitHub integration completed its initial historical scan with no detected secret incidents and has automatic monitoring enabled.

**Important:** The successful fresh-install exercise included **manual steps** (Vault initialization, unseal, KV v2, policy, initial secrets, and Argo CD synchronization). Automated sync for the root and Argo CD Applications was added to the manifests *after* that test; a fully unattended end-to-end fresh install has **not** been demonstrated. The reduced component set has been validated in the running cluster, but has **not** yet undergone a fresh end-to-end rebuild.

## Getting started

Follow the [complete installation guide](INSTALLATION.md), including prerequisites, commands, manual bootstrap steps, troubleshooting, and final verification.

For deeper reference:

- [Terraform layer](terraform/_docs/README.md)
- [Ansible layer](ansible/_docs/README.md)
- [Kubernetes / GitOps layer](_kubernetes/_docs/README.md)

## Scope and limitations

This lab demonstrates reproducible infrastructure and platform setup, not data preservation across rebuilds. The clean rebuild discarded old application data. Vault's lab unseal helper is not a production-grade seal solution; never commit tokens, unseal keys, kubeconfigs, Terraform state or real application secrets. Local backup/restore does not include PVC data, and GCP backup is planned but not implemented. The GCP IAM API is enabled, but dedicated Service Accounts and IAM permissions have not yet been configured.

## License

MIT — see [LICENSE](LICENSE).
