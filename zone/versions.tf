terraform {
  # Terragrunt's remote_state fills this in.
  backend "s3" {}

  required_version = ">= 1.12.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.26"
    }
  }
}

# No provider block: the provider reads CLOUDFLARE_API_TOKEN from the environment.
# Terragrunt leaves set it per account via extra_arguments env_vars, so the token never lands on disk.
