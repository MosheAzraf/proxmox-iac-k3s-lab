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

## Argo CD Role

Argo CD was added as a new Ansible bootstrap role.

The goal was to install Argo CD into the k3s cluster using Helm through Ansible, in the same style already used for MetalLB and Traefik.

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

The role adds the Argo Helm repository and installs the Argo CD Helm chart.

The install task uses `wait: true` so Ansible waits for the Helm release resources to become ready before finishing.

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

## Argo CD Installation

Argo CD was installed with:

```bash
ansible-playbook playbooks/argocd.yaml
```

Result:

```text
ok=2
changed=2
failed=0
```

The installation created the `argocd` namespace and installed the Argo CD Helm release.

## Argo CD Validation

Pods were checked with:

```bash
kubectl get pods -n argocd
```

All main Argo CD pods were running:

```text
argocd-application-controller
argocd-applicationset-controller
argocd-dex-server
argocd-notifications-controller
argocd-redis
argocd-repo-server
argocd-server
```

The Redis init job finished successfully:

```text
argocd-redis-secret-init   Completed
```

Services were checked with:

```bash
kubectl get svc -n argocd
```

The Argo CD server service is currently:

```text
argocd-server   ClusterIP   80/TCP,443/TCP
```

This means Argo CD is currently internal to the cluster.

## Argo CD UI Access

Temporary local access to the UI can be done with:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then open:

```text
https://localhost:8080
```

The browser may show a certificate warning. This is expected at this stage.

The default username is:

```text
admin
```

The initial admin password can be retrieved manually with:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

This command is kept as a manual access note, not as an Ansible role task.


## cert-manager Role

cert-manager was added as a new Ansible bootstrap role.

The goal was to install cert-manager into the k3s cluster using Helm through Ansible, as part of the base cluster setup together with MetalLB, Traefik and Argo CD.

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

The role adds the Jetstack Helm repository and installs the cert-manager Helm chart.

The install task uses `wait: true` so Ansible waits for the Helm release resources to become ready before finishing.

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

`cert_manager_crds_enabled: true` is required so the cert-manager CRDs are installed together with the Helm chart.

This matches the official Helm install behavior:

```bash
helm install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.20.2 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

In this project, the regular Jetstack Helm repository is used instead of the OCI chart, so the chart version is written as:

```text
1.20.2
```

## cert-manager Installation

cert-manager was installed with:

```bash
ansible-playbook playbooks/cert_manager.yaml
```

Result:

```text
ok=2
changed=2
failed=0
```

The installation created the `cert-manager` namespace and installed the cert-manager Helm release.

## cert-manager Validation

Pods were checked with:

```bash
kubectl get pods -n cert-manager
```

All main cert-manager pods were running:

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

## Current Responsibility Split

Current approach:

```text
Ansible:
- install common node settings
- install k3s controller
- install k3s worker
- bootstrap MetalLB
- bootstrap Traefik
- bootstrap Argo CD
- bootstrap cert-manager

Future Argo CD:
- manage itself from Git
- manage Traefik values
- manage Traefik routing configuration
- manage platform components
- manage applications and GitOps resources
```

Important note:

If Argo CD later takes ownership of the Traefik Helm release, avoid running the Ansible Traefik role repeatedly unless it is intentionally still part of bootstrap.

Important note:

Argo CD is currently installed by Ansible using Helm. The next planned step is to make Argo CD self-managed carefully, starting with a Git-based Argo CD Application without automatic sync.

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

Argo CD:

```bash
ansible-playbook playbooks/argocd.yaml
```

Expected result after everything already exists:

```text
ok=2
changed=0
failed=0
```

Check Argo CD pods:

```bash
kubectl get pods -n argocd
```

Check Argo CD services:

```bash
kubectl get svc -n argocd
```

cert-manager:

```bash
ansible-playbook playbooks/cert_manager.yaml
```

Expected result after everything already exists:

```text
ok=2
changed=0
failed=0
```

Check cert-manager pods:

```bash
kubectl get pods -n cert-manager
```

Check cert-manager Helm release:

```bash
helm list -n cert-manager
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
Future self-management should move to Argo CD / GitOps
```


cert-manager:

```text
Helm install managed by kubernetes.core.helm
Installed into cert-manager namespace
CRDs installed through crds.enabled=true
cert-manager, cainjector and webhook pods are running
Future management can move to Argo CD / GitOps later
```

## Useful Commit Messages Used

```bash
git commit -m "Refactor MetalLB role to use Kubernetes modules"
git commit -m "Refactor Traefik role to use Helm module"
git commit -m "Add Argo CD Ansible installation"
git commit -m "Add cert-manager Ansible installation"
```

## Vault LXC Ansible Role

A new Ansible role was added to install and manage HashiCorp Vault on the dedicated Proxmox LXC container.

The Vault LXC was previously created by Terraform:

```text
vault-k3s
10.0.20.110
Ubuntu 24.04 LXC
```

The Ansible inventory was updated with a dedicated `vault` group:

```ini
[vault]
vault-k3s ansible_host=10.0.20.110

[vault:vars]
ansible_user=root
ansible_ssh_private_key_file=~/.ssh/id_ed25519
ansible_python_interpreter=/usr/bin/python3
```

Validation was done with:

```bash
ansible vault -m ping
```

Result:

```text
vault-k3s | SUCCESS
ping: pong
```

## Vault Role Files

New files added:

```text
ansible/playbooks/vault.yaml
ansible/roles/vault/tasks/main.yaml
ansible/roles/vault/templates/vault.hcl.j2
ansible/roles/vault/handlers/main.yaml
```

The playbook:

```yaml
---
- name: install vault
  hosts: vault
  roles:
    - vault
```

## Vault Variables

A fixed Vault version was added to:

```text
ansible/group_vars/all.yaml
```

Current value:

```yaml
vault_version: "1.21.2-1"
```

This keeps the Vault install version pinned instead of installing whatever version is latest.

## Vault Install Role

The Vault role currently does the following:

```text
- installs required apt dependencies
- adds the HashiCorp GPG key
- adds the HashiCorp apt repository
- installs the pinned Vault version
- creates /opt/vault/data
- copies the Vault configuration template
- enables and starts the Vault systemd service
```

The HashiCorp apt repository task was updated to use:

```yaml
{{ ansible_facts['distribution_release'] }}
```

instead of the deprecated top-level fact variable.

After the update, the playbook runs cleanly and idempotently:

```text
ok=8
changed=0
failed=0
```

## Vault Configuration

Vault is configured with file storage for the current lab setup.

Current template:

```text
ansible/roles/vault/templates/vault.hcl.j2
```

Current configuration:

```hcl
storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

api_addr = "http://10.0.20.110:8200"

ui = true
disable_mlock = true
```

The `api_addr` value was added after Vault showed a warning that no API address was configured.

After restarting Vault, the warning disappeared.

## Vault Handler

A handler was added so Vault restarts automatically when the configuration template changes.

Handler file:

```text
ansible/roles/vault/handlers/main.yaml
```

Handler:

```yaml
---
- name: Restart Vault
  systemd:
    name: vault
    state: restarted
```

The configuration copy task notifies this handler:

```yaml
notify: Restart Vault
```

## Vault Service Validation

Vault was checked with:

```bash
ssh root@10.0.20.110 "systemctl status vault --no-pager"
```

Result:

```text
vault.service active (running)
Vault v1.21.2
Storage: file
```

The Vault HTTP API was checked from the local machine:

```bash
curl http://10.0.20.110:8200/v1/sys/health
```

Result showed Vault is reachable but not initialized yet:

```json
{
  "initialized": false,
  "sealed": true,
  "version": "1.21.2",
  "enterprise": false
}
```

This is the expected state before running `vault operator init`.

## Current Vault Status

Current state:

```text
Vault installed
Vault service running
Vault API reachable on port 8200
Vault not initialized yet
Vault sealed
```

Next planned step:

```text
Prepare a local secure place to store Vault init output
Run vault operator init
Store unseal keys and root token outside Git
Unseal Vault
Continue toward ESO integration later
```

## Useful Commit Messages Used

```bash
git commit -m "add vault lxc terraform configuration and ansible inventory"
git commit -m "add vault ansible role"
```

