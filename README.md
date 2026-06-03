# Proxmox IaC K3s Lab

Infrastructure as Code lab project for provisioning and bootstrapping a small k3s cluster on Proxmox.

The goal of this project is to simulate a production-like infrastructure workflow in a home lab environment, using Terraform, Ansible, Kubernetes, and GitOps.

## Stack

```text
Proxmox
Terraform
Ansible
k3s
Argo CD
Vault
Kubernetes platform components
```

## Repository Layout

```text
proxmox-iac-k3s-lab/
├── terraform/        # Proxmox infrastructure
├── ansible/          # Server and cluster bootstrap
├── _kubernetes/      # GitOps layer managed by Argo CD
└── README.md
```

## How It Works

```text
Terraform
   ↓
Proxmox virtual machines
   ↓
Ansible
   ↓
k3s cluster bootstrap
   ↓
Argo CD
   ↓
GitOps-managed Kubernetes platform
```

## Deployment Flow

### 1. Provision infrastructure

Terraform is used to create the Proxmox virtual machines and supporting infrastructure.

```sh
cd terraform
terraform init
terraform plan
terraform apply
```

### 2. Bootstrap the cluster

Ansible is used to configure the servers and install k3s.

```sh
cd ansible
ansible-playbook playbooks/common.yaml
ansible-playbook playbooks/k3s_controller.yaml
ansible-playbook playbooks/k3s_worker.yaml
```

### 3. Install initial platform components

Ansible is also used to install the initial platform components required before GitOps can fully manage the cluster.

```sh
ansible-playbook playbooks/metallb.yaml
ansible-playbook playbooks/traefik.yaml
ansible-playbook playbooks/argocd.yaml
ansible-playbook playbooks/vault.yaml
```

### 4. Enable GitOps management

After Argo CD is installed, the Kubernetes platform is managed from the `_kubernetes` directory.

```sh
kubectl apply -f _kubernetes/bootstrap/root-app.yaml
```

From this point, Argo CD tracks and reconciles the Kubernetes platform configuration from Git.

## Documentation

1. [Terraform](terraform/_docs/README.md)
   Infrastructure provisioning layer.

2. [Ansible](ansible/_docs/README.md)
   Server and cluster bootstrap layer.

3. [Kubernetes / GitOps](./_kubernetes/_docs/README.md)
   Kubernetes platform and GitOps layer.

## Project Scope

This project focuses on building a small production-like Kubernetes lab on top of Proxmox.

The repository covers the full infrastructure flow: provisioning virtual machines, bootstrapping a k3s cluster, installing core platform components, and managing Kubernetes resources with GitOps.

The exact platform components may change over time as the lab evolves.
