# Kubernetes Bootstrap Roles

This note documents the Ansible roles used to bootstrap Kubernetes platform components.

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

## MetalLB Resources

MetalLB still needs these Kubernetes objects after installation:

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

Traefik is kept as a minimal bootstrap install through Ansible.

Later, Argo CD can manage Traefik values and configuration from the GitOps layer.

## Argo CD Role

Argo CD was added as a new Ansible bootstrap role.

New files added:

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

The Argo CD variables were added to:

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

The selected Helm chart version was:

```text
9.5.14
```

This chart installs Argo CD app version:

```text
v3.4.2
```

Important note:

`argocd_chart_version` is the Helm chart version, not the Argo CD application version.

## Argo CD Validation

Pods were checked with:

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

The Argo CD server service is currently:

```text
argocd-server   ClusterIP   80/TCP,443/TCP
```

Temporary UI access:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open:

```text
https://localhost:8080
```

## cert-manager Role

cert-manager was added as a new Ansible bootstrap role.

New files added:

```text
ansible/playbooks/cert_manager.yaml
ansible/roles/cert_manager/tasks/main.yaml
```

The playbook runs locally:

```yaml
---
# Runs locally and requires Helm + kubectl configured on the development machine
- name: install cert-manager
  hosts: localhost
  connection: local
  gather_facts: false
  become: false
  roles:
    - cert_manager
```

The cert-manager role uses:

```yaml
kubernetes.core.helm_repository
kubernetes.core.helm
```

## cert-manager Variables

The cert-manager variables were added to:

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

The selected Helm chart version was:

```text
1.20.2
```

This chart installs cert-manager app version:

```text
v1.20.2
```

Important note:

```yaml
cert_manager_crds_enabled: true
```

is required so the cert-manager CRDs are installed together with the Helm chart.

## cert-manager Validation

Pods were checked with:

```bash
kubectl get pods -n cert-manager
```

Main cert-manager pods:

```text
cert-manager
cert-manager-cainjector
cert-manager-webhook
```

The Helm release was checked with:

```bash
helm list -n cert-manager
```

Result:

```text
NAME            NAMESPACE       REVISION        STATUS      CHART                  APP VERSION
cert-manager    cert-manager    1               deployed    cert-manager-v1.20.2   v1.20.2
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

Argo CD:

```text
Helm install managed by kubernetes.core.helm
Installed into argocd namespace
argocd-server currently exposed as ClusterIP
Temporary UI access is done with kubectl port-forward
Current self-management is now handled from Argo CD / GitOps
```

cert-manager:

```text
Helm install managed by kubernetes.core.helm
Installed into cert-manager namespace
CRDs installed through crds.enabled=true
cert-manager, cainjector and webhook pods are running
Future management should move to Argo CD / GitOps
```
