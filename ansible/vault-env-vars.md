# Vault Environment Variables

This note explains how I separate the local Vault on my Mac from the Vault running in the k3s lab.

## Current local Vault variables

These variables are used for the Vault running locally on the Mac:

```bash
export VAULT_ADDR
export VAULT_UNSEAL_KEY
export VAULT_TOKEN
```

Do not change them for the k3s Vault.

## k3s Vault variables

For the Vault running in Proxmox / k3s lab, use separate variable names:

```bash
# vault k3s
export VAULT_K3S_ADDR="http://10.0.20.110:8200"
export VAULT_K3S_UNSEAL_KEY=""
export VAULT_K3S_TOKEN=""
```

These can be stored in `~/.zshrc`.

## How to work with the k3s Vault

When I want the Vault CLI to work against the k3s Vault, I temporarily map the k3s variables into the regular Vault variables:

```bash
export VAULT_ADDR="$VAULT_K3S_ADDR"
export VAULT_UNSEAL_KEY="$VAULT_K3S_UNSEAL_KEY"
export VAULT_TOKEN="$VAULT_K3S_TOKEN"
```

After this, commands like this will use the k3s Vault:

```bash
vault status
```

## Simple rule

`VAULT_ADDR`, `VAULT_UNSEAL_KEY`, and `VAULT_TOKEN` are the active variables that the Vault CLI uses.

`VAULT_K3S_ADDR`, `VAULT_K3S_UNSEAL_KEY`, and `VAULT_K3S_TOKEN` are only saved values for the k3s Vault.

The local Vault variables stay for the Mac.

The k3s Vault variables stay separate.
