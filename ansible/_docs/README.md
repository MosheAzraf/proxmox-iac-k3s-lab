# Ansible Layer

Project-specific notes for the Ansible bootstrap layer of `proxmox-iac-k3s-lab`.

Ansible configures the Terraform-provisioned hosts and bootstraps k3s, Vault, and the services required before Argo CD takes ownership.

## Source Of Truth

* `inventory.ini` - hosts and connection settings.
* `group_vars/all.yaml` - shared versions and configuration.
* `playbooks/` - runnable entry points.
* `roles/` - implementation.

Read these files for current addresses, versions, and component settings.

## Responsibilities

Ansible is responsible for the initial bootstrap phase.

It configures the provisioned machines, installs k3s, joins the worker node, and installs the initial platform components required before GitOps management is active.

Main responsibilities:

```text
Base host configuration
k3s controller setup
k3s worker setup
Traefik bootstrap
Argo CD bootstrap
Vault LXC configuration
```

Some older playbooks are retained for rebuild or bootstrap scenarios, but ongoing platform management should happen through Argo CD and the `_kubernetes` directory.

## Prerequisites

The control machine needs Ansible, Helm, `kubectl`, an active kubeconfig, and the required Ansible collection:

```bash
ansible-galaxy collection install kubernetes.core
```

The Terraform layer should be applied before running the main Ansible playbooks.

## Run

Run commands from `ansible/`:

```bash
ansible all -m ping
ansible-playbook playbooks/common.yaml
ansible-playbook playbooks/k3s_controller.yaml
ansible-playbook playbooks/k3s_worker.yaml
ansible-playbook playbooks/traefik.yaml
ansible-playbook playbooks/argocd.yaml
ansible-playbook playbooks/vault.yaml
```

The local Kubernetes playbooks use the current `kubectl` context.

Verify the current context before running Kubernetes-related playbooks:

```bash
kubectl config current-context
```

## Legacy Bootstrap Playbooks

The following playbooks are retained only as legacy/bootstrap code:

```text
playbooks/cert_manager.yaml
playbooks/metallb.yaml
```

cert-manager, MetalLB, and other GitOps resources are managed from `_kubernetes/` after Argo CD takes ownership.

Do not manage GitOps-owned components with their old Ansible playbooks during normal operation.
