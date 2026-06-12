# Proxmox IaC K3s Lab

Infrastructure as Code lab project for provisioning and bootstrapping a small k3s Kubernetes cluster on Proxmox.

The goal of this project is to simulate a production-like infrastructure workflow in a home lab environment, using Terraform, Ansible, Kubernetes, GitOps, Vault, and supporting platform components.

This is a practical lab environment, not a production-ready platform.

## Stack

```text
Proxmox
Terraform
Ansible
k3s
Argo CD
Vault
External Secrets Operator
MetalLB
Traefik
cert-manager
Longhorn
CloudNativePG
kube-prometheus-stack
Grafana
Renovate
```

## Repository Layout

```text
proxmox-iac-k3s-lab/
├── terraform/        # Proxmox infrastructure
├── ansible/          # Server and cluster bootstrap
├── _kubernetes/      # GitOps layer managed by Argo CD
├── renovate.json     # Renovate configuration
└── README.md
```

## Architecture

```mermaid
flowchart TD
    A[Terraform] --> B[Proxmox VMs]
    A --> C[Vault LXC]
    B --> D[Ansible]
    C --> D
    D --> E[k3s Cluster]
    E --> F[Argo CD]
    F --> G[GitOps Platform]
    G --> H[Ingress, TLS, Storage, Monitoring, Secrets, Databases]
```

## Design Notes

Terraform is responsible for provisioning the Proxmox infrastructure.

Ansible is responsible for the initial server and cluster bootstrap.

Argo CD manages the Kubernetes platform from Git after the bootstrap phase.

Vault runs outside the Kubernetes cluster as a separate LXC container, so secrets are not tied to the cluster lifecycle.

External Secrets Operator syncs selected Vault secrets into Kubernetes.

Traefik is installed during bootstrap and provides ingress for internal services.

Renovate runs inside the cluster as a CronJob and opens controlled pull requests for Helm chart updates.

## Deployment Flow

### 1. Provision infrastructure

Terraform is split into separate states:

```text
terraform/vms        # k3s virtual machines
terraform/vault-lxc  # Vault LXC container
```

Provision the k3s virtual machines:

```sh
cd terraform/vms
terraform init
terraform plan
terraform apply
```

Provision the Vault LXC:

```sh
cd ../vault-lxc
terraform init
terraform plan
terraform apply
```

### 2. Bootstrap the cluster

Ansible is used to configure the servers and install k3s.

```sh
cd ../../ansible
ansible-playbook playbooks/common.yaml
ansible-playbook playbooks/k3s_controller.yaml
ansible-playbook playbooks/k3s_worker.yaml
```

### 3. Install bootstrap platform components

Ansible installs the initial platform components required before GitOps can fully manage the cluster.

```sh
ansible-playbook playbooks/traefik.yaml
ansible-playbook playbooks/argocd.yaml
ansible-playbook playbooks/vault.yaml
```

Additional bootstrap playbooks are available for rebuild scenarios:

```sh
ansible-playbook playbooks/cert_manager.yaml
ansible-playbook playbooks/metallb.yaml
```

After Argo CD takes over, ongoing Kubernetes platform changes should be made through the `_kubernetes` directory.

### 4. Enable GitOps management

After Argo CD is installed, apply the root application:

```sh
kubectl apply -f _kubernetes/bootstrap/root-app.yaml
```

From this point, Argo CD tracks and reconciles the Kubernetes platform configuration from Git.

## GitOps Platform

The `_kubernetes` directory manages the Kubernetes platform through Argo CD.

Current platform components include:

```text
Argo CD
MetalLB
cert-manager
External Secrets Operator
Longhorn
CloudNativePG
kube-prometheus-stack
Grafana
Homarr
pgAdmin
Renovate
```

CloudNativePG is currently installed as a database operator foundation for future workloads.

## Secrets

Secrets are not stored in Git.

Vault stores secret values, and External Secrets Operator syncs them into Kubernetes as native Kubernetes Secrets.

External Secrets uses the `ClusterSecretStore` defined under:

```text
_kubernetes/platform/external-secrets/cluster-secret-store.yaml
```

The Vault token used by External Secrets must be created manually in the `external-secrets` namespace:

```sh
kubectl create secret generic vault-token \
  --from-literal=token="$VAULT_TOKEN" \
  --namespace external-secrets
```

Detailed Vault paths and required keys are documented in the [Terraform Layer](terraform/_docs/README.md).

## Renovate

Renovate runs inside the cluster as a CronJob managed by Argo CD.

It checks Helm chart versions from the Argo CD Application manifests and opens pull requests for updates.

The repository-level Renovate configuration is stored in:

```text
renovate.json
```

The configuration is intentionally conservative so dependency updates can be reviewed and applied gradually.

## Documentation

Project-specific documentation is available for each layer:

1. [Terraform Layer](terraform/_docs/README.md)
   Project-specific notes for the Terraform infrastructure layer.

2. [Ansible Layer](ansible/_docs/README.md)
   Project-specific notes for the Ansible bootstrap layer.

3. [Kubernetes / GitOps Layer](./_kubernetes/_docs/README.md)
   Project-specific notes for the Kubernetes and GitOps layer.

## Project Scope

This project focuses on building a small production-like Kubernetes lab on top of Proxmox.

The repository covers the full infrastructure flow: provisioning virtual machines, bootstrapping a k3s cluster, installing core platform components, managing Kubernetes resources with GitOps, handling secrets with Vault, and testing a controlled dependency update workflow with Renovate.

The exact platform components may change over time as the lab evolves.

## Contributions

This is a personal lab project.

Pull requests from external contributors are not expected to be reviewed or merged.

The repository is public for learning, documentation, and portfolio purposes.
