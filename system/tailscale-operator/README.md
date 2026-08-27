# Tailscale Operator Deployment

This directory deploys the `tailscale-operator` using FluxCD.

## Pre-requisites

### 1. 1Password OAuth Secret Setup

The operator retrieves its OAuth credentials using `ExternalSecrets` from 1Password. Ensure you have an item named **`Tailscale OAuth`** in your 1Password vault with the following text fields:

- `client_id`: Your Tailscale OAuth client ID
- `client_secret`: Your Tailscale OAuth client secret

### 2. OAuth Client Configuration (Tailscale Console)

When creating the OAuth client in the Tailscale admin console, ensure the following are configured:

- **Scope**: Must have **Read/Write** permissions for **Devices (Core)** and **Auth Keys (Keys)**.
- **Tags**: Must be assigned the `tag:k8s-operator` tag (or the tag you configured in your ACLs).
