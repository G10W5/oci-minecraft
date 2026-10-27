resource "oci_core_vcn" "minecraft" {
  compartment_id = local.compartment_id
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "${var.instance_name}-vcn"
  dns_label      = "mcvcn"
}

resource "oci_core_internet_gateway" "minecraft" {
  compartment_id = local.compartment_id
  display_name   = "${var.instance_name}-igw"
  enabled        = true
  vcn_id         = oci_core_vcn.minecraft.id
}

resource "oci_core_default_route_table" "minecraft" {
  manage_default_resource_id = oci_core_vcn.minecraft.default_route_table_id
  display_name               = "${var.instance_name}-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.minecraft.id
  }
}

# The OCI Ubuntu image ships with only port 22 open, and the VCN default
# security list inherits that. Minecraft needs its own ingress rule.
resource "oci_core_default_security_list" "minecraft" {
  manage_default_resource_id = oci_core_vcn.minecraft.default_security_list_id
  display_name               = "${var.instance_name}-sl"

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    description = "SSH"

    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    description = "Minecraft"

    tcp_options {
      min = var.mc_port
      max = var.mc_port
    }
  }

  # Path MTU discovery: clients hang on connect without this.
  ingress_security_rules {
    protocol    = "1" # ICMP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    description = "ICMP fragmentation needed"

    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_subnet" "minecraft" {
  compartment_id             = local.compartment_id
  cidr_block                 = "10.0.0.0/24"
  display_name               = "${var.instance_name}-subnet"
  dns_label                  = "mcsubnet"
  vcn_id                     = oci_core_vcn.minecraft.id
  route_table_id             = oci_core_vcn.minecraft.default_route_table_id
  security_list_ids          = [oci_core_vcn.minecraft.default_security_list_id]
  prohibit_public_ip_on_vnic = false
}
