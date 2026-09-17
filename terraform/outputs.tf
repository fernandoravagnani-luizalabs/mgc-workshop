# ---------------------------------------------------------------------------
# Outputs úteis do workshop.
# ---------------------------------------------------------------------------

output "public_ip" {
  description = "IP público da VM (abrir no navegador)."
  value       = mgc_virtual_machine_instances.site.ipv4
}

output "bucket_name" {
  description = "Nome do bucket de mídias."
  value       = mgc_object_storage_buckets.media.bucket
}

output "wp_url" {
  description = "URL para finalizar a instalação do WordPress."
  value       = "http://${mgc_virtual_machine_instances.site.ipv4}"
}

output "ssh_command" {
  description = "Comando SSH para conectar na VM."
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${mgc_virtual_machine_instances.site.ipv4}"
}
