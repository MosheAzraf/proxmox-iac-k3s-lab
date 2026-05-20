# Ansible Notes

This note documents the Ansible cleanup done for the `proxmox-iac-k3s-lab` project.

## Goal

The goal was to improve the Ansible roles for MetalLB and Traefik by replacing direct CLI usage with Ansible modules.

Instead of using:

```yaml
ansible.builtin.command
```

for `helm` and `kubectl`, the roles now use modules from the `kubernetes.core` collection.

## Required Ansible Collection

Install:

```bash
ansible-galaxy collection install kubernetes.core
```

Used modules:

```text
kubernetes.core.helm_repository
kubernetes.core.helm
kubernetes.core.k8s
```

## Optional Helm Plugin

To avoid Helm idempotency warnings and improve change detection:

```bash
helm plugin install https://github.com/databus23/helm-diff
```

This removes warnings like:

```text
The default idempotency check can fail to report changes in certain cases.
Install helm diff >= 3.4.1 for better results.
```

## KUBECONFIG

The local machine had multiple kubeconfig files configured:

```bash
$HOME/.kube/config:$HOME/.kube/config-pi
```

This caused Ansible to try connecting to an old Kubernetes API address.

The fix was to set a clean permanent environment variable:

```bash
export KUBECONFIG="$HOME/.kube/config"
```

This was added to:

```text
~/.zshrc
```

After reloading the shell:

```bash
source ~/.zshrc
```

The active kubeconfig points to the current Proxmox k3s cluster:

```text
https://10.0.20.101:6443
```

## MetalLB Role

MetalLB was changed from inline `kubectl apply -f -` commands to Ansible Kubernetes modules.

### Before

The role used:

```yaml
ansible.builtin.command: helm upgrade --install ...
ansible.builtin.command: kubectl apply -f -
```

### After

The role now uses:

```yaml
kubernetes.core.helm_repository
kubernetes.core.helm
kubernetes.core.k8s
```

The MetalLB Kubernetes resources were moved into templates:

```text
roles/metallb/templates/ip-address-pool.yaml.j2
roles/metallb/templates/l2-advertisement.yaml.j2
```

The role applies them with:

```yaml
definition: "{{ lookup('template', 'ip-address-pool.yaml.j2') | from_yaml }}"
definition: "{{ lookup('template', 'l2-advertisement.yaml.j2') | from_yaml }}"
```

This avoids the deprecation warning that appeared when using the `template:` parameter directly in `kubernetes.core.k8s`.

## MetalLB Resources

MetalLB still needs these Kubernetes objects after installation:

```text
IPAddressPool
L2Advertisement
```

Reason:

MetalLB can be installed by Helm, but it still needs to know which IP range it is allowed to assign.

Current IP range:

```text
10.0.20.200-10.0.20.230
```

Current pool names:

```text
default-pool
default-l2
```

## Traefik Role

Traefik was also changed from direct Helm commands to Ansible Helm modules.

### Before

The role used:

```yaml
ansible.builtin.command: helm repo add ...
ansible.builtin.command: helm upgrade --install ...
```

### After

The role now uses:

```yaml
kubernetes.core.helm_repository
kubernetes.core.helm
```

No custom values were added to Ansible for now.

Reason:

Traefik is kept as a minimal bootstrap install through Ansible. Later, Argo CD can manage Traefik values and configuration from the GitOps layer.

## Current Responsibility Split

Current approach:

```text
Ansible:
- install common node settings
- install k3s controller
- install k3s worker
- bootstrap MetalLB
- bootstrap Traefik

Future Argo CD:
- manage Traefik values
- manage Traefik routing configuration
- manage applications and GitOps resources
```

Important note:

If Argo CD later takes ownership of the Traefik Helm release, avoid running the Ansible Traefik role repeatedly unless it is intentionally still part of bootstrap.

## Validation Commands

MetalLB:

```bash
ansible-playbook playbooks/metallb.yaml
```

Expected result after everything already exists:

```text
ok=4
changed=0
failed=0
```

Traefik:

```bash
ansible-playbook playbooks/traefik.yaml
```

Expected result after everything already exists:

```text
ok=2
changed=0
failed=0
```

## Final State

MetalLB:

```text
Helm install managed by kubernetes.core.helm
IPAddressPool managed by kubernetes.core.k8s
L2Advertisement managed by kubernetes.core.k8s
Templates stored under roles/metallb/templates
```

Traefik:

```text
Helm install managed by kubernetes.core.helm
No values file in Ansible for now
Future values should likely move to Argo CD / GitOps
```

## Useful Commit Messages Used

```bash
git commit -m "Refactor MetalLB role to use Kubernetes modules"
git commit -m "Refactor Traefik role to use Helm module"
```
