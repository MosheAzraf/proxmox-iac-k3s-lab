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

Expected result before init:

```json
{
  "initialized": false,
  "sealed": true,
  "version": "1.21.2",
  "enterprise": false
}
```

## Vault Current Project State

Vault was later initialized and unsealed manually outside Ansible.

Current known state:

```text
Vault installed
Vault service running
Vault API reachable on port 8200
Vault initialized
Vault can be unsealed manually
Vault UI is accessible
External Secrets Operator connects to Vault through a dedicated token
```

Important:

```text
Vault unseal keys, root token and ESO token are not stored in Git.
```
