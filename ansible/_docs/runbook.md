# Ansible Runbook

This file contains short operational commands for the Ansible layer.

## Go to Ansible Directory

```bash
cd ansible
```

## Check Inventory

```bash
ansible-inventory -i inventory.ini --list
```

## Ping All Hosts

```bash
ansible all -i inventory.ini -m ping
```

## Run Common Node Setup

```bash
ansible-playbook playbooks/common.yaml
```

## Install k3s Controller

```bash
ansible-playbook playbooks/k3s_controller.yaml
```

## Install k3s Worker

```bash
ansible-playbook playbooks/k3s_worker.yaml
```

## Install MetalLB

```bash
ansible-playbook playbooks/metallb.yaml
```

## Install Traefik

```bash
ansible-playbook playbooks/traefik.yaml
```

## Install Argo CD

```bash
ansible-playbook playbooks/argocd.yaml
```

## Configure Vault LXC

```bash
ansible-playbook playbooks/vault.yaml
```

## Run Vault Playbook with Unseal Key

Use this only when configuring or updating the local lab auto-unseal setup.

```bash
read -s VAULT_K3S_UNSEAL_KEY
ansible-playbook playbooks/vault.yaml --extra-vars "vault_unseal_key=${VAULT_K3S_UNSEAL_KEY}"
```

## Check Vault Status

```bash
ansible vault -m shell -a "VAULT_ADDR=http://127.0.0.1:8200 vault status"
```

Expected state:

```text
Initialized true
Sealed false
```

## Required Collection

```bash
ansible-galaxy collection install kubernetes.core
```

## Optional Helm Plugin

```bash
helm plugin install https://github.com/databus23/helm-diff
```

## KUBECONFIG

Use the local kubeconfig for the current Proxmox k3s cluster:

```bash
export KUBECONFIG="$HOME/.kube/config"
```

Expected Kubernetes API endpoint:

```text
https://10.0.20.101:6443
```

## Responsibility Note

Ansible is used for bootstrap.

Argo CD manages GitOps-owned Kubernetes platform components after the bootstrap phase.

Avoid repeatedly running Ansible roles for components that are already managed by Argo CD, unless the action is intentional.
