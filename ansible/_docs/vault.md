# Vault Ansible Role

This note documents the Ansible role used to install and manage HashiCorp Vault on the dedicated Proxmox LXC container.

## Vault LXC

The Vault LXC was created by Terraform:

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

Expected result:

```text
vault-k3s | SUCCESS
ping: pong
```

## Vault Role Files

Vault is managed by the following Ansible files:

```text
ansible/playbooks/vault.yaml
ansible/roles/vault/tasks/main.yaml
ansible/roles/vault/templates/vault.hcl.j2
ansible/roles/vault/templates/vault-unseal.sh.j2
ansible/roles/vault/templates/vault-unseal.service.j2
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

A fixed Vault version is defined in:

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
- installs a local lab auto-unseal script
- installs and enables a vault-unseal systemd service
```

The HashiCorp apt repository task uses:

```yaml
{{ ansible_facts['distribution_release'] }}
```

instead of the deprecated top-level fact variable.

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

## Vault Handler

A handler restarts Vault automatically when the configuration template changes.

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

## Local Lab Auto-Unseal

This lab uses a local scripted unseal mechanism for convenience.

This allows Vault to become available automatically after a restart, so components such as External Secrets Operator can recover without manual intervention.

This is intended for lab use only.

In production, the unseal key should not be stored on the same machine as Vault. A production setup should use external auto-unseal with a KMS or HSM provider.

Files used:

```text
ansible/roles/vault/templates/vault-unseal.sh.j2
ansible/roles/vault/templates/vault-unseal.service.j2
```

The unseal key is stored on the Vault LXC at:

```text
/etc/vault.d/unseal.key
```

File permissions:

```text
owner: root
group: root
mode: 0600
```

The unseal key is not committed to Git.

The key was passed once through Ansible using a runtime variable:

```bash
read -s VAULT_K3S_UNSEAL_KEY
```

Then the Vault playbook was run with:

```bash
ansible-playbook playbooks/vault.yaml --extra-vars "vault_unseal_key=${VAULT_K3S_UNSEAL_KEY}"
```

The Ansible task that writes the key uses:

```yaml
no_log: true
```

so the key is not printed in Ansible output.

## Vault Unseal Service

The local unseal service is installed as:

```text
/etc/systemd/system/vault-unseal.service
```

The script is installed as:

```text
/usr/local/bin/vault-unseal.sh
```

The service runs after `vault.service`.

Service validation:

```bash
ansible vault -m shell -a "systemctl status vault-unseal --no-pager"
```

Expected state:

```text
Loaded: loaded
Active: active (exited)
status=0/SUCCESS
```

## Vault Service Validation

Check Vault service:

```bash
ansible vault -m shell -a "systemctl status vault --no-pager"
```

Check Vault status from inside the Vault LXC:

```bash
ansible vault -m shell -a "VAULT_ADDR=http://127.0.0.1:8200 vault status"
```

Expected current state:

```text
Initialized     true
Sealed          false
Storage Type    file
```

## Auto-Unseal Validation

Vault was tested with a service restart:

```bash
ansible vault -m shell -a "systemctl restart vault && sleep 5 && systemctl restart vault-unseal"
```

Then Vault status was checked:

```bash
ansible vault -m shell -a "VAULT_ADDR=http://127.0.0.1:8200 vault status"
```

Expected result:

```text
Sealed false
```

This confirms that the local lab auto-unseal mechanism works.

## External Secrets Validation

After Vault is unsealed, External Secrets should be able to connect to Vault.

Check the ClusterSecretStore:

```bash
kubectl get clustersecretstore vault-k3s
```

Expected result:

```text
vault-k3s   Valid   ReadWrite   True
```

If this shows `InvalidProviderConfig` and the message says `Vault is sealed`, Vault needs to be unsealed or the local unseal service needs to be checked.

## Vault Current Project State

Current known state:

```text
Vault installed
Vault service running
Vault API reachable on port 8200
Vault initialized
Vault auto-unseal works for this lab
Vault UI is accessible
External Secrets Operator connects to Vault through a dedicated token
ClusterSecretStore is Valid / Ready True
```

Important:

```text
Vault root token, ESO token and unseal key are not stored in Git.
```

For this lab, the unseal key is stored only on the Vault LXC for local scripted unseal.
