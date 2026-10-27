terraform {
  required_version = "~> 1.17"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.11"
    }
  }

  # Partial configuration: the workflow supplies the rest with -backend-config,
  # so no bucket names or keys ever live in git.
  backend "s3" {}
}

provider "oci" {
  auth             = "APIKey"
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}
