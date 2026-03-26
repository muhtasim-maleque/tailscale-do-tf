# Tailscale subnet router on DigitalOcean with Terraform

This repository provides a Terraform-based deployment for a Tailscale Subnet Router and an isolated test device on DigitalOcean. It demonstrates how to securely bridge a Tailnet to a private subnet, providing remote access to internal resources without requiring the Tailscale agent to be installed on every individual machine.

## How it works
![Tailscale Architecture](./architecture.png)
Two Droplets are provisioned in the same DigitalOcean region. 
1. **Subnet Router (`tailscalesubnet`)**: A gateway device configured via `cloud-init`. It installs Tailscale, enables SSH and IP forwarding, and joins the Tailnet using an auth key. Route advertisement is configured manually after provisioning.
2. **Isolated Device (`basicubuntu`)**: A standard Ubuntu instance with no Tailscale agent. It exists purely to validate that traffic routed through the subnet router reaches a private IP that is not directly on the Tailnet.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [Tailscale account](https://tailscale.com/docs/how-to/quickstart) and a reusable auth key
    * **How to get**: [Admin Console > Settings > Keys > Generate auth key](https://tailscale.com/docs/features/access-control/auth-keys#generate-an-auth-key)
- DigitalOcean account with a [Personal Access Token](https://docs.digitalocean.com/reference/api/create-personal-access-token/)
- DigitalOcean SSH key and its numeric ID:
  - If you have not added one yet, follow the [DigitalOcean guide](https://docs.digitalocean.com/products/droplets/how-to/add-ssh-keys/) to add your public key via Settings > Security > SSH keys
  - Once added, retrieve the numeric ID with the DigitalOcean CLI:
    ```bash
    doctl compute ssh-key list
    # if not authenticated: doctl -t <your_token> compute ssh-key list
    ```

## Variables

| Name | Description | Default |
|---|---|---|
| `do_token` | DigitalOcean Personal Access Token | (required) |
| `tailscale_auth_key` | Tailscale auth key for device registration | (required) |
| `ssh_key_id` | Numeric ID of your DigitalOcean SSH key | (required) |
| `region` | DigitalOcean region | `nyc1` |
| `droplet_size` | Droplet size | `s-1vcpu-1gb` |
| `ubuntu_image` | OS image | `ubuntu-24-04-x64` |

## Deployment

### 1. Set variables

You can set environment variables using the `TF_VAR_` prefix to a variable name. The following are the required variables for this deployment:

```bash
export TF_VAR_do_token="your_digitalocean_token"
export TF_VAR_tailscale_auth_key="your_tailscale_auth_key"
export TF_VAR_ssh_key_id="your_digitalocean_numeric_ssh_id"
```

Variables with a default can be overridden the same way — for example, `export TF_VAR_region="sfo3"` to deploy to a different region.

Other alternative methods for passing variable values are documented [here](https://developer.hashicorp.com/terraform/language/values/variables#assign-values-to-variables).

### 2. Initialize and Plan
Prepare your workspace for Terraform to apply your configuration:

```bash
terraform init
```
Preview the changes Terraform will make before you apply them:
```bash
terraform plan
```

### 3. Apply
Create the resources and output relevant IP information:
```bash
terraform apply
```

Allow approximately 60 seconds after apply for `cloud-init` to complete on the subnet router. Terraform outputs three values once provisioning finishes:
 
- `tailscale_droplet_ip` : public IP of the subnet router
- `basic_droplet_private_ip` : private IP of the test device
- `vpc_ip_range` : the exact CIDR to use in the next step

### 4. Advertise the subnet route
 
SSH into the subnet router using Tailscale SSH (your machine must be connected to the same Tailnet):
 
```bash
ssh root@tailscalesubnet
```
 
Then advertise the VPC's CIDR using the `vpc_ip_range` value from the Terraform output:
 
```bash
tailscale set --advertise-routes=<vpc_ip_range>
```
 
The VPC CIDR is read from the droplet's actual VPC at plan time rather than supplied as a static variable, which avoids mismatches when deploying to regions with different default CIDR assignments.

### 5. Verify routing behavior before route approval
 
Exit the SSH session, and attempt to ping the private IP of the test device from your local machine:
 
```bash
ping <basic_droplet_private_ip>
```
 
This will fail. Advertised subnet routes are not active until approved in the Tailscale admin console, so the Tailnet has no path to the `basicubuntu` device at this point. This is expected behavior and confirms the approval step is meaningful.

### 6. Approve the advertised route
 
Advertised routes require manual approval in the Tailscale admin console unless `autoApprovers` is configured in your ACL policy. After the device appears:
 
1. Go to [Tailscale Admin](https://login.tailscale.com/admin/machines)
2. Find the `tailscalesubnet` device and open its route settings
3. Approve the advertised subnet
 
### 7. Validate
 
From your local machine, ping the same private IP again:
 
```bash
ping <basic_droplet_private_ip>
```
 
A successful ping confirms that traffic is now flowing through the subnet router to a device that has no Tailscale client installed. Nice!
 
### Tear down

This will cleanup both droplets and all associated resources: 
```bash
terraform destroy
```
 
## File structure
 
```
.
├── providers.tf        # Terraform version constraints and DigitalOcean provider config
├── variables.tf        # All input variable declarations with types and defaults
├── main.tf             # The two Droplet resources and VPC data source
├── outputs.tf          # Public IP of the router, private IP of the test device, VPC CIDR
├── cloud_init.tftpl    # cloud-init template run on first boot of the Tailscale subnet router
└── .gitignore          # Excludes .tfvars, .tfstate, and .terraform/
```
 
## Design notes
 
Route advertisement is a manual step rather than being baked into `cloud-init`. Fetching the default VPC address range at provisioning time may be unreliable. Instead, the VPC CIDR is read via a `digitalocean_vpc` data source and provided as a Terraform output. This makes the correct value explicit and eliminates guesswork when deploying to regions with non-standard CIDR assignments.
 
Having a second Droplet (`basicubuntu`) is intentional. A subnet router is only meaningful if there are devices on the subnet that are not running Tailscale locally. Gaving a plain device to route traffic to makes the validation step concrete.