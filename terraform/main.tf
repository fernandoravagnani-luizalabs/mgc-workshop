# ---------------------------------------------------------------------------
# Infraestrutura do workshop na Magalu Cloud (MGC)
# Provider oficial: MagaluCloud/mgc
# Recursos criados:
#   - Chave SSH (mgc_ssh_keys)
#   - Máquina Virtual com IP público (mgc_virtual_machine_instances)
#     (usa o Security Group default da conta/região)
#   - Bucket Object Storage (mgc_object_storage_buckets) para as mídias
#   - Provisionamento/configuração/deploy via Ansible (null_resource)
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    mgc = {
      source  = "MagaluCloud/mgc"
      version = "~> 0.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "mgc" {
  api_key         = var.mgc_api_key
  region          = var.region
  key_pair_id     = var.object_storage_access_key
  key_pair_secret = var.object_storage_secret_key
}

# ---------------------------------------------------------------------------
# Chave SSH
# ---------------------------------------------------------------------------
resource "mgc_ssh_keys" "workshop" {
  name = var.ssh_key_name
  key  = var.ssh_public_key
}

# ---------------------------------------------------------------------------
# Máquina Virtual (usa o Security Group 'default' da VPC/região)
# ---------------------------------------------------------------------------
resource "mgc_virtual_machine_instances" "site" {
  name                 = var.vm_name
  machine_type         = var.machine_type # ex.: BV2-2-8 (2 vCPU / 8 GB)
  image                = var.image        # ex.: cloud-ubuntu-24.04 LTS
  ssh_key_name         = mgc_ssh_keys.workshop.name
  allocate_public_ipv4 = true
  availability_zone    = var.availability_zone
}

# ---------------------------------------------------------------------------
# Bucket Object Storage (mídias do WordPress)
# ---------------------------------------------------------------------------
resource "mgc_object_storage_buckets" "media" {
  bucket     = var.bucket_name
  versioning = false
}

# Deixa o bucket público para leitura (serve as mídias do site)
resource "null_resource" "bucket_public_policy" {
  depends_on = [mgc_object_storage_buckets.media]

  provisioner "local-exec" {
    command = <<-EOT
      mgc object-storage buckets policy set \
        --dst ${mgc_object_storage_buckets.media.bucket} \
        --policy '${templatefile("${path.module}/templates/bucket-policy.json", {
    bucket_name = mgc_object_storage_buckets.media.bucket
})}'
    EOT
}
}

# ---------------------------------------------------------------------------
# Provisionamento / configuração / deploy via Ansible
# O provisioner local chama o ansible-playbook contra o IP público da VM.
# ---------------------------------------------------------------------------
resource "null_resource" "deploy_wordpress" {
  depends_on = [
    mgc_virtual_machine_instances.site,
    mgc_object_storage_buckets.media,
  ]

  # Só roda de novo se a VM ou o bucket mudarem (ou via taint)
  triggers = {
    vm_id        = mgc_virtual_machine_instances.site.id
    bucket_name  = mgc_object_storage_buckets.media.bucket
    ssh_key_name = mgc_ssh_keys.workshop.name
    public_ip    = mgc_virtual_machine_instances.site.ipv4
  }

  # Gera o inventário do Ansible com o IP da VM
  provisioner "local-exec" {
    command = <<-EOT
      cat > ${path.module}/../ansible/inventory/hosts.ini <<EOF
      [wordpress]
      ${mgc_virtual_machine_instances.site.ipv4} ansible_user=ubuntu ansible_ssh_private_key_file=${var.ssh_private_key_path}
      EOF
    EOT
  }

  # Roda o playbook de deploy
  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../ansible && \
      ansible-playbook -i inventory/hosts.ini playbook.yml \
        -e "bucket_name=${mgc_object_storage_buckets.media.bucket}" \
        -e "object_storage_access_key=${var.object_storage_access_key}" \
        -e "object_storage_secret_key=${var.object_storage_secret_key}" \
        -e "object_storage_endpoint=${var.object_storage_endpoint}" \
        -e "object_storage_region=${var.region}"
    EOT
  }
}
