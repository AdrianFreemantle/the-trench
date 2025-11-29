# Terraform env/dev

This folder contains the Terraform configuration for the **dev** environment.

It is intended to be run manually from this directory:

```bash
terraform init
terraform plan  -var-file="dev.secrets.tfvars"
terraform apply -var-file="dev.secrets.tfvars"
```

## Variables

The following input variables are defined in `variables.tf`:

- `environment`  
  Suffix for names (defaults to `dev`).

- `location`  
  Azure region (defaults to `southafricanorth`).

- `subscription_id`  
  Azure subscription ID for this environment.

- `tenant_id`  
  Azure AD tenant ID for this environment.

- `postgres_admin_password`  
  Admin password for the PostgreSQL Flexible Server.

## tfvars layout

Two tfvars files are used for local workflows:

- `dev.auto.tfvars` (checked-in)  
  Non-secret settings for this env:

  ```hcl
  subscription_id = "<your-subscription-id>"
  tenant_id       = "<your-tenant-id>"
  ```

  Terraform loads `*.auto.tfvars` automatically.

- `dev.secrets.tfvars` (**not committed**)  
  Secrets for this env. At minimum:

  ```hcl
  postgres_admin_password = "<strong-password>"
  ```

  This file is ignored by Git via `*.tfvars` rules in
  the root `.gitignore` and `infra/terraform/env/.gitignore`.

## Running Terraform

From this directory:

```bash
terraform init
terraform plan  -var-file="dev.secrets.tfvars"
terraform apply -var-file="dev.secrets.tfvars"
```

Ensure `dev.secrets.tfvars` exists locally before running these commands.
