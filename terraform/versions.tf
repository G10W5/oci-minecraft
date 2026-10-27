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
  #
  # The native OCI backend (Terraform 1.12+) is required here. The S3-compatible
  # backend cannot upload state to OCI Object Storage: every PutObject carries
  # "content-encoding: aws-chunked", which OCI rejects with
  # 501 NotImplemented - "AWS chunked encoding not supported".
  backend "oci" {}
}

provider "oci" {
  auth             = "APIKey"
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}
