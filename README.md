# Proxmox IaC K3s Lab

Infrastructure as Code project for creating a home or lab k3s environment on Proxmox.

The project uses Terraform to create virtual machines in Proxmox, and Ansible to prepare the nodes, install k3s, and bootstrap the basic cluster components.

## What This Project Creates

- Two Ubuntu virtual machines in Proxmox:
  - `k3s-controller-01` at `10.0.20.101`
  - `k3s-worker-01` at `10.0.20.102`
- A k3s controller with the built-in Traefik and ServiceLB disabled
- A k3s worker node joined to the cluster
- MetalLB as the cluster load balancer
- Traefik as the ingress controller

## Project Structure

```text
.
├── terraform/
│   ├── providers.tf
│   ├── variables.tf
│   ├── vm.tf
│   └── outputs.tf
└── ansible/
    ├── ansible.cfg
    ├── inventory.ini
    ├── group_vars/all.yaml
    ├── playbooks/
    └── roles/
```

## Prerequisites

- A running Proxmox environment with an Ubuntu template
- Terraform
- Ansible
- SSH access to the virtual machines using the `ubuntu` user
- Vault with the Proxmox connection details
- `kubectl` and `helm` installed on the local machine
- The Ansible Kubernetes collection:

```bash
ansible-galaxy collection install kubernetes.core
```

Optional, for improved Helm idempotency:

```bash
helm plugin install https://github.com/databus23/helm-diff
```

## Secrets and Vault

Terraform reads the Proxmox credentials from Vault:

- Default mount: `secret`
- Default secret name: `proxmox`

Expected secret fields:

```text
proxmox_api_url
proxmox_token_id
proxmox_token_secret
```

You must also pass a public SSH key to Terraform:

```bash
terraform apply -var='ssh_public_key=ssh-ed25519 ...'
```

## Usage

### 1. Create the Virtual Machines with Terraform

```bash
cd terraform
terraform init
terraform plan -var='ssh_public_key=ssh-ed25519 ...'
terraform apply -var='ssh_public_key=ssh-ed25519 ...'
```

After the VMs are created, view the VM names, VM IDs, and IP addresses:

```bash
terraform output
```

### 2. Update the Inventory

The `ansible/inventory.ini` file is already configured with the default IP addresses:

```text
10.0.20.101
10.0.20.102
```

If you change the IP addresses in Terraform, update them in the Ansible inventory as well.

### 3. Install k3s with Ansible

```bash
cd ../ansible
ansible-playbook playbooks/common.yaml
ansible-playbook playbooks/k3s_controller.yaml
ansible-playbook playbooks/k3s_worker.yaml
```

### 4. Configure kubeconfig

After installing the controller, make sure the local `kubectl` points to the new cluster.

Using a clean kubeconfig is recommended:

```bash
export KUBECONFIG="$HOME/.kube/config"
```

### 5. Install MetalLB and Traefik

```bash
ansible-playbook playbooks/metallb.yaml
ansible-playbook playbooks/traefik.yaml
```

MetalLB is configured by default with this address range:

```text
10.0.20.200-10.0.20.230
```

## Important Configuration Files

- `terraform/variables.tf` - VM definitions, IP addresses, CPU/RAM/disk resources, and template ID
- `terraform/providers.tf` - provider configuration and Proxmox connection through Vault
- `ansible/inventory.ini` - controller and worker host inventory
- `ansible/group_vars/all.yaml` - k3s, MetalLB, and Traefik versions
- `ansible/notes.md` - additional notes about Ansible, Helm, and kubeconfig

## Useful Checks

Check nodes:

```bash
kubectl get nodes -o wide
```

Check Helm releases:

```bash
helm list -A
```

Check MetalLB:

```bash
kubectl get pods -n metallb-system
kubectl get ipaddresspools -n metallb-system
```

Check Traefik:

```bash
kubectl get pods -n traefik
kubectl get svc -n traefik
```

## Notes

- The cluster is installed without the built-in k3s Traefik and ServiceLB so external Traefik and MetalLB can be used instead.
- The MetalLB and Traefik playbooks run locally and require a valid `kubectl`, `helm`, and kubeconfig setup.
- In the future, advanced Traefik configuration and application management can be moved to a GitOps workflow, for example with Argo CD.
