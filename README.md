# Workshop Magalu Cloud na Prática

Workshop hands-on de **1h30** onde cada participante cria sua própria conta no ID Magalu, sobe uma infraestrutura completa na **Magalu Cloud (MGC)** — simulando o caso de um cliente que hospeda um website corporativo na nuvem — e depois desmonta todos os recursos para não gerar custos remanescentes.

---

## 🎯 Arquitetura da Solução

Ao final do workshop, cada participante terá construído o seguinte ambiente:

- **1 Máquina Virtual (VM):** rodando **WordPress + MySQL** em containers Docker.
- **1 Bucket no Object Storage (S3-compatible):** armazenando e servindo as **mídias** do site (imagens, vídeos e uploads) com acesso público de leitura.
- **1 IP Público:** para acesso direto ao site via navegador.

```
Navegador do Participante / Visitantes
        │  http://<IP_PUBLICO>
        ▼
   ┌────────────────────────────────┐   mídias/uploads   ┌──────────────────────┐
   │  VM (Ubuntu 24.04) — Docker    │ ─────────────────▶ │  Object Storage      │
   │  ┌──────────────┐  ┌─────────┐ │                    │  (bucket público)    │
   │  │ WordPress    │  │ MySQL   │ │                    └──────────────────────┘
   │  │ (Apache+PHP) │  │ 8.0     │ │
   │  └──────────────┘  └─────────┘ │
   └────────────────────────────────┘
   WordPress = código + tema + plugins (na VM)
   Banco de dados MySQL = persistido na VM
   Mídias da biblioteca = servidas direto do Object Storage (S3)
```

---

## 📁 Estrutura do Repositório

```
mgc-workshop/
├── README.md                    # Este guia completo passo a passo
├── workshop-magalu-mloud.pptx   # Roteiro didático do facilitador com falas e tempos
├── scripts/                     # Scripts utilitários de instalação de pré-requisitos
│   ├── install-prereqs.sh       # Instalação automatizada no Linux/macOS
│   └── install-prereqs.ps1      # Instalação automatizada no Windows (PowerShell)
├── terraform/                   # Infraestrutura como Código (IaC) via Terraform
│   ├── main.tf                  # Definição de VM, Chave SSH, Bucket, ACL e Ansible
│   ├── variables.tf             # Definição das variáveis
│   ├── outputs.tf               # IPs e URLs de saída
│   └── terraform.tfvars.example # Template do arquivo de variáveis do Terraform
├── ansible/                     # Automação de deploy e configuração da VM
│   ├── playbook.yml             # Playbook de instalação do Docker e WordPress
│   ├── ansible.cfg              # Configurações do Ansible
│   ├── inventory/hosts.ini      # Inventário gerado automaticamente
│   └── roles/wordpress/         # Role com tarefas e templates do Docker Compose
└── docker/                      # Compose de referência pedagógica
```

---

## 📑 Índice

1. [Criação e Acesso à Conta (ID Magalu)](#1-criação-e-acesso-à-conta-id-magalu)
2. [Pré-requisitos e Ferramental](#2-pré-requisitos-e-ferramental)
3. [Provisionamento da Infraestrutura](#3-provisionamento-da-infraestrutura)
   - [3.1 Procedimento 1: Via Console Web](#31-procedimento-1-via-console-web)
   - [3.2 Procedimento 2: Via MGC CLI](#32-procedimento-2-via-mgc-cli)
   - [3.3 Procedimento 3: Via Terraform + Ansible (Automatizado)](#33-procedimento-3-via-terraform--ansible-automatizado)
4. [Configuração do WordPress e Mídias no Object Storage](#4-configuração-do-wordpress-e-mídias-no-object-storage)
5. [Validação do Ambiente](#5-validação-do-ambiente)
6. [Desmontagem e Exclusão dos Recursos](#6-desmontagem-e-exclusão-dos-recursos)
7. [Documentação e Referências Oficiais](#7-documentação-e-referências-oficiais)

---

## 1. Criação e Acesso à Conta (ID Magalu)

> 📖 **Documentação de apoio:** [Como criar sua conta na Magalu Cloud](https://docs.magalu.cloud/docs/onboarding/create-account)

Todos os participantes devem utilizar sua própria conta no ID Magalu. O cadastro é gratuito e no modelo *pay-as-you-go* (paga apenas pelo que usar).

### Passo a passo para criar sua conta:

1. Acesse o portal da Magalu Cloud: [https://magalu.cloud](https://magalu.cloud) e clique em **Criar conta** (ou acesse diretamente [https://console.magalu.cloud](https://console.magalu.cloud)).
2. Preencha os dados solicitados: Nome completo, CPF/CNPJ, e-mail de acesso e crie uma senha segura.
3. Acesse sua caixa de entrada e confirme seu endereço de e-mail clicando no link de ativação enviado.
4. Faça login no **Console Web**: [https://console.magalu.cloud](https://console.magalu.cloud).
5. No primeiro acesso, aceite os Termos de Serviço da plataforma.
6. Confirme a criação do seu **Tenant** (organização/espaço de trabalho padrão).

---

## 2. Pré-requisitos e Ferramental

Dependendo do procedimento de provisionamento escolhido (Console, CLI ou Terraform), prepare seu ambiente local:

### 2.1 Gerar Par de Chaves SSH Local (Necessário para todos os métodos)
Para acessar a Máquina Virtual de forma segura via terminal, gere uma chave SSH local caso ainda não possua:

```bash
# Gera um par de chaves ED25519 (recomendado) ou RSA
ssh-keygen -t ed25519 -f ~/.ssh/sshkey-workshop-mgc -N "" -C "workshop-mgc"

# Garanta as permissões restritas corretas no arquivo privado
chmod 600 ~/.ssh/sshkey-workshop-mgc
```

### 2.2 Script Automático de Instalação de Ferramentas (CLI / Terraform)
O repositório inclui scripts que instalam automaticamente `mgc` CLI, `terraform`, `ansible` e `git`:

- **Linux / macOS:**
  ```bash
  chmod +x scripts/install-prereqs.sh
  ./scripts/install-prereqs.sh
  ```
- **Windows (PowerShell como Administrador):**
  ```powershell
  Set-ExecutionPolicy Bypass -Scope Process -Force
  .\scripts\install-prereqs.ps1
  ```

---

## 3. Provisionamento da Infraestrutura

Escolha **um dos 3 procedimentos abaixo** para criar sua infraestrutura:

---

### 3.1 Procedimento 1: Via Console Web

> 📖 **Documentações de apoio:**
> - [Gerenciamento de Chaves SSH](https://docs.magalu.cloud/docs/virtual-machine/quickstart)
> - [Criar Instância de Máquina Virtual](https://docs.magalu.cloud/docs/virtual-machine/quickstart)
> - [Criar e Gerenciar Buckets no Object Storage](https://docs.magalu.cloud/docs/storage/object-storage/quickstart)
> - [Gerenciar Chaves de Acesso e API Keys](https://docs.magalu.cloud/docs/storage/object-storage/compatible-tools/mgc-cli-compatibility)

#### Passo 1 — Cadastrar sua Chave Pública SSH no Console
1. No Console da Magalu Cloud, acesse o menu **Segurança** (ou **Configurações de Perfil**) → **Chaves SSH**.
2. Clique em **Adicionar chave SSH**.
3. Defina o nome como `site-key`.
4. Cole o conteúdo da sua chave pública (copie do seu terminal com `cat ~/.ssh/id_ed25519.pub`).
5. Clique em **Salvar**.

#### Passo 2 — Gerar Chaves de Acesso do Object Storage (S3 Key Pair)
1. No menu lateral, acesse **Object Storage** → **Chaves de Acesso** / **API Keys**.
2. Clique em **Criar chave de acesso** (selecione escopo de Leitura e Escrita).
3. **Guarde com segurança o `Access Key ID` e a `Secret Access Key`** gerados (a Secret só é exibida uma vez).

#### Passo 3 — Criar a Máquina Virtual (VM)
1. No menu lateral, acesse **Máquinas Virtuais** → **Criar máquina**.
2. Preencha os campos:
   - **Nome:** `site-web-01`
   - **Região:** `Sudeste (br-se1)`
   - **Zona de Disponibilidade:** `br-se1-a`
   - **Imagem/SO:** `Ubuntu 24.04 LTS` (ou `cloud-ubuntu-24.04 LTS`)
   - **Tipo de Máquina (Flavor):** `BV1-1-10` (1 vCPU / 1 GB RAM / 10 GB Disco) ou `BV2-2-8`
   - **VPC / Rede:** Selecione a VPC padrão (`default`)
   - **IP Público:** Marque a opção para **Alocar IP Público IPv4**
   - **Chave SSH:** Selecione a chave cadastrada (`site-key`)
3. Clique em **Criar Máquina Virtual**.
4. Aguarde o status mudar para **Ativa/Executando** e **copie o IP Público** exibido.

#### Passo 4 — Criar o Bucket no Object Storage
1. No menu lateral, acesse **Object Storage** → **Buckets**.
2. Clique em **Criar bucket**.
3. Preencha:
   - **Nome:** `site-media-<seu-nome-exclusivo>` *(o nome deve ser único globalmente)*
   - **Região:** `br-se1` (mesma região da VM)
   - **Visibilidade:** Marque **Público para leitura** (ou adicione a política de leitura pública).
4. Clique em **Criar**.

#### Passo 5 — Deploy do WordPress via SSH na VM
Conecte-se na VM e suba os containers Docker:

```bash
# 1. Conecte via SSH
ssh -i ~/.ssh/id_ed25519 ubuntu@<IP_PUBLICO>

# 2. Instale o Docker e Docker Compose Plugin
sudo apt update && sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker

# 3. Crie a pasta da aplicação e o docker-compose.yml
mkdir -p ~/wordpress && cd ~/wordpress

cat > docker-compose.yml <<'EOF'
services:
  wordpress:
    image: wordpress:latest
    restart: always
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress_secret_pass
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wordpress_data:/var/www/html

  db:
    image: mysql:8.0
    restart: always
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress_secret_pass
      MYSQL_RANDOM_ROOT_PASSWORD: '1'
    volumes:
      - db_data:/var/lib/mysql

volumes:
  wordpress_data:
  db_data:
EOF

# 4. Inicie os containers
sudo docker compose up -d
sudo docker compose ps
```

---

### 3.2 Procedimento 2: Via MGC CLI

> 📖 **Documentações de apoio:**
> - [Instalação e Configuração da CLI](https://docs.magalu.cloud/docs/cli/installation-and-configuration/get-started)
> - [Autenticação e API Keys no CLI](https://docs.magalu.cloud/docs/cli/)
> - [Compatibilidade e Configuração de Object Storage no CLI](https://docs.magalu.cloud/docs/storage/object-storage/compatible-tools/mgc-cli-compatibility)
> - [Gerenciamento de Instâncias e Chaves SSH via CLI](https://docs.magalu.cloud/docs/cli/virtual-machine/instances)

#### Passo 1 — Login e Configuração de Credenciais na CLI
```bash
# 1. Autenticar no ID Magalu (abre o navegador)
mgc auth login

# 2. Confirmar o tenant ativo
mgc auth tenant current

# 3. Criar e ativar uma API Key com permissão para Object Storage
mgc object-storage api-key create workshop-key
# Copie o UUID retornado pelo comando acima e configure como ativo:
mgc object-storage api-key set <UUID_DA_API_KEY>
mgc object-storage api-key current
```

#### Passo 2 — Registrar a Chave SSH
```bash
# Registra a chave pública no perfil da MGC
mgc profile ssh-keys create \
  --name site-key \
  --key "$(cat ~/.ssh/id_ed25519.pub)" \
  --output json --raw
```

#### Passo 3 — Criar a Máquina Virtual (VM)
```bash
# Provisiona a VM com IP público na região br-se1
mgc virtual-machine instances create \
  --name site-web-01 \
  --machine-type.name BV1-1-10 \
  --image.name="cloud-ubuntu-24.04 LTS" \
  --ssh-key-name site-key \
  --network.associate-public-ip true \
  --region br-se1 \
  --output json --raw
```

Para consultar o IP público alocado:
```bash
mgc virtual-machine instances list
```
*(Anote o IP exibido na coluna `Public IP` / `associated_public_ipv4`).*

#### Passo 4 — Criar o Bucket no Object Storage com Leitura Pública
```bash
# Cria o bucket público na região br-se1
mgc object-storage buckets create site-media-<seu-nome> \
  --public-read \
  --region br-se1 \
  --output json --raw

# Aplica a política de leitura pública para o endpoint S3
mgc object-storage buckets policy set \
  --dst site-media-<seu-nome> \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "site-media-<seu-nome>/*"
    }]
  }'
```

#### Passo 5 — Deploy do WordPress na VM
Conecte-se na VM via SSH e realize a inicialização do Docker Compose (mesmo script de inicialização do Passo 5 da Seção 3.1):
```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@<IP_PUBLICO>
```

---

### 3.3 Procedimento 3: Via Terraform + Ansible (Automatizado)

> 📖 **Documentações de apoio:**
> - [Guia de Terraform na Magalu Cloud](https://docs.magalu.cloud/docs/infrastructure-as-code/terraform)
> - [Documentação do Provider Oficial MagaluCloud/mgc](https://registry.terraform.io/providers/MagaluCloud/mgc/latest/docs)
> - [Backend S3 e Integração Object Storage](https://docs.magalu.cloud/docs/storage/object-storage/quickstart)

Este método provisiona 100% da infraestrutura com **Terraform** e executa a configuração e deploy do WordPress automaticamente via **Ansible Playbook**.

#### Passo 1 — Configurar o arquivo de variáveis do Terraform
1. Entre no diretório do Terraform:
   ```bash
   cd terraform
   ```
2. Crie seu arquivo de variáveis a partir do exemplo:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
3. Edite o `terraform.tfvars` preenchendo com suas credenciais:
   ```hcl
   mgc_api_key            = "SUA_API_KEY_DA_MAGALU_CLOUD"
   region                 = "br-se1"
   availability_zone      = "br-se1-a"

   vm_name                = "site-web-01"
   machine_type           = "BV1-1-10"
   image                  = "cloud-ubuntu-24.04 LTS"

   ssh_key_name           = "site-key"
   ssh_public_key         = "ssh-ed25519 AAAAC3... (conteúdo de ~/.ssh/id_ed25519.pub)"
   ssh_private_key_path   = "~/.ssh/id_ed25519"

   bucket_name            = "site-media-<seu-nome-exclusivo>"

   object_storage_access_key  = "SEU_ACCESS_KEY_DO_OBJECT_STORAGE"
   object_storage_secret_key  = "SUA_SECRET_KEY_DO_OBJECT_STORAGE"
   object_storage_endpoint    = "https://br-se1.magaluobjects.com"
   ```

#### Passo 2 — Inicializar e Aplicar o Terraform
```bash
# Inicializa os providers (MGC, AWS S3 e Null)
terraform init

# Visualiza o plano de execução
terraform plan

# Aplica a infraestrutura e roda o deploy Ansible automaticamente
terraform apply
```

O Terraform realizará automaticamente:
1. Registro da chave SSH (`mgc_ssh_keys`).
2. Provisionamento da Máquina Virtual com IP público (`mgc_virtual_machine_instances`).
3. Criação do bucket de mídias (`mgc_object_storage_buckets`).
4. Configuração da ACL de leitura pública S3 (`aws_s3_bucket_acl`).
5. Execução do Ansible que aguarda a VM inicializar, instala o Docker e sobe o WordPress + MySQL via Docker Compose.

Ao final, o terminal exibirá os **Outputs**:
```text
Outputs:
bucket_name = "site-media-seu-nome"
public_ip   = "201.23.xx.xx"
ssh_command = "ssh -i ~/.ssh/id_ed25519 ubuntu@201.23.xx.xx"
wp_url      = "http://201.23.xx.xx"
```

---

## 4. Configuração do WordPress e Mídias no Object Storage

Após subir a infraestrutura por qualquer um dos 3 procedimentos:

### 4.1 Instalação do WordPress
1. Abra no seu navegador: `http://<IP_PUBLICO>`.
2. Selecione o idioma (Português do Brasil).
3. Preencha os dados do site (Título, Usuário Administrador, Senha e E-mail).
4. Clique em **Instalar WordPress** e faça login no painel `/wp-admin`.

### 4.2 Instalar e Configurar o Plugin Media Cloud Sync
O plugin **Media Cloud Sync** conecta a biblioteca de mídia do WordPress diretamente ao Object Storage compatível com S3 da Magalu Cloud:

1. No painel do WordPress, vá em **Plugins** → **Adicionar Novo**.
2. Busque por **Media Cloud Sync** e clique em **Instalar Agora** → **Ativar**.
3. Acesse o menu lateral **Media Cloud** (ou **Settings** → **Cloud Storage**).
4. Em **Storage Provider**, selecione **S3 Compatible**.
5. Preencha as credenciais:
   - **Provider Name / Label:** `Magalu Cloud`
   - **Storage Endpoint:** `https://br-se1.magaluobjects.com/`
   - **Access Key:** Sua Access Key do Object Storage
   - **Secret Key:** Sua Secret Key do Object Storage
   - **Region:** `br-se1`
   - **Bucket:** `site-media-<seu-nome>`
6. Em **Media Delivery Provider**, selecione **Other** / `Magalu Cloud`.
7. Clique em **Save Changes** e execute o teste de conexão.

---

## 5. Validação do Ambiente

Faça o teste de ponta a ponta da integração entre a VM e o Object Storage:

1. No painel do WordPress, vá em **Mídia** → **Adicionar Nova**.
2. Faça upload de uma imagem qualquer (ex: `.png` ou `.jpg`).
3. Clique sobre a imagem carregada e copie o link do arquivo (**URL do arquivo**).
4. **Verifique a URL:** A imagem estará apontando diretamente para `https://br-se1.magaluobjects.com/site-media-<seu-nome>/wp-content/uploads/...`.
5. Abra uma aba anônima no navegador e cole a URL da imagem: ela será carregada publicamente direto do Object Storage da Magalu Cloud sem onerar o disco da VM.

---

## 6. Desmontagem e Exclusão dos Recursos

> ⚠️ **Importante:** Para garantir que não haja cobranças residuais após o término do workshop, execute a exclusão completa dos recursos criados.

### 6.1 Desmontagem Via Console Web
1. **Excluir a VM:** Acesse **Máquinas Virtuais** → Selecione `site-web-01` → Clique em **Excluir** (o IP público associado será liberado).
2. **Esvaziar e Excluir o Bucket:** Acesse **Object Storage** → Selecione seu bucket → Clique em **Esvaziar objetos** → Depois clique em **Excluir bucket**.
3. **Remover Chave SSH:** Acesse **Segurança / Chaves SSH** → Exclua a chave `site-key`.

### 6.2 Desmontagem Via MGC CLI
```bash
# 1. Obter o ID da VM
VM_ID=$(mgc virtual-machine instances list --output json | grep -o '"id": "[^"]*' | head -1 | cut -d'"' -f4)

# 2. Excluir a VM e liberar o IP público
mgc virtual-machine instances delete --id $VM_ID --delete-public-ip=true

# 3. Excluir o bucket e todos os arquivos armazenados
mgc object-storage buckets delete --dst site-media-<seu-nome> --recursive

# 4. Remover a chave SSH do perfil
mgc profile ssh-keys delete --name site-key
```

### 6.3 Desmontagem Via Terraform
Se você utilizou o Terraform:
```bash
cd terraform
terraform destroy
```
*(Digite `yes` para confirmar. O Terraform removerá a VM, a chave SSH, a ACL e o bucket automaticamente).*

---

## 7. Documentação e Referências Oficiais

- 🌐 [Portal Oficial da Magalu Cloud](https://magalu.cloud/)
- 📖 [Documentação Central da Magalu Cloud](https://docs.magalu.cloud/)
- 🚀 [Guia de Criação de Conta e Onboarding](https://docs.magalu.cloud/docs/onboarding/create-account)
- 💻 [Guia de Instalação e Comandos da MGC CLI](https://docs.magalu.cloud/docs/cli/installation-and-configuration/get-started)
- 🖥️ [Documentação de Máquinas Virtuais (Compute)](https://docs.magalu.cloud/docs/virtual-machine/quickstart)
- 🪣 [Documentação de Object Storage (S3-Compatible)](https://docs.magalu.cloud/docs/storage/object-storage/quickstart)
- 🏗️ [Terraform Provider MagaluCloud/mgc](https://registry.terraform.io/providers/MagaluCloud/mgc/latest/docs)
- 🐳 [Imagem Oficial do WordPress (Docker Hub)](https://hub.docker.com/_/wordpress)
- 🔌 [Plugin WordPress Media Cloud Sync](https://wordpress.org/plugins/media-cloud-sync/)
- 📜 [Roteiro Pedagógico do Facilitador](roteiro-workshop.md)

---

*Workshop Magalu Cloud na Prática — Desenvolva, valide e automatize sua infraestrutura com autonomia.*
