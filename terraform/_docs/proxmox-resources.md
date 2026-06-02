# Proxmox Resources

This note documents the Proxmox resources currently created by Terraform.

## k3s Controller VM

```text
Name: k3s-controller-01
VM ID: 201
IP: 10.0.20.101/24
CPU: 4 cores
RAM: 8192 MB
Disk: 150 GB
```

## k3s Worker VM

```text
Name: k3s-worker-01
VM ID: 202
IP: 10.0.20.102/24
CPU: 4 cores
RAM: 16384 MB
Disk: 150 GB
```

## Shared VM Characteristics

Both k3s VMs:

```text
Clone from Ubuntu template VM ID 9000
Use cloud-init
Use SSH public key authentication
Have QEMU guest agent enabled
Start automatically on boot
```

## Vault LXC Container

A dedicated Ubuntu 24.04 LXC container was added for Vault.

```text
Hostname: vault-k3s
VM ID: 210
IP: 10.0.20.110/24
Gateway: 10.0.20.1
CPU: 2 cores
RAM: 2048 MB
Swap: 512 MB
Disk: 20 GB
Bridge: vmbr0
Template: ubuntu-24.04-standard_24.04-2_amd64.tar.zst
```

## Vault LXC Characteristics

```text
Unprivileged container
Starts automatically on boot
Uses the same SSH public key as the k3s nodes
Accessible through SSH as root
Managed through Terraform
```

Example login:

```bash
ssh root@10.0.20.110
```

## Important Terraform Note

A lifecycle rule was added to ignore Proxmox feature flag drift on the LXC container:

```hcl
lifecycle {
  ignore_changes = [
    features
  ]
}
```

Reason:

```text
This prevents Terraform from repeatedly attempting feature flag modifications that require elevated Proxmox permissions.
```
