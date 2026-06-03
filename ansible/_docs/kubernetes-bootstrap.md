# Kubernetes Bootstrap Roles

This note documents the Ansible roles used to bootstrap Kubernetes platform components.

Ansible is used for the initial bootstrap layer. After the base platform is ready, ongoing Kubernetes platform management gradually moves to Argo CD / GitOps.

## MetalLB Role

MetalLB was changed from inline `kubectl apply -f -` commands to Ansible Kubernetes modules.

### Before

The role used direct command execution:

```yaml
ansible.builtin.command: helm upgrade --install ...
ansible.builtin.command: kubectl apply -f -
```

### After

The role now uses Kubernetes-aware Ansible modules:

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

## MetalLB Resources

MetalLB needs these Kubernetes objects after installation:

```text
IPAddressPool
L2Advertisement
```

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

Traefik was changed from direct Helm commands to Ansible Helm modules.

### Before

The role used direct command execution:

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

Traefik is kept as a minimal bootstrap install through Ansible.

Future Traefik values and configuration can move to the GitOps layer if needed.

## Argo CD Role

Argo CD was added as an Ansible bootstrap role.

Files:

```text
ansible/playbooks/argocd.yaml
ansible/roles/argocd/tasks/main.yaml
```

The playbook runs locally:

```yaml
---
# Runs locally and requires Helm + kubectl configured on the development machine
- name: install argocd
  hosts: localhost
  connection: local
  gather_facts: false
  become: false
  roles:
    - argocd
```

The Argo CD role uses:

```yaml
kubernetes.core.helm_repository
kubernetes.core.helm
```

## Argo CD Variables

The Argo CD variables are defined in:

```text
ansible/group_vars/all.yaml
```

Current values:

```yaml
argocd_repo_name: argo
argocd_namespace: argocd
argocd_release_name: argocd
argocd_chart: argo/argo-cd
argocd_repo_url: https://argoproj.github.io/argo-helm
argocd_chart_version: 9.5.14
```

Important note:

```text
argocd_chart_version is the Helm chart version, not the Argo CD application version.
```

## Argo CD Validation

Pods can be checked with:

```bash
kubectl get pods -n argocd
```

Main Argo CD pods:

```text
argocd-application-controller
argocd-applicationset-controller
argocd-dex-server
argocd-notifications-controller
argocd-redis
argocd-repo-server
argocd-server
```

The Argo CD server service is:

```text
argocd-server
```

Argo CD is initially installed by Ansible, and then managed by Argo CD itself from the GitOps layer.

## cert-manager Role

cert-manager was originally added as an Ansible bootstrap role.

Files:

```text
ansible/playbooks/cert_manager.yaml
ansible/roles/cert_manager/tasks/main.yaml
```

The role was used for the initial installation of cert-manager.

Current direction:

```text
cert-manager is managed by Argo CD after the initial bootstrap.
```

The Ansible role is kept in the repository for bootstrap history and reference, but it should not be used for regular ongoing management.

Current GitOps files for cert-manager:

```text
_kubernetes/applications/cert-manager.yaml
_kubernetes/applications/cert-manager-config.yaml
_kubernetes/platform/cert-manager/
```

## cert-manager Variables

The cert-manager variables are still defined in:

```text
ansible/group_vars/all.yaml
```

Current values:

```yaml
cert_manager_repo_name: jetstack
cert_manager_namespace: cert-manager
cert_manager_release_name: cert-manager
cert_manager_chart: jetstack/cert-manager
cert_manager_repo_url: https://charts.jetstack.io
cert_manager_chart_version: 1.20.2
cert_manager_crds_enabled: true
```

These values belong to the original Ansible bootstrap role.

Important note:

```yaml
cert_manager_crds_enabled: true
```

was required so the cert-manager CRDs were installed together with the Helm chart during the initial bootstrap flow.

## cert-manager Validation

cert-manager can be checked with:

```bash
kubectl get pods -n cert-manager
```

Main cert-manager pods:

```text
cert-manager
cert-manager-cainjector
cert-manager-webhook
```

ClusterIssuers can be checked with:

```bash
kubectl get clusterissuer
```

Expected issuers:

```text
selfsigned-issuer
internal-ca
```

Expected state:

```text
Ready = True
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
Future values can move to Argo CD / GitOps if needed
```

Argo CD:

```text
Initial Helm install managed by kubernetes.core.helm
Installed into argocd namespace
Ongoing self-management is handled from Argo CD / GitOps
```

cert-manager:

```text
Originally installed by Ansible during bootstrap
Currently managed by Argo CD
Internal CA configuration is managed from the GitOps layer
Ansible role is kept for bootstrap history and reference
```
