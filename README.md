# Proxmox IaC K3s Lab

A hands-on Infrastructure as Code homelab built on Proxmox. It demonstrates the full lifecycle of a small Kubernetes environment: provisioning, bootstrapping, GitOps reconciliation, secrets management, updates, and local disaster recovery.

**This is a learning and portfolio lab, not a production-ready platform.**

## Architecture

| Layer | Technology | Responsibility |
| --- | --- | --- |
| Virtualization | Proxmox VE | Runs the lab hosts |
| Infrastructure | Terraform | Provisions k3s VMs and the Vault LXC |
| Bootstrap | Ansible | Configures hosts, installs k3s, Traefik, initial Argo CD and Vault |
| Container orchestration | k3s | Kubernetes cluster |
| GitOps | Argo CD | Reconciles platform applications from Git |
| Secrets | Vault + External Secrets Operator | Synchronizes application secrets using Kubernetes authentication |
| Maintenance | Ansible + Renovate | Host/k3s updates and Helm dependency updates |
| Recovery | Ansible | Local backup and restore of k3s and Vault |

The project uses **two separate Vault instances**: a development-machine Vault for Terraform's Proxmox API token and a dedicated Proxmox Vault LXC for Kubernetes application secrets.

## Repository

```text
terraform/          # Proxmox VMs and Vault LXC (separate Terraform states)
ansible/            # Central bootstrap, roles, maintenance, backup/restore
_kubernetes/        # Argo CD root app, applications and platform manifests
renovate.json       # Helm/Argo CD dependency update policy
```

## GitOps-managed components

Argo CD, cert-manager, External Secrets, MetalLB, Longhorn, CloudNativePG, kube-prometheus-stack/Grafana, Homarr, pgAdmin, Renovate and Reloader. Traefik is bootstrapped with Ansible.

## What has been tested

- Terraform **destroy and clean apply** for k3s controller VM **201**, worker VM **202**, and Vault LXC **210** (19 October 2026).
- Ansible `site.yaml` bootstrapped a fresh k3s cluster and platform services. Initial SSH readiness required retrying after the new machines finished starting.
- Local `kubectl` works through `~/.kube/config`; both nodes reached `Ready`.
- Vault was initialized and unsealed; Kubernetes auth and three initial application secrets were configured. All three ExternalSecrets reached `SecretSynced / Ready=True`.
- All **19 Argo CD Applications** reached `Synced / Healthy` after GitOps synchronization.
- A separate, earlier **local backup/restore test** recovered the k3s SQLite datastore/server token and Vault data. **PVC data is not covered.**

**Important:** The successful fresh-install exercise included **manual steps** (Vault initialization, unseal, KV v2, policy, initial secrets, and Argo CD synchronization). Automated sync for the root and Argo CD Applications was added to the manifests *after* that test; a fully unattended end-to-end fresh install has **not** been demonstrated.

## Getting started

Follow the [complete installation guide](INSTALLATION.md), including prerequisites, commands, manual bootstrap steps, troubleshooting, and final verification.

For deeper reference:

- [Terraform layer](terraform/_docs/README.md)
- [Ansible layer](ansible/_docs/README.md)
- [Kubernetes / GitOps layer](_kubernetes/_docs/README.md)

## Scope and limitations

This lab demonstrates reproducible infrastructure and platform setup, not data preservation across rebuilds. The clean rebuild discarded old application data. Vault's lab unseal helper is not a production-grade seal solution; never commit tokens, unseal keys, kubeconfigs, Terraform state or real application secrets. Local backup/restore does not include PVC data, and GCP backup is planned but not implemented.

## License

MIT — see [LICENSE](LICENSE).
