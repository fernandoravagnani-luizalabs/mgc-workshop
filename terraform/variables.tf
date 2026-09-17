# ---------------------------------------------------------------------------
# Variáveis do workshop — ajuste conforme necessário.
# ---------------------------------------------------------------------------

variable "mgc_api_key" {
  type        = string
  sensitive   = true
  description = "API Key da Magalu Cloud (autenticação do provider)."
}

variable "region" {
  type        = string
  default     = "br-se1"
  description = "Região da Magalu Cloud."
}

variable "availability_zone" {
  type        = string
  default     = "br-se1-a"
  description = "Zona de disponibilidade da VM."
}

variable "vm_name" {
  type        = string
  default     = "site-web-01"
  description = "Nome da Máquina Virtual."
}

variable "machine_type" {
  type        = string
  default     = "BV2-2-8"
  description = "Flavor da VM (2 vCPU / 8 GB)."
}

variable "image" {
  type        = string
  default     = "cloud-ubuntu-24.04 LTS"
  description = "Imagem/SO da VM."
}

variable "ssh_key_name" {
  type        = string
  default     = "site-key"
  description = "Nome da chave SSH registrada na Magalu Cloud."
}

variable "ssh_public_key" {
  type        = string
  description = "Conteúdo da chave pública SSH (id_ed25519.pub)."
}

variable "ssh_private_key_path" {
  type        = string
  description = "Caminho local da chave privada SSH usada pelo Ansible (ex.: ~/.ssh/id_ed25519)."
}

variable "bucket_name" {
  type        = string
  description = "Nome do bucket de mídias (único global na MGC). Ex.: site-media-<seu-nome>."
}

variable "object_storage_access_key" {
  type        = string
  sensitive   = true
  description = "Access Key do Object Storage (S3-compatible)."
}

variable "object_storage_secret_key" {
  type        = string
  sensitive   = true
  description = "Secret Key do Object Storage (S3-compatible)."
}

variable "object_storage_endpoint" {
  type        = string
  default     = "https://br-se1.magaluobjects.com"
  description = "Endpoint S3 do Object Storage da MGC."
}
