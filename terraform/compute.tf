locals {
  compartment_id = var.compartment_ocid != "" ? var.compartment_ocid : var.tenancy_ocid

  availability_domain = var.availability_domain != "" ? var.availability_domain : (
    data.oci_identity_availability_domains.ads.availability_domains[0].name
  )

  image_id = var.image_id_override != "" ? var.image_id_override : (
    length(data.oci_core_images.ubuntu_2404.images) > 0
    ? data.oci_core_images.ubuntu_2404.images[0].id
    : data.oci_core_images.ubuntu_2204.images[0].id
  )
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu_2404" {
  compartment_id           = local.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.shape
  state                    = "AVAILABLE"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

data "oci_core_images" "ubuntu_2204" {
  compartment_id           = local.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = var.shape
  state                    = "AVAILABLE"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "minecraft" {
  availability_domain = local.availability_domain
  compartment_id      = local.compartment_id
  display_name        = var.instance_name
  shape               = var.shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  # main.tf exported from the console had assign_public_ip = false, which
  # makes the server unreachable from the internet.
  create_vnic_details {
    subnet_id        = oci_core_subnet.minecraft.id
    assign_public_ip = true
    hostname_label   = "mc"
    display_name     = "${var.instance_name}-vnic"
  }

  source_details {
    source_type             = "image"
    source_id               = local.image_id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  # Do not leave orphaned boot volumes behind on destroy: the Always Free
  # block storage allowance is only 200 GB in total.
  preserve_boot_volume = false

  metadata = {
    ssh_authorized_keys = join("\n", var.ssh_public_keys)
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
      mc_version     = var.mc_version
      mc_port        = var.mc_port
      mc_xms         = var.mc_xms
      mc_xmx         = var.mc_xmx
      install_script = base64encode(file("${path.module}/../scripts/install-minecraft.sh"))
    }))
  }

  availability_config {
    recovery_action = "RESTORE_INSTANCE"
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  timeouts {
    create = "40m"
  }
}
