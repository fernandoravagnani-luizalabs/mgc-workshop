# Infraestrutura via Terraform (provider Magalu Cloud)

Este diretório contém o **Terraform** que provisiona a infraestrutura do
workshop na Magalu Cloud (VM usando o Security Group default + bucket) e, em
seguida, chama o **Ansible** para fazer o provisionamento/configuração/deploy do
WordPress via Docker Compose.

## Recursos criados

| Recurso | Tipo | Nome (padrão) |
|---|---|---|
| Chave SSH | `mgc_ssh_keys` | `site-key` |
| Máquina Virtual (SG default) | `mgc_virtual_machine_instances` | `site-web-01` |
| Bucket (mídias) | `mgc_object_storage_buckets` | `site-media-<nome>` |
| Deploy (Ansible) | `null_resource` | — |

> **Nota sobre Security Group:** a VM utiliza o Security Group `default` da VPC/região na Magalu Cloud. Certifique-se de que ele permite tráfego de entrada nas portas 22 (SSH) e 80 (HTTP).

## Como usar

1. **Preencha as variáveis:**

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # edite o terraform.tfvars com sua API Key, chaves e nome de bucket
   ```

2. **Instale o provider e planeje:**

   ```bash
   terraform init
   terraform plan
   ```

3. **Aplique** (cria a infra e roda o Ansible automaticamente):

   ```bash
   terraform apply
   ```

   Ao final, o Ansible já terá instalado o Docker, subido o WordPress + MySQL
   e deixado o bucket de mídias pronto. Veja os `outputs` (IP público, URL).

4. **Finalizar o WordPress no navegador** em `http://<IP>` (título, usuário,
   senha) e instalar/configurar o plugin **WP Offload Media** apontando para o
   bucket (as credenciais já foram injetadas no Ansible, mas a configuração do
   plugin é feita pelo participante no painel — igual ao README principal).

5. **Desmontar** (remove VM, bucket e tudo):

   ```bash
   terraform destroy
   ```

> O `terraform.tfvars` contém segredos (API Key, chaves). Não o versione —
> o `.tfvars.example` é o que deve ir para o repositório.
