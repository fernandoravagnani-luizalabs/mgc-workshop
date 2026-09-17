# Workshop Magalu Cloud na Prática

Workshop hands-on de **1h30** onde cada participante sobe um ambiente simples na
Magalu Cloud (MGC) — simulando o caso de um cliente que roda um website da sua
empresa na nuvem — e depois desmonta tudo para não gerar custo.

Ao final do passo a passo, cada pessoa terá:

- **1 Máquina Virtual (VM)** rodando **WordPress + MySQL** em containers Docker
- **1 Bucket no Object Storage** (S3-compatible) com os **assets/media** do site
  (imagens, vídeos, documentos e arquivos de `wp-content/uploads`)
- **1 IP público** para acessar o site no navegador

> O site é um **WordPress** — o CMS mais usado no mundo — rodando via **Docker**
> na VM (container `wordpress` oficial + container `mysql:8.0` como banco). As
> mídias enviadas pela biblioteca do WordPress são copiadas para o **Object
> Storage** com o plugin **Media Cloud Sync**, e servidas direto do bucket.

```
Browser do participante
        │  http://<IP público>
        ▼
   ┌───────────────────────────────┐   media/assets     ┌────────────────────┐
   │  VM — Docker                  │ ─────────────────▶ │  Object Storage    │
   │  ┌──────────────┐  ┌────────┐ │                    │  (bucket público)  │
   │  │ wordpress    │  │ mysql  │ │                    └────────────────────┘
   │  │ (Apache+PHP) │  │ :8.0   │ │
   │  └──────────────┘  └────────┘ │
   └───────────────────────────────┘
   WordPress = código + tema + plugins (na VM)
   Banco de dados MySQL (na VM)
   Media/imagens (no Object Storage)
```

---

## Estrutura do repositório

O material do workshop está organizado por tipo de arquivo:

```
mgc-workshop/
├── README.md                 # Este guia passo a passo
├── roteiro-workshop.md       # Roteiro/falas do facilitador
├── scripts/                  # Scripts auxiliares (mgc CLI, pré-requisitos)
├── terraform/                # IaC: cria a infra e chama o Ansible (deploy)
│   ├── main.tf               # VM, Security Group, bucket, provisioner Ansible
│   ├── variables.tf
│   ├── outputs.tf
│   ├── templates/            # Policy do bucket (S3)
│   └── terraform.tfvars.example
├── ansible/                  # Provisionamento/configuração/deploy do WordPress
│   ├── playbook.yml
│   ├── ansible.cfg
│   ├── inventory/            # hosts.ini (IP gerado pelo Terraform)
│   └── roles/wordpress/      # instala Docker + sobe WordPress/MySQL
└── docker/                   # (reservado) docker-compose.yml de referência
```

> 💡 **Duas formas de criar o ambiente:** o caminho **manual** (console/CLI,
> seções 3 e 4) e o caminho **IaC** (Terraform + Ansible, seção 3.3). Ambos
> produzem a mesma entrega — a diferença é que o IaC automatiza o deploy.

---

## Índice

- [1. Pré-requisitos](#1-pré-requisitos)
- [2. Acesso à conta](#2-acesso-à-conta)
- [3. Provisionar a infraestrutura](#3-provisionar-a-infraestrutura)
  - [3.1 Pelo console](#31-pelo-console)
  - [3.2 Pela CLI](#32-pela-cli)
  - [3.3 Pelo IaC (Terraform + Ansible)](#33-pelo-iac-terraform--ansible)
- [4. Deploy do site](#4-deploy-do-site)
- [5. Verificação](#5-verificação)
- [6. Desmontagem do ambiente](#6-desmontagem-do-ambiente)
- [Referências](#referências)

---

## 1. Pré-requisitos

Antes do workshop, cada participante precisa de:

- Um navegador (Chrome/Firefox/Edge).
- Acesso ao console da Magalu Cloud (conta própria no ID Magalu **ou**
  conta de demonstração do workshop — ver [seção 2](#2-acesso-à-conta)).
- **Apenas para o caminho via CLI:** terminal com `mgc` CLI e `git` instalados.
- **Apenas para o caminho via IaC (Terraform + Ansible):** terminal com
  `terraform`, `ansible` instalados. O script
  `scripts/install-prereqs.sh`  (ou versão `.ps1` no Windows) 
  instalam essas ferramentas.

---

## 2. Acesso à conta

Existem dois caminhos. O **recomendado** é usar a própria conta;
ou pode ser usada a conta de demonstração.

### Caminho A — Criar a própria conta no ID Magalu (recomendado)

1. Acesse **https://magalu.cloud** e clique em **Criar conta**.
2. Preencha nome, e-mail e senha; confirme o e-mail pelo link enviado.
3. Faça login no console: **https://console.magalu.cloud**.
4. Aceite os termos e confirme que o **tenant** (organização) foi criado.

### Caminho B — Conta de demonstração

1. Acesse o **canal do WhatsApp do workshop**.
2. Envie o **e-mail do seu ID Magalu** no canal.
3. Aguarde o aviso de que o acesso na conta de demonstração foi liberado.
4. Acesse o console: **https://console.magalu.cloud** e faça login.

> O facilitador libera os acessos na conta de demonstração conforme os e-mails
> chegam. Só siga para a próxima seção depois do aviso de liberação.



---

## 3. Provisionar a infraestrutura

Vamos criar os dois recursos: a **VM** e o **bucket**. Você pode fazer tudo pelo
**console** (mais visual), pela **CLI** (mais rápido e reproduzível) ou pelo
**IaC** com Terraform + Ansible (tudo automatizado, seção 3.3).

> **Parâmetros usados neste guia** (ajuste se quiser):
> - Região: `br-se1`
> - VM: nome `site-web-01`, flavor `BV1-1-10` (1 vCPU / 1 GB RAM / 10GB Disk), 
>       imagem `cloud-ubuntu-24.04 LTS`
> - Bucket: nome `site-media-<seu-nome>` (o nome de bucket é **único global**)
> - Security Group: `site-sg`, liberando HTTP (80) e HTTPS (443) para todos e
>   SSH (22) para o seu IP

### 3.1 Pelo console

#### 3.1.1 Criar a Máquina Virtual

1. No console, acesse o menu **Máquinas Virtuais** → **Criar máquina**.
2. Preencha:
   - **Nome:** `site-web-01`
   - **Imagem/SO:** `cloud-ubuntu-24.04 LTS`
   - **Flavor/Configuração:** `BV1-1-10` (a menor disponível já basta)
   - **VPC:** a default - padrão da conta (não criar rede própria)
   - **IP público:** ativado (é o que permite acessar o site depois)
   - **Chave SSH:** escolha a chave do workshop (ou crie uma)
3. Clique em **Criar** e aguarde a máquina ficar **Ativa**.
4. **Anote o IP público** exibido — será usado no deploy.

#### 3.1.2 Criar o bucket (Object Storage)

1. No console, acesse **Object Storage** → **Criar bucket**.
2. Preencha:
   - **Nome:** `site-media-<seu-nome>`
   - **Região:** `br-se1` (mesma da VM)
   - **Visibilidade:** **público para leitura** (vai servir as mídias do site)
3. Clique em **Criar bucket**.
4. **Anote o nome do bucket** — vamos usá-lo na configuração do WordPress (o
   plugin grava as mídias lá).

### 3.2 Pela CLI

> Pré-requisito: `mgc` CLI autenticado. Substitua
> `<SEU_NOME>` por um identificador único (ex.: seu nome de usuário).

#### 3.2.1 Login e autenticação

```bash
# autenticar o CLI
mgc auth login          # abre o navegador para autenticar via ID Magalu
mgc auth tenant current # confirma o tenant logado

# configurar as chaves do object storage no CLI
https://docs.magalu.cloud/docs/storage/object-storage/compatible-tools/mgc-cli-compatibility#como-configurar-a-mgc-cli-com-api-keys
mgc object-storage api-key create --name="api-key-name" # criar uma api-key para possibilitar o acesso ao object storage
mgc object-storage api-key get UUID                     # verifica a api-key criada
mgc object-storage api-key set UUID                     # configura o CLI para utilizar a api-key no acesso ao object storage
mgc object-storage api-key current                      # verifica a api-key configurada no CLI
```

> Se você usa a **conta de demonstração**, verifique se a sua API key foi
> liberada antes de autenticar.

#### 3.2.2 Criar a VM

```bash
# registra a chave SSH (se ainda não tiver)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "workshop-mgc"
mgc profile ssh-keys create --name site-key \
  --key "$(cat ~/.ssh/id_ed25519.pub)" --output json --raw
```

```bash
# cria a VM com IP público
mgc virtual-machine instances create \
  --name site-web-01 \
  --machine-type.name BV1-1-10 \
  --image.name="cloud-ubuntu-24.04 LTS" \
  --ssh-key-name site-key \
  --network.associate-public-ip true \
  --region br-se1 \
  --output json --raw
```

```bash
# verifique a máquina criada
mgc virtual-machine instances get <ID>
```
> Anote o IP público retornado no campo `associated_public_ipv4`.

#### 3.2.3 Criar o bucket

```bash
# cria o bucket (S3-compatible) na região
mgc object-storage buckets create site-media-<seu-nome> \
  --public-read \
  --region br-se1 \
  --output json --raw

# torna a leitura pública (para servir as mídias do site)
mgc object-storage buckets policy set \
  --dst site-media-<seu-nome> \
  --policy '{
    "Version":"2012-10-17",
    "Statement":[{
      "Effect":"Allow",
      "Principal":"*",
      "Action":"s3:GetObject",
      "Resource":"site-media-<seu-nome>/*"
    }]
  }'
```

> **Nota:** não é preciso fazer upload manual das mídias. Elas serão enviadas
> pelo **WordPress** (via plugin Media Cloud Sync) quando você adicionar
> imagens na biblioteca de mídia — a VM precisa apenas das credenciais do
> bucket (ver [seção 4](#4-deploy-do-site)).

### 3.3 Pelo IaC (Terraform + Ansible)

Esta é a forma **automatizada**: o **Terraform** (provider oficial
`MagaluCloud/mgc`) cria toda a infraestrutura (chave SSH, security group, VM com
IP público e bucket) e, logo em seguida, o **provisioner local chama o Ansible**,
que instala o Docker e faz o deploy do WordPress + MySQL na VM.

```
Terraform ──cria a infra──▶ MGC (VM, SG, bucket)
    │
    └── provisioner local-exec ──▶ Ansible ──▶ deploy WordPress (Docker) na VM
```

**Passo a passo:**

```bash
# 1. Entre na pasta do Terraform
cd terraform

# 2. Preencha as variáveis
cp terraform.tfvars.example terraform.tfvars
# edite o terraform.tfvars: API Key, chaves SSH, nome do bucket e credenciais
# do Object Storage (access/secret key)

# 3. Inicialize e planeje
terraform init
terraform plan

# 4. Aplique (cria a infra + roda o Ansible automaticamente)
terraform apply
```

Ao final, o `terraform apply` já terá:
- criado a **VM** com IP público e o **bucket** de mídias (público para leitura);
- gerado o inventário do Ansible (`ansible/inventory/hosts.ini`) com o IP da VM;
- rodado o **Ansible**, que instala o Docker e sobe o **WordPress + MySQL** via
  `docker compose`.

Veja os **outputs** do Terraform (IP público e URL do site). Depois, siga a
seção [4](#4-deploy-do-site) apenas para **finalizar o WordPress no navegador**
e conectar o plugin Media Cloud Sync (o restante já foi feito pelo Ansible).

Para **desmontar** tudo:

```bash
terraform destroy
```

> Toda a lógica do deploy está em `ansible/roles/wordpress/` — veja os detalhes
> na [README do Terraform](terraform/README.md).

---

## 4. Deploy do WordPress (Docker)

Com a VM no ar e o bucket criado, vamos subir o **WordPress + MySQL em Docker**
e conectar as mídias ao Object Storage.

### 4.1 Conectar na VM

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@<IP_PUBLICO>
```

> Não tem SSH? O próprio console da Magalu Cloud oferece a **conexão web**
> direto na máquina — não depende da sua máquina local.

### 4.2 Instalar o Docker

```bash
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

Confirme a instalação:

```bash
sudo docker --version
sudo docker compose version
```

### 4.3 Subir WordPress + MySQL com Docker Compose

Crie o arquivo `docker-compose.yml` (baseado na **imagem oficial do WordPress**):

```bash
mkdir -p ~/wordpress && cd ~/wordpress
```

```yaml
# ~/wordpress/docker-compose.yml
services:

  wordpress:
    image: wordpress:latest
    restart: always
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wordpress:/var/www/html

  db:
    image: mysql:8.0
    restart: always
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress
      MYSQL_RANDOM_ROOT_PASSWORD: '1'
    volumes:
      - db:/var/lib/mysql

volumes:
  wordpress:
  db:
```

Suba os containers:

```bash
sudo docker compose up -d
sudo docker compose ps
```

> O primeiro `up -d` baixa as imagens e pode levar alguns minutos. Acompanhe o
> log com `sudo docker compose logs -f` até o WordPress responder.

> ⚠️ **Uso pedagógico:** aqui as senhas do banco são simples e fixas para o
> workshop. Em produção, use senhas fortes/aleatórias (a imagem oficial suporta
> `_FILE` para ler de Docker secrets) e dados persistentes.

### 4.4 Configurar as mídias no Object Storage

As mídias enviadas pelo WordPress (imagens, vídeos, documentos) vão para o
bucket via plugin. O plugin oficial usado é o
[**Media Cloud Sync**](https://wordpress.org/plugins/media-cloud-sync/)
(compatível com S3 — e o Object Storage da MGC fala S3).

**No navegador, finalize a instalação do WordPress** (em `http://<IP_PUBLICO>`):
1. Escolha o idioma e preencha os dados do site (título, usuário admin, senha e
   e-mail).
2. Faça login no painel (`/wp-admin`).

**Instale e configure o plugin:**

1. No painel, vá em **Plugins → Adicionar novo**.
2. Busque por **"Media Cloud Sync"** e **Instalar agora → Ativar**.
3. No menu **Settings → Configure**, configure o **Configure Cloud Service**
   com o **S3 Compatible** (o Object Storage da MGC é S3-compatible) e preencha:
   - **Provider label** — `Magalu Cloud`
   - **Storage Endpoint** — `https://br-se1.magaluobjects.com/`
   - **Access Key / Secret Key** — credenciais do Object Storage
     (obtidas no console do ID Magalu).
   - **Region** — `br-se1`.
   - **Bucket** — `site-media-<seu-nome>`.
   - **Save**

   - **Choose your Media Delivery Provider** - `Other`
   - **Provider Name** - `Magalu Cloud`
   - **Save**

4. Salve. O plugin testa a conexão com o bucket.

**Teste:** envie uma imagem pela biblioteca de mídia (**Mídia → Adicionar
nova**). Ela é copiada para o bucket e servida de lá — confira a URL da imagem
no site e no bucket no console do Object Storage.

> A essência da arquitetura: o **código, tema e plugins do WordPress ficam na
> VM**; o **banco fica no MySQL da VM**; mas as **mídias moram no Object
> Storage**. Assim a máquina não precisa crescer com o armazenamento e você
> pode escalar/cachear mídias com CDN no futuro.

---

## 5. Verificação

Abra no navegador:

```
http://<IP_PUBLICO>
```

Você deve ver o **WordPress instalado e no ar**, e, após o login no `/wp-admin`,
conseguir adicionar mídias que aparecem no site.

**Checklist:**
- [ ] Página inicial do WordPress responde (`http://<IP_PUBLICO>`)
- [ ] Login em `http://<IP_PUBLICO>/wp-admin` funciona
- [ ] Uma imagem enviada pela biblioteca de mídia aparece no site
- [ ] A imagem enviada também aparece no bucket `site-media-<seu-nome>` no
      console do Object Storage

> **Teste extra (opcional):** exclua a imagem local na máquina (o plugin tem a
> opção "Remove files from server") e verifique que a mídia continua acessível
> **direto do Object Storage** — a VM não precisa guardar as imagens.

---

## 6. Desmontagem do ambiente

Importante para **não gerar custo** depois do workshop (pay-as-you-go).

### Pelo console

1. **Apagar a VM:** menu **Máquinas Virtuais** → selecionar `site-web-01` →
   **Apagar/Excluir** → confirmar. (Isso também remove os containers e o volume
   do banco — os dados do workshop se perdem, como esperado.)
2. **Apagar o bucket:** menu **Object Storage** → selecionar o bucket →
   **esvaziar** (excluir os objetos de mídia) → **Apagar/Excluir** → confirmar.

> O **IP público** é apagado junto com a VM — não é preciso apagar à parte.

### Pela CLI

```bash
# apaga a VM (e o IP público junto) — remove containers, WordPress e o banco
mgc virtual-machine instances delete --id <VM_ID> --delete-public-ip=true --output json --raw

# apaga o bucket e esvazia os objetos de mídia
mgc object-storage buckets delete \
  --bucket site-media-<seu-nome> \
  --recursive
```

Confira no console que os dois recursos sumiram. Ambiente desmontado, sem custo
remanescente.

---

## Referências

- [Documentação da Magalu Cloud](https://docs.magalu.cloud/)
- [Console da Magalu Cloud](https://console.magalu.cloud)
- [Imagem oficial do WordPress no Docker Hub](https://hub.docker.com/_/wordpress)
- [Plugin Media Cloud Sync](https://wordpress.org/plugins/media-cloud-sync/)
- [Terraform Provider MagaluCloud/mgc](https://registry.terraform.io/providers/MagaluCloud/mgc/latest/docs)
- [Documentação do Ansible](https://docs.ansible.com/)
- [Roteiro do workshop (falas do facilitador)](roteiro-workshop.md)

---

*Workshop Magalu Cloud na Prática — rode, verifique e desmonte. Sem custo, sem
surpresa.*
