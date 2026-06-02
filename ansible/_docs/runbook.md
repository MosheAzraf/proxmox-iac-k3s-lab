# Ansible Runbook

This file contains short operational commands for the Ansible layer.

## Install Required Ansible Collection

```bash
ansible-galaxy collection install kubernetes.core
```

## Reload Shell Environment

```bash
source ~/.zshrc
```

## Validate Vault SSH / Ansible Connectivity

```bash
ansible vault -m ping
```

Expected:

```text
vault-k3s | SUCCESS
ping: pong
```

## Run MetalLB Playbook

```bash
ansible-playbook playbooks/metallb.yaml
```

Expected result after everything already exists:

```text
ok=4
changed=0
failed=0
```

## Run Traefik Playbook

```bash
ansible-playbook playbooks/traefik.yaml
```

Expected result after everything already exists:

```text
ok=2
changed=0
failed=0
```

## Run Argo CD Playbook

```bash
ansible-playbook playbooks/argocd.yaml
```

Expected result after everything already exists:

```text
ok=2
changed=0
failed=0
```

## Check Argo CD Pods

```bash
kubectl get pods -n argocd
```

## Check Argo CD Services

```bash
kubectl get svc -n argocd
```

## Open Argo CD UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open:

```text
https://localhost:8080
```

## Get Initial Argo CD Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret   -o jsonpath="{.data.password}" | base64 -d
```

## Run cert-manager Playbook

```bash
ansible-playbook playbooks/cert_manager.yaml
```

Expected result after everything already exists:

```text
ok=2
changed=0
failed=0
```

## Check cert-manager Pods

```bash
kubectl get pods -n cert-manager
```

## Check cert-manager Helm Release

```bash
helm list -n cert-manager
```

## Run Vault Playbook

```bash
ansible-playbook playbooks/vault.yaml
```

Expected result after everything already exists:

```text
ok=8
changed=0
failed=0
```

## Check Vault Service

```bash
ssh root@10.0.20.110 "systemctl status vault --no-pager"
```

## Check Vault API

```bash
curl http://10.0.20.110:8200/v1/sys/health
```

## Work With k3s Vault From Mac

```bash
source ~/.zshrc
export VAULT_ADDR="$VAULT_K3S_ADDR"
vault status
```

If Vault is sealed, unseal it with the locally saved unseal key.

Do not commit Vault tokens or unseal keys to Git.
