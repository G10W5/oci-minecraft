output "public_ip" {
  description = "Public IPv4 address of the Minecraft server."
  value       = oci_core_instance.minecraft.public_ip
}

output "minecraft_address" {
  value = "${oci_core_instance.minecraft.public_ip}:${var.mc_port}"
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/oci-minecraft.key ubuntu@${oci_core_instance.minecraft.public_ip}"
}

output "instance_ocid" {
  value = oci_core_instance.minecraft.id
}

output "availability_domain" {
  value = oci_core_instance.minecraft.availability_domain
}

output "image_used" {
  value = local.image_id
}
