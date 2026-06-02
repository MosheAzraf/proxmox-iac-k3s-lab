# Terraform Runbook

This file contains short operational commands for the Terraform layer.

## Go to Terraform Directory

```bash
cd terraform
```

## Initialize Terraform

```bash
terraform init
```

## Format Terraform Files

```bash
terraform fmt
```

## Validate Terraform

```bash
terraform validate
```

## Check Plan

```bash
terraform plan
```

Expected clean result:

```text
No changes. Your infrastructure matches the configuration.
```

## Apply Changes

```bash
terraform apply
```

## Current Terraform Resources

```text
k3s-controller-01   10.0.20.101   VM ID 201
k3s-worker-01       10.0.20.102   VM ID 202
vault-k3s           10.0.20.110   LXC ID 210
```

## SSH to Vault LXC

```bash
ssh root@10.0.20.110
```

## Important Safety Notes

Do not commit:

```text
terraform.tfstate
terraform.tfstate.backup
*.tfvars with real secrets
Vault tokens
Proxmox tokens
```

Terraform state should remain ignored by Git.
