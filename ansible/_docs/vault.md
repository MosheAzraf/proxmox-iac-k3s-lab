# Vault Ansible Role

This note documents the Ansible role used to install and manage HashiCorp Vault on the dedicated Proxmox LXC container.

## Vault LXC

The Vault LXC is created by Terraform.

```text
vault-k3s
10.0.20.110
Ubuntu 24.04 LXC
```

The Ansible inventory includes a dedicated `vault` group:

```ini
[vault]
vault-k3s ansible_host=10.0.20.110

[vault:vars]
ansible_user=root
ansible_ssh_private_key_file=~/.ssh/id_ed25519
ansible_python_interpreter=/usr/bin/python3
```

Validate connectivity with:

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

## Vault Version

A fixed Vault version is defined in:

```text
ansible/group_vars/all.yaml
```

Example:

```yaml
vault_version: "1.21.2-1"
```

This keeps the Vault install version pinned instead of installing whatever version is latest.

## Vault Install Role

The Vault role is responsible for:

```text
installing required apt dependencies
adding the HashiCorp GPG key
adding the HashiCorp apt repository
installing the pinned Vault version
creating the Vault data directory
copying the Vault configuration template
enabling and starting the Vault systemd service
installing the local lab auto-unseal script
installing and enabling the vault-unseal systemd service
```

The HashiCorp apt repository task uses:

```yaml
{{ ansible_facts['distribution_release'] }}
```

instead of the deprecated top-level fact variable.

## Vault Configuration

Vault is configured with file storage for the current lab setup.

Template:

```text
ansible/roles/vault/templates/vault.hcl.j2
```

Configuration:

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

The `api_addr` value is configured so Vault can advertise its API address correctly.

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

The key can be passed through Ansible using a runtime variable:

```bash
read -s VAULT_K3S_UNSEAL_KEY
```

Then run the Vault playbook with:

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

Expected state:

```text
Initialized true
Sealed false
```

## Auto-Unseal Validation

Vault auto-unseal can be tested with a service restart:

```bash
ansible vault -m shell -a "systemctl restart vault && sleep 5 && systemctl restart vault-unseal"
```

Then check Vault status:

```bash
ansible vault -m shell -a "VAULT_ADDR=http://127.0.0.1:8200 vault status"
```

Expected result:

```text
Sealed false
```

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

## Security Notes

Do not commit real Vault tokens, ESO tokens, or unseal keys to Git.

For this lab, the unseal key is stored only on the Vault LXC for local scripted unseal.

This setup is designed for local lab convenience and should not be treated as a production Vault architecture.
