
# Oracle Cloud Web Server Provisioning with Terraform
[![Terraform](https://img.shields.io/badge/Terraform-v1.5%2B-blue.svg)](https://www.terraform.io/)
[![OCI Provider](https://img.shields.io/badge/OCI%20Provider-v5%2B-orange.svg)](https://registry.terraform.io/providers/hashicorp/oci/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This Terraform repository automates the provisioning of production-ready, publicly accessible web servers on Oracle Cloud Infrastructure (OCI). Each instance is deployed with a fully hardened LAMP stack (Ubuntu 22.04, Apache, PHP 8, PostgreSQL 16) including automatic security updates, modern HTTP headers, and server-side hardening applied immediately via Ansible.
## Features

- **Fully Automated Deployment:** Provision real, live web servers on Oracle Cloud with a simple `terraform apply` command.
- **Pre-configured Stack:** Apache 2.4, PHP 8.1, and PostgreSQL 16 installed on Ubuntu 22.04 LTS.
- **Public Access:** Each server gets a real public IP address, making it immediately accessible via HTTP and SSH.
- **Security-First Configuration:** Hardened server with modern HTTP security headers and PHP functions disabled.
- **Auto Updates:** Configured with unattended-upgrades and daily auto-reboots for security patches.

## Components and Technologies

- **Oracle Cloud** – Hosting platform (OCI)
- **Ubuntu** – Operating system (22.04 LTS)
- **Terraform** – Infrastructure as Code tool
- **Apache** – Web server (Apache 2.4)
- **PHP** – Version 8.1
- **PostgreSQL** – Version 16 (official repository)

## What Gets Installed (As of November 2025)

| Component         | Exact Version / Detail                                        |
|-------------------|---------------------------------------------------------------|
| **OS**            | Canonical Ubuntu 22.04 LTS (latest available image)           |
| **Web Server**    | Apache 2.4                                                   |
| **PHP**           | PHP 8.1 (Ubuntu 22.04 default)                                |
| **Database**      | PostgreSQL 16 (official repository)                           |
| **Web Root**      | `/var/www/html/index.php` – Clean "It works" page with server info |
| **Open Ports**    | 22 (SSH), 80 (HTTP), 443 (HTTPS)                              |
| **Security**      | PHP dangerous functions disabled, `expose_php = Off`, Modern HTTP security headers, `ServerSignature Off`, `ServerTokens Prod` |
| **Auto Updates**  | `unattended-upgrades` configured, auto-reboot at 04:30 daily |
| **Iptables Fix**  | Oracle’s default REJECT-all rule removed for port 80 access   |
| **Public IPs**    | Yes, each VM gets a real public IP                            |
| **Cloud-Init + Ansible** | Runs immediately after first boot – zero manual steps    |

## Prerequisites

- **Terraform** – Ensure you have Terraform installed. [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- **Oracle Cloud Account** – You must have an Oracle Cloud account and set up your OCI credentials. [Create an Oracle Cloud Account](https://www.oracle.com/cloud/free/)
- **OCI CLI** – Install the Oracle Cloud Infrastructure Command Line Interface (CLI) to authenticate and interact with your OCI tenancy. [OCI CLI Installation Guide](https://docs.oracle.com/en-us/iaas/Content/SDKDocs/cliinstall.htm)

## Usage and General Oracle Cloud Always Free Tier Limits:
-Proceed with caution on additional cost allocation as currently:

-These are the listed support for free-tier within OCI as of Nov.2025. 
- 2 VMs (each with 1 OCPU and 1 GB RAM) eligible for Always Free.

- Block Storage:

- 100 GB of block storage (shared across all free-tier VMs).

- Public IPs:

- 1 Public IP per free VM is free (additional ones might incur charges).

- Bandwidth:

- 10 TB outbound data transfer per month is free.

## Security Overview – Hardened & Ready for Production

This repository deploys **fully hardened, auto-updating LAMP + PostgreSQL 16** servers on Oracle Cloud.
## !! Security Note !!

Currently port 80 is open, HTTP only:

- No encryption (plain HTTP)
- No authentication
- !! Web Servers are only configured with HTTP as of Nov, 2025  !!

### Open Ports (Controlled at OCI Security List Level)

| Port | Protocol | Purpose               | Open to         | Security Status                                      |
|------|----------|-----------------------|-----------------|------------------------------------------------------|
| 22   | TCP      | SSH access            | 0.0.0.0/0       | **Key-only authentication** (password login disabled) |
| 80   | TCP      | HTTP web server       | 0.0.0.0/0       | Open (plain HTTP -)          |
| 443  | TCP      | HTTPS                 | 0.0.0.0/0       | Open and waiting for SSL (Manual HTTPS setup Required, Optional)                 |

**All other ports are blocked** – no extra rules exist in the VCN security list.

### Server-Side Hardening (Applied Automatically by Ansible)

| Category                     | Hardening Measures                                                                                                                                    |
|------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Automatic Updates**        | `unattended-upgrades` + daily security patches + auto-reboot at 04:30 if needed                                                                      |
| **PHP Security**             | Dangerous functions disabled (`exec`, `shell_exec`, `system`, `popen`, etc.)<br>`expose_php = Off` (hides PHP version)                                |
| **Apache Hardening**         | `ServerTokens Prod` · `ServerSignature Off` · `TraceEnable Off`<br>No directory listing (`-Indexes`)<br>ETags removed                                      |
| **2025 Security Headers**    | `X-Content-Type-Options: nosniff`<br>`X-Frame-Options: DENY`<br>`Referrer-Policy: strict-origin-when-cross-origin`<br>Strict CSP & Permissions-Policy |
| **Database**                 | PostgreSQL 16 bound to localhost only (not exposed)                                                                                                   |
| **Principle of Least Privilege** | Web files owned by `www-data`<br>Minimal packages installed                                                                                       |
| **SSH Access**               | Only your public key (`~/.ssh/my_oci_key.pub`) is authorized – password authentication is impossible                                                |


# Step 1. Clone the repository:

   ```bash
   git clone github.com/BrandynLo/OCI_WebHosting_Terraform
   ```

## Prerequisites
| Requirement | Details |
|-----------|---------|
| **OCI Account** | Free Tier or Paid [](https://www.oracle.com/cloud/) |
| **Terraform** | `v1.5+` |
| **OCI CLI** | Latest version |
| **OS** | Tested on **Ubuntu 22.04+** (VM or local) |
## Install Terraform (Ubuntu/Debian)
```bash
sudo apt update && sudo apt install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```
## OCI Setup

### 1. Create a Dedicated Compartment

1. Log in to the **OCI Console**  
2. Navigate to **Identity & Security → Compartments**  
3. Click **Create Compartment**  

   **Fill in the details:**  
   - **Name:** `terraform-vcn-demo`  
   - **Description:** `Compartment for Terraform VCN & VM demo`  
   - **Parent Compartment:** (leave default or select your root)  

4. Click **Create Compartment**  
5. **Copy the Compartment OCID** — you’ll need it in `terraform.tfvars`

   ![Create Compartment](https://github.com/user-attachments/assets/6df370d6-7e62-467c-b394-a5a7b00092e1)  
   ![Compartment OCID](https://github.com/user-attachments/assets/3817f7d4-44ba-4a4a-91ee-88d591f71daa)

---


### Step 1: Set up OCI CLI
Before running Terraform, configure the OCI CLI with your Oracle Cloud credentials. Run:
 ```bash
   $ oci setup config
```
This will create a `~/.oci/config` file. You need to edit this file with your personal OCI details.

### Step 2: Edit the config file
Navigate to the `~/.oci` directory and open the `config` file in a text editor:
 ```bash
   $ cd ~/.oci
   $ sudo nano config
```
The file should look something like this:

- `user`: Your OCI user OCID (found in the OCI Console).
- `fingerprint`: The public SSH key fingerprint you will generate.
- `key_file`: The path to your private SSH key (`oci_api_key.pem`).
- `tenancy`: Your OCI tenancy OCID.
- `region`: Your Oracle Cloud region (e.g., `us-ashburn-1`).

### Step 3: Generate an SSH key pair
Generate an SSH key pair to authenticate with OCI and add the public key to your Oracle Cloud account:
```bash
   $ ssh-keygen -t rsa -b 2048 -f ~/.oci/oci_api_key.pem
   $ cat ~/.oci/oci_api_key.pem
```
Take the output from `cat ~/.oci/oci_api_key.pem.pub` and add this to your public API key in OCI **Identity > API Keys**.
Upload the public key in OCI Console → Identity & Security → Users → [Your User] → API Keys → 
<img width="1910" height="560" alt="image" src="https://github.com/user-attachments/assets/28daa9b7-7412-4e67-9029-9fe21b63f01a" />

This will have the fingerprint ID that will be used in your main.tf credentials for "fingerprint". 

### Step 3.5: Generate an SSH key pair within ~/.ssh 
```bash
ssh-keygen -t rsa -b 2048 -f ~/.ssh/my_oci_key -N ""
```
This SSH key is meant to be used for the VMs to link your personal machine to them. DO NOT LOSE THIS.
These keys will be located in ~/.ssh/my_oci_key.pub

## Install Ansible
```bash
sudo apt update && sudo apt install -y ansible
```
**Deploy with Terraform**
1. Initialize the Terraform configuration:
```bash
   $ terraform init
```
<img width="756" height="354" alt="image" src="https://github.com/user-attachments/assets/4c8c0896-8b1a-4dfd-9416-0b6b22f0bf15" />

# Apply the configuration to create the VCN:
- You will be prompted for compartment ID. This is located on your OCI container you made on the OCI website. 
- Below is CODE Syntax:
```bash
# 1. Deploy (just pass compartment ID)
terraform apply -var="compartment_id=ocid1.compartment.oc1..aaaa..."

# 1.5 Deploy Just One Container
terraform apply

# 2. VMs with default names
terraform apply -var="compartment_id=..." -var="vm_count=5"

# 3. VMs with custom names  
terraform apply -var="compartment_id=..." -var='vm_names=["web1","db1","app1"]'

# 4. Both together
terraform apply -var="compartment_id=..." -var="vm_count=5" -var='vm_names=["web1","db2","app1","cache1","cache2"]'
```
<img width="1918" height="1030" alt="image" src="https://github.com/user-attachments/assets/3670e5b5-df72-4c63-9e4a-d383dd847b3e" />
<img width="1919" height="1030" alt="image" src="https://github.com/user-attachments/assets/91824bca-7fed-44a7-9e64-d280767daecc" />

# SSH + Website Edits 

```bash
ssh -i ~/.ssh/my_oci_key ubuntu@x.x.x.x
sudo nano /var/www/html/index.php
```
<img width="1174" height="669" alt="image" src="https://github.com/user-attachments/assets/e4f10186-91bf-40eb-9a32-e4f3805ddf19" />

- These are the index.php webpages that will now be defaulted to when a user searches up your ip address to your site like 150.x.x.x; It will take them to this new "index.php" file we made.
- The previous screenshots are to the direct IP address and were "defaulted" to the default apache site. But now, it will be heading to the php interface we just made.
- Add configurations, buttons, and links as you build your website within this and learn how to loadbalance it later! 
- Also keep in mind you'll likely need a domain so people won't need to ping your server directly to x.x.x.x everytime. This is where a domain is helpful. 
- Additionally you'll want to have HTTPS and prevent attacks on your server, so cloudflare and other providers might be a great option.
- I made a project using K8 Clusters to host web servers using cloudflare and provide a short tutorial on that repo. Take a look if you can. Thank you! 

<img width="1919" height="1035" alt="image" src="https://github.com/user-attachments/assets/beb6250d-37c8-4e44-9749-c209ed6d0ac7" />
<img width="1919" height="1035" alt="image" src="https://github.com/user-attachments/assets/932c1a13-b00c-423e-8623-ece69d6f7c0c" />

