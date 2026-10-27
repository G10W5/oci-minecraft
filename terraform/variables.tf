variable "tenancy_ocid" {
  description = "Tenancy OCID. Supplied by the TF_VAR_tenancy_ocid secret."
  type        = string
}

variable "user_ocid" {
  description = "User OCID that owns the API signing key."
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the OCI API signing key."
  type        = string
}

variable "private_key_path" {
  description = "Path to the OCI API signing private key on the runner."
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "compartment_ocid" {
  description = "Compartment to deploy into. Empty means the tenancy root compartment."
  type        = string
  default     = ""
}

variable "region" {
  description = "Home region. Always Free resources only exist here."
  type        = string
  default     = "eu-turin-1"
}

variable "shape" {
  type    = string
  default = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  type    = number
  default = 2
}

variable "memory_in_gbs" {
  type    = number
  default = 12
}

variable "boot_volume_size_in_gbs" {
  description = "Always Free block storage is 200 GB total; 50 GB is the OCI default."
  type        = number
  default     = 50
}

variable "instance_name" {
  type    = string
  default = "mc-server"
}

variable "availability_domain" {
  description = "Force a specific AD (e.g. qdzu:EU-TURIN-1-AD-1). Empty = auto-detect."
  type        = string
  default     = ""
}

variable "image_id_override" {
  description = "Force an image OCID. Empty = newest Canonical Ubuntu for the shape."
  type        = string
  default     = ""
}

variable "mc_port" {
  type    = number
  default = 25565
}

variable "mc_version" {
  description = "Minecraft version the Fabric server is installed for, on first boot only."
  type        = string
  default     = "1.21.4"
}

variable "mc_xms" {
  type    = string
  default = "2G"
}

variable "mc_xmx" {
  type    = string
  default = "10G"
}

# All three keypairs you generated are authorised, so whichever private key you
# end up holding can log in. Prune this list later once you have settled on one.
variable "ssh_public_keys" {
  type = list(string)
  default = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC3pvv+8DN+4ZjeKOvP18FCt+sExoLBwHj1hCNW9y7yudlqfvggxhmR9xNtGszJEmi4K+ywoALQc9zbuaWWJBVGVeIBtYdGGTrI7fkQNbPkfP+nvoa/b6nZvB9/d/xcLX0ujDdtRJ/2CMy+iRetw5lhEvpKS1NsGPbU3pZpvFufjyKxnbzIiyoc8ykTTllr6xm3l9j3GZ6Symk/jvZHdW5sPeg9W1eLf53T+IPJBuNfWLqteB9mJlEurVFW5QNHa0ey+j3r/GNQ1egEByzzxiLWoGCGXCpB9FH9WBk+SdM4c8xaktkH76/AhJjpBRbt4mRcx3HQpZtDUyUxLL3YDR29 ssh-key-2026-10-26",
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDj2tFlzD1KK9FwT+qWGWnC9qASf3L5kotqrqKbSMKA3qkrFVL1qM+oo5trI2qUqYsWHP2J4SQqjIqT/hkM6cxSGue8+bY+8TO5D+bCBJ1k1mTrmCvR4ddRzu6kqG/cqNfl10e5TGKaftOj9oMNXJDzD9/dObTUS/msWplLHxgNxxT9x08Y8VXqvrp5zwwrKrervrKgWU6lzotI/r9Pw0j0cZaQugvuaotsIeorQViXVQ3vv8zQCcqV9/RZw6UH/u/tWYeK/tGqQmYEW3GaIUen6uTpem0rzE5W5fMIHOgeBD0P8q//RcOx7RIQeL7uhc3g47cTNONcafyyhpJ/sam9 ssh-key-2026-10-26-new",
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDVipRh7/zRKraqEzv2V//fY6svXarHBqE85Kf6lOhYY9YZ/0GqlvtmOyzGrgvvWHi8LbLVlEDpfKJuEDg+t00uyJZ3arl3hjOuB5OBHT9x4TNexr1GFHTom4YTWpcYnlrYmdlyPOZneyd9UA6KvaDwRPSDoDF8ieznAGmV1PuJi2fjah/0quPTbIhkpih113T3HoSVUZq2w2uGmAT/n5u4rCvHZDyV84afSE69TjVUQIC4DZmDC+dhnIRKgYsMkHMQCfXRHqzLwxEbrBBtV9HhEbfKoGLplKBy7z8a52I/FeSNL2dnMDX2FOR1QAs14DjS2KyouLbGfR7b/mh9PMPx ssh-key-2026-10-26-alt",
  ]
}
