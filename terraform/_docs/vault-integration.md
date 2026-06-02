# Terraform Vault Integration

This note documents how Terraform reads Proxmox credentials from Vault.

## Providers

Terraform uses:

```text
HashiCorp Vault provider
Proxmox provider: bpg/proxmox
```

Terraform reads Proxmox credentials directly from Vault.

## Vault Secret Location

Terraform reads the following values from Vault:

```text
mount: secret
secret: proxmox
```

Expected fields:

```text
proxmox_api_url
proxmox_token_id
proxmox_token_secret
```

## Usage

The Proxmox provider receives its endpoint and API token from Vault instead of hardcoded values.

This keeps Proxmox credentials out of Terraform files.

## Security Rule

Do not commit real Proxmox tokens or Vault tokens to Git.

The repository should contain only Terraform code and non-secret configuration.

## Current Status

Terraform is successfully connected to Proxmox through Vault.

Terraform plan was checked and showed:

```text
No changes. Your infrastructure matches the configuration.
```
