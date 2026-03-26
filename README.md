# Tailscale subnet router on DigitalOcean with Terraform

This repository provides a Terraform-based deployment for a Tailscale Subnet Router and an isolated VM on DigitalOcean. It demonstrates how to securely bridge a Tailnet to a private subnet, providing remote access to internal resources without requiring the Tailscale agent to be installed on every individual machine.

## How it works
![Tailscale Architecture](./architecture.png)
Two Droplets are provisioned in the same DigitalOcean region. 
1. **Subnet Router (`tailscalesubnet`)**: A gateway device configured via `cloud-init`. It installs Tailscale, enables SSH and IP forwarding, and joins the Tailnet using an auth key. Route advertisement is configured manually after provisioning.
2. **Isolated Basic VM (`basicubuntu`)**: A standard Ubuntu instance with no Tailscale agent. It exists purely to validate that traffic routed through the subnet router reaches a private IP that is not directly on the Tailnet.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [Tailscale account](https://tailscale.com/docs/how-to/quickstart) and a reusable auth key
    * To obtain auth key: [Tailscale Admin Console > Settings > Keys > Generate auth key](https://tailscale.com/docs/features/access-control/auth-keys#generate-an-auth-key)
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

You can set environment variables using the `TF_VAR_` prefix to a variable name. Required variables (those without a default) must be exported after they are obtained in the Prerequisites section. Optional variables with a default can be overridden the same way, for example, `export TF_VAR_region="sfo3"` to deploy to a different region.

## Deployment

### 1. Set variables

```bash
export TF_VAR_do_token="your_digitalocean_token"
export TF_VAR_tailscale_auth_key="your_tailscale_auth_key"
export TF_VAR_ssh_key_id="your_digitalocean_numeric_ssh_id"
```

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
Check `tailscale status` from your local machine to confirm `tailscalesubnet` has joined your Tailnet:
```bash
tailscale status
```
SSH into the subnet router using Tailscale SSH as `demo` user:
 
```bash
ssh demo@tailscalesubnet
```
 
Inside the SSH session, advertise the VPC's CIDR using the `vpc_ip_range` value from the Terraform output:
 
```bash
sudo tailscale set --advertise-routes=<vpc_ip_range>
```

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
├── architecture.png    # Visual representation of the VPC and Tailnet bridge
├── cloud_init.tftpl    # cloud-init template run on first boot of the Subnet Router
├── main.tf             # Droplet resources and the dynamic VPC data source
├── outputs.tf          # Provisioning data: Router IP, Test IP, and VPC CIDR
├── providers.tf        # Terraform & DigitalOcean provider version constraints
├── variables.tf        # Input variable declarations with types and defaults
├── .terraform.lock.hcl # Dependency lock file to ensure provider version consistency
└── .gitignore          # Excludes .tfstate, .terraform/, and local secrets
```
 
## Design notes
 
Route advertisement is handled as post-provisioning step rather than being baked into `cloud-init`. Fetching the default VPC address range at provisioning time may be unreliable. By retrieving the VPC range via a Terraform data source and providing it as a verified output, we eliminate the risk of misconfiguration that often occurs when deploying to regions with non-standard CIDR assignments.
 
Having a second Droplet (`basicubuntu`) is intentional. It allows us to validate that using a subnet router, devices on a Tailnet can reach devices on the subnet that are not running Tailscale locally. 