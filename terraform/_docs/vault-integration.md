# Terraform Vault Integration

This note documents how Terraform reads Proxmox credentials from Vault.

## Purpose

Terraform uses Vault to avoid storing Proxmox credentials directly in the repository.

The Proxmox provider receives its endpoint and API token from Vault during Terraform execution.

## Providers

Terraform uses:

```text
HashiCorp Vault provider
Proxmox provider: bpg/proxmox
```

## Vault Secret Location

Terraform reads the Proxmox credentials from Vault.

Expected location:

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

## Usage Flow

```text
Vault
   ↓
Terraform Vault provider
   ↓
Proxmox provider configuration
   ↓
Proxmox resource provisioning
```

## Security Rule

Do not commit real Proxmox tokens or Vault tokens to Git.

The repository should contain only Terraform code and non-secret configuration.

Terraform state should also remain outside Git, because it can contain sensitive or environment-specific data.
