# Throwaway root module whose only job is to prove the state backend can
# accept a write. The workflow applies this BEFORE creating any OCI resource,
# because Terraform uploads state only at the end of an apply: if the upload
# is rejected, everything the apply created is left orphaned and untracked.
#
# It uses the built-in terraform_data resource, so it needs no providers and
# finishes in a couple of seconds.

terraform {
  required_version = "~> 1.17"

  backend "oci" {}
}

resource "terraform_data" "state_probe" {
  input = "state backend write check"
}
