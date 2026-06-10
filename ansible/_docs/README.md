# Ansible

Ansible configures the Terraform-provisioned hosts and bootstraps k3s, Vault,
and the services required before Argo CD takes ownership.

## Source Of Truth

* `inventory.ini` - hosts and connection settings.
* `group_vars/all.yaml` - shared versions and configuration.
* `playbooks/` - runnable entry points.
* `roles/` - implementation.

Read these files for current addresses, versions, and component settings.

## Prerequisites

The control machine needs Ansible, Helm, `kubectl`, an active kubeconfig, and:

```bash
ansible-galaxy collection install kubernetes.core
```

## Run

Run commands from `ansible/`:

```bash
ansible all -m ping
ansible-playbook playbooks/common.yaml
ansible-playbook playbooks/k3s_controller.yaml
ansible-playbook playbooks/k3s_worker.yaml
ansible-playbook playbooks/metallb.yaml
ansible-playbook playbooks/traefik.yaml
ansible-playbook playbooks/argocd.yaml
ansible-playbook playbooks/vault.yaml
```

The local Kubernetes playbooks use the current `kubectl` context. Verify it
before running them:

```bash
kubectl config current-context
```

`playbooks/cert_manager.yaml` and `playbooks/metallb.yaml` are retained only as legacy/bootstrap code.
cert-manager, MetalLB, and other GitOps resources are managed from `_kubernetes/`.
