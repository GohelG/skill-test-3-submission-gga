# Azure DevOps Practice: Terraform, Ansible, and Jenkins

A production-grade implementation of Infrastructure as Code (**Terraform** on Azure), Configuration Management & Deployments (**Ansible**), and Continuous Integration / Continuous Delivery (**Jenkins**), featuring comprehensive **Git Cache and Repository Security Management**.

---

## 🏛 Architecture & Technology Stack

### System Architecture

```text
                               +-----------------------------+
                               |     Git Developer Client    |
                               +--------------+--------------+
                                              |
                                            Push
                                              v
                               +-----------------------------+
                               |    Azure Jenkins VM (CI/CD) |
                               |  (Java 17, Docker, Ansible) |
                               +--------------+--------------+
                                              |
                                           Deploy
                      +-----------------------+-----------------------+
                      |                                               |
                      v                                               v
     +---------------------------------+             +---------------------------------+
     |       Azure Standard ALB        |             |       Azure VM (Web Tier)       |
     |  (Public HTTP / Health Probes)  |             |      (Apache2, UFW, motd)       |
     +----------------+----------------+             +----------------+----------------+
                      |                                               |
                      v                                               v
     +---------------------------------+             +---------------------------------+
     |   Azure VM Scale Set (VMSS)     |             |       Azure VM (DB Tier)        |
     |   (2-4 Instances, Autoscale)    |             |      (MySQL Server, UFW)        |
     +---------------------------------+             +---------------------------------+
```

### Technology Stack

| Layer / Component | Technology / Service | Purpose |
| :--- | :--- | :--- |
| **Version Control** | Git | Source code management and deployment trigger |
| **CI/CD & Automation** | Jenkins, Java 17, Docker, Ansible | Automated builds, containerization, and configuration management |
| **Load Balancing** | Azure Standard ALB | Public HTTP traffic routing and instance health checks |
| **Compute (Autoscaling)** | Azure VM Scale Set (VMSS) | Elastic scaling across 2 to 4 virtual machine instances |
| **Web Tier** | Azure VM (Apache2, UFW) | Web server hosting, firewall rules, and custom login banner (`motd`) |
| **Database Tier** | Azure VM (MySQL Server, UFW) | Relational data storage secured with host-level firewall rules |

---

## 📂 Project Folder Structure

```text
.
├── .gitignore
├── README.md
├── terraform/
│   ├── provider.tf                      # AzureRM & TLS key providers
│   ├── main.tf                          # Root module orchestrator & ALB/VMSS
│   ├── variable.tf                      # Global input variables
│   ├── output.tf                        # Public IPs, URLs, SSH key file paths
│   ├── terraform.tfvars                 # Environment deployment variables
│   └── module/
│       ├── network/                     # VNet (10.0.0.0/16), public/private subnets, RT
│       ├── security/                    # NSG rules (HTTP: 80, SSH: 22, Jenkins: 8080)
│       ├── storage/                     # Azure Storage Account with Blob versioning
│       ├── vm/                          # Web & Database virtual machines
│       └── jenkins/                     # Dedicated Jenkins CI VM with bootstrap cloud-init
│
├── ansible/
│   ├── ansible.cfg                      # Roles path, default user, SSH configuration
│   ├── inventory.ini                    # Web & DB target host groupings
│   ├── site.yaml                        # Master playbook covering Tasks 1, 2, 3, and 4
│   ├── groups_var/
│   │   ├── all.yml                      # Shared application configurations
│   │   ├── dev.yml                      # Development database & flags
│   │   ├── staging.yml                  # Staging configuration
│   │   └── prod.yml                     # Production vault-encrypted secrets
│   ├── role/
│   │   └── webapp/
│   │       ├── tasks/main.yml           # Git clone, permissions, vhost setup
│   │       ├── templates/vhost.conf.j2  # Dynamic Apache VirtualHost
│   │       └── vars/main.yml            # Default application variables
│   └── advanced-deployment/
│       └── rolling_update.yml           # Zero-downtime rolling update + rollback logic
│
└── Jenkins/
    └── Jenkinsfile                      # Declarative CI/CD pipeline (Dev -> Staging -> Prod)
```

---

## ⚙️ Prerequisites & Workstation Setup

1. **Operating System**: Linux (Ubuntu 22.04 LTS), macOS, or Windows with WSL2.
2. **Azure CLI**: Authenticate your session and set your subscription:
   ```bash
   az login
   az account set --subscription "<YOUR_AZURE_SUBSCRIPTION_ID>"
   ```
3. **Core Binaries**:
   ```bash
   terraform -version   # Must be >= 1.5.0
   ansible --version     # Must be >= 2.14
   git --version         # Must be >= 2.30
   ```
4. **SSH Key Pair**:
   ### For Linux OS
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
   ```
   ### For Windows OS 
   ```powershell
   # Create the directory if it does not exist
   New-Item -ItemType Directory -Force -Path "\$env:USERPROFILE\Downloads\multicloud-key"
   # Generate a RSA SSH key pair without a passphrase
   ssh-keygen -t rsa -b 4096 -f "\$env:USERPROFILE\Downloads\multicloud-key\azure_vm_key" -N '""'
   ```
---

## 🚀 Part 1: Terraform Infrastructure Tasks (Azure)

### Task 1: Basic Virtual Machine Provisioning
Provisions the root Azure Resource Group and an initial `Standard_B1s` Ubuntu 22.04 LTS Virtual Machine with standard resource tags (`Environment = "Practice"`).

### Task 2: Virtual Network & Subnet Segmentation
Configures network isolation matching the specification:
- Virtual Network: `10.0.0.0/16`
- Public Subnet: `10.0.1.0/24` (Direct Internet route via Route Table)
- Private Subnet: `10.0.2.0/24` (Isolated backend database subnet)

### Task 3: Automated Apache Web Server & Storage
Deploys a Network Security Group allowing Inbound HTTP (`80`) and SSH (`22`), bootstrapping Apache using base64-encoded `user_data`, and deploying an **Azure Storage Account** with Blob versioning enabled (`versioning_enabled = true`).

### Task 4: Modular Architecture & Remote State
Refactors infrastructure into isolated reusable components under `terraform/module/`:
- `network`: VNet, Subnets, Route Table associations.
- `security`: NSG security rules and NIC associations.
- `storage`: S3-equivalent versioned Blob container.
- `vm`: Compute instances configured with dynamic OpenSSH keys.
- `jenkins`: Controller host with pre-installed Java, Docker, and Jenkins LTS.

### Task 5: Load Balancing & Autoscaling Scale Set (VMSS)
Provisions an Azure Standard Load Balancer (ALB equivalent) with frontend IP, backend pool, health probe on `/`, and an HTTP load-balancing rule. Deploys an Azure Virtual Machine Scale Set (VMSS) across availability zones (min: 2, max: 4 instances) with auto-scaling rules triggering when average CPU utilization exceeds **70%**.

#### Execution Commands
```bash
cd terraform

# 1. Initialize providers and child modules
terraform init

# 2. Validate code syntax and arguments
terraform validate

# 3. View planned resource creations
terraform plan -out=tfplan

# 4. Provision infrastructure
terraform apply tfplan

# 5. Extract operational endpoints
terraform output web_vm_public_ip
terraform output load_balancer_ip
terraform output jenkins_url
```

---

## 🤖 Part 2: Ansible Configuration & Deployment Tasks

### Task 1: Connectivity & System Cache Updates
Verifies connectivity to all targets using the `ping` module and updates the APT package cache:
```bash
cd ansible
ansible -i inventory.ini all -m ping
ansible-playbook -i inventory.ini site.yaml --tags "cache"
```

### Task 2: Server Tier Configuration & Dynamic MOTD
Configures two distinct server tiers in `inventory.ini`:
- `[web]`: Installs Apache2, configures UFW rules for port 80, dynamic MOTD banner, and notification handlers.
- `[db]`: Installs MySQL Server, configures UFW rules for port 3306, dynamic MOTD banner, and notification handlers.
```bash
ansible-playbook -i inventory.ini site.yaml
```

### Task 3: Web Application Role Deployment
Implements the modular `role/webapp` to clone application source code from Git, establish `www-data` ownership, render Apache VirtualHost configuration via Jinja2 (`vhost.conf.j2`), and restart services.

### Task 4: Multi-Environment Parameterization & Vault
Supports isolated configurations across `dev`, `staging`, and `prod` using dedicated `groups_var/`:
- Enforces pre-tasks verifying disk space (`size_available > 1GB`).
- Enforces post-tasks executing HTTP endpoint health checks.
- Encrypts sensitive production database credentials using Ansible Vault:
  ```bash
  ansible-vault encrypt groups_var/prod.yml
  ansible-playbook -i inventory.ini site.yaml -e "target_env=prod" --ask-vault-pass
  ```

### Task 5: Zero-Downtime Rolling Updates with Automated Rollback
Executes atomic, rolling software updates (`serial: 1`) on web tier nodes:
1. Deploys new code to a timestamped release directory: `/var/www/app/releases/<timestamp>`.
2. Executes automated smoke tests against the staged files.
3. Atomically updates the `/var/www/app/current` symlink.
4. If health check tests fail, the `rescue` block triggers an automatic rollback to the previous working symlink target.
```bash
ansible-playbook -i inventory.ini advanced-deployment/rolling_update.yml
```

---

## 🏗 Part 3: Jenkins CI/CD Pipeline Tasks

### Task 1: Controller Setup & Bootstrap
Bootstrap Jenkins using the Terraform Jenkins module or direct script:
```bash
# Retrieve unlock key from Jenkins VM
ssh -i ~/.ssh/id_rsa azureuser@<JENKINS_PUBLIC_IP>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```
Install recommended plugins: **Git**, **Pipeline**, **Pipeline: Stage View**, and **JUnit**.

### Task 2: Parameterized Multi-Stage Pipeline
The declarative `Jenkins/Jenkinsfile` provides:
- String parameter: `BRANCH_NAME` (default: `main`)
- Choice parameter: `ENVIRONMENT` (`dev`, `staging`, `prod`)
- Structured stages: `Checkout`, `Build`, `Test`, `Archive`

### Task 3: Parallel Quality Gates & Test Automation
- Concurrently runs **Unit Tests** and **Static Code Analysis / Linting**.
- Formats test outcomes into JUnit XML reports (`junit 'test-results/*.xml'`).
- Enforces a quality gate breaking the build if coverage falls below threshold.

### Task 4: Production Deployment Gate & Recovery
1. Deploys artifact to **Dev**.
2. Deploys artifact to **Staging** and executes integration tests.
3. Pauses execution for a **Manual Interactive Approval Gate** (2-day timeout limit).
4. Deploys to **Production** wrapped in an automated `try/catch` rollback handler.

---

## 🔍 Git Cache, Index & Secret Quarantine Guide

In Git, the **cache** refers directly to the **Index / Staging Area**. It serves as the intermediate snapshot layer where Git prepares changes before recording them into a commit.

```text
Working Directory                Git Cache (Index / Staging)                  Git Repository
(Local Disk Files)                     (Cached Files)                       (Committed History)
[main.tf]         --- git add --->        [main.tf]       --- git commit ---> [Commit Object]
[terraform.tfvars]                 [terraform.tfvars] (LEAK!)
```

> ⚠️ **Critical Rule**: Adding a pattern to `.gitignore` does **not** stop Git from tracking a file if that file was already added to the Git cache (index) in a previous step.

---

### 1. Understanding the Git Cache (Index / Staging Area)

When you run `git add <file>`, Git creates a SHA-1/SHA-256 content blob in `.git/objects/` and registers the path, permission mode, and object ID in `.git/index`. This tracked state is what `git rm --cached` modifies.

---

### 2. Auditing Cached & Staged Files

Use these commands to inspect what is currently held inside Git's index:

```bash
# 1. List every file currently tracked in Git's cache/index
git ls-files --cached

# 2. Inspect the index with permission modes and object hashes (stage view)
git ls-files --stage

# 3. List only files currently staged for the upcoming commit
git diff --cached --name-only

# 4. View line-by-line staged modifications ready to be committed
git diff --cached
```

---

### 3. Proactive Security Audits (Detect Leaked Secrets)

Before creating a commit or pushing to GitHub/GitLab, scan the Git index for accidentally cached state files, keys, and environment variables:

```bash
# Scan index for common sensitive patterns
git ls-files | grep -E '\.tfstate|\.tfstate\.backup|\.env|\.pem|\.key|id_rsa|terraform\.tfvars$|\.vault_pass'
```

If this command returns any output, **do not commit**. Proceed to the purging steps below immediately.

---

### 4. Purging Tracked Files from the Index (Preserving Disk Files)

To remove sensitive files from Git's tracking without deleting your local copy on disk, use `git rm --cached`:

```bash
# Untrack a single sensitive file
git rm --cached terraform/terraform.tfvars

# Untrack local Terraform state files
git rm --cached terraform/*.tfstate
git rm --cached terraform/*.tfstate.backup

# Untrack entire directories recursively (e.g., .terraform provider cache)
git rm -r --cached terraform/.terraform/

# Untrack SSH keys and certificates
git rm --cached *.pem
git rm --cached id_rsa
```

---

### 5. Complete Index Reset & Cache Rebuild Workflow

If multiple files were staged before updating `.gitignore`, rebuild and synchronize your entire Git cache safely:

```bash
# Step 1: Ensure your working directory has no uncommitted code you might lose
git status

# Step 2: Remove every file from the index recursively (working tree files are untouched)
git rm -r --cached .

# Step 3: Re-index your project respecting the rules in .gitignore
git add .

# Step 4: Verify the newly cleaned index
git status

# Step 5: Commit the sanitized index state
git commit -m "fix(git): re-index repository and purge cached ignored artifacts"
```

---

### 6. Emergency Secret Scrubbing (Git History Purge)

If a secret, SSH private key, or `terraform.tfvars` was **already committed** to local or remote history, standard `git rm --cached` is insufficient because the credential remains in previous commits.

Use `git filter-repo` (recommended over the deprecated `git filter-branch`):

```bash
# Install git-filter-repo (via pip)
pip install git-filter-repo

# Scrub a sensitive file completely from all branches and commit history
git filter-repo --invert-paths --path terraform/terraform.tfvars --force

# Force-push the sanitized history to remote (coordinate with team members)
git push origin --force --all
```

---

### 7. Hardened Project `.gitignore`

Ensure this `.gitignore` file is placed in your repository root:

```gitignore
# ==========================================
# Terraform State & Local Artifacts
# ==========================================
**/.terraform/
*.tfstate
*.tfstate.*
*.tfplan
*.tfplan.*
crash.log
crash.*.log

# ==========================================
# Terraform Variable & Secret Files
# ==========================================
# Disallow all tfvars except explicit documentation examples
*.tfvars
*.tfvars.json
*.auto.tfvars
*.auto.tfvars.json
!terraform.tfvars.example

# ==========================================
# Ansible Credentials & Cache
# ==========================================
*.retry
*.vault_pass
.ansible/
ansible/*/ansible.log

# ==========================================
# SSH Keys, Certs, and Secrets
# ==========================================
*.pem
*.key
*.pub
*.cer
*.pfx
id_rsa
id_rsa.pub
azure_vm_key.pem
.env
.env.*
!.env.example

# ==========================================
# CI/CD & Build Outputs
# ==========================================
build_output/
test-results/
coverage-reports/
reports/
*.bin
*.tar.gz
*.zip

# ==========================================
# OS & Editor Metadata
# ==========================================
.DS_Store
Thumbs.db
*.swp
*.swo
*~
.idea/
.vscode/
```

---

## 💰 Resource Teardown & Cost Optimization

To prevent ongoing cloud compute and public IP reservation charges, tear down all Azure resources immediately after completing evaluations:

```bash
# 1. Tear down Terraform infrastructure
cd terraform
terraform destroy -auto-approve

# 2. Confirm resource group deletion using Azure CLI
az group list --query "[?contains(name, 'practice') || contains(name, 'devops')].{Name:name, State:properties.provisioningState}" --output table

# 3. Clean local temporary state plans and logs
rm -f tfplan azure_vm_key.pem
```

---

# 👨‍💻 Author

**Gautam Gohel**

System Administrator | SRE Engineer | DevOps & Cloud Enthusiast 🚀

---
---
