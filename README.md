<div align="center">

# Desafio Técnico DevOps
## Lacrei Saúde

**Deploy seguro, infraestrutura reproduzível e observabilidade na AWS**

<br />

![AWS](https://img.shields.io/badge/AWS-Cloud-orange?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Container-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-20-339933?style=for-the-badge&logo=node.js&logoColor=white)

</div>

<br />

> Este projeto implementa uma aplicação Node.js/Express containerizada, executada em ECS Fargate, com deploy automatizado por GitHub Actions, autenticação OIDC, promoção controlada entre ambientes e monitoramento por CloudWatch e SNS.

## Visão geral

A solução foi construída com foco em quatro objetivos:

| Objetivo | Implementação |
|---|---|
| **Entrega segura** | GitHub Actions autenticado na AWS por OIDC, sem access keys permanentes. |
| **Rastreabilidade** | Imagens Docker identificadas pelo SHA completo do commit e armazenadas com tags imutáveis. |
| **Separação de ambientes** | Deploy em staging, validação automática e aprovação manual antes da produção. |
| **Observabilidade** | Alarmes CloudWatch baseados na saúde dos targets do ALB e notificações via SNS. |

## Resultado validado

Os dois ambientes estão publicados e respondendo corretamente pelo CloudFront:

| Ambiente | Endpoint | Status |
|---|---|---|
| **Staging** | [`/devops/staging/status`](https://d1gjy0g4ibj9zk.cloudfront.net/devops/staging/status) | `HTTP 200` |
| **Production** | [`/devops/production/status`](https://d1gjy0g4ibj9zk.cloudfront.net/devops/production/status) | `HTTP 200` |

A mesma imagem foi promovida de staging para produção:

```text
deddb239a66829abc8e75cd236671eddfec22e49
```

O monitoramento também foi validado:

- Alarmes de staging e production provisionados no CloudWatch.
- Targets saudáveis com `UnHealthyHostCount = 0`.
- Tópico SNS criado.
- Subscription de e-mail confirmada.
- Notificação de mudança de estado recebida por e-mail.

> O teste de notificação observado registrou a transição `INSUFFICIENT_DATA → OK`, confirmando a entrega do SNS ao e-mail configurado.

## Arquitetura

```text
┌─────────────────────┐
│   GitHub Actions    │
│  Build + Test + CI  │
└──────────┬──────────┘
           │ OIDC
           ▼
┌─────────────────────┐
│     AWS ECR         │
│  Tags por commit    │
│     Imutáveis       │
└──────────┬──────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌──────────┐  ┌──────────────┐
│ Staging  │  │ Production   │
│ ECS      │  │ ECS Fargate  │
│ Fargate  │  │              │
└────┬─────┘  └──────┬───────┘
     │               │
     └───────┬───────┘
             ▼
┌─────────────────────┐
│   Application LB     │
│  Path-based routing  │
└──────────┬──────────┘
           │ Header secreto
           ▼
┌─────────────────────┐
│   Amazon CloudFront  │
│      HTTPS/TLS       │
└──────────┬──────────┘
           │
           ▼
        Internet
```

### Fluxo de promoção

```text
Push na main
    ↓
Build da imagem Docker
    ↓
Smoke test HTTP
    ↓
Verificação da tag no ECR
    ↓
Push somente se a tag ainda não existir
    ↓
Deploy em staging
    ↓
Health-check de staging
    ↓
Aprovação manual no ambiente production
    ↓
Promoção da mesma imagem
    ↓
Deploy e health-check de production
```

## Componentes da solução

| Camada | Tecnologia | Responsabilidade |
|---|---|---|
| **Aplicação** | Node.js + Express | Expor as rotas da aplicação e o health-check. |
| **Container** | Docker | Empacotar a aplicação com imagem Alpine e usuário não-root. |
| **Registry** | Amazon ECR | Armazenar imagens com tags imutáveis por SHA. |
| **Computação** | ECS + Fargate | Executar os serviços sem gerenciamento de servidores. |
| **Rede** | VPC, subnets públicas e privadas | Isolar os componentes e controlar o tráfego. |
| **Entrada** | ALB + CloudFront | Roteamento por path e acesso HTTPS público. |
| **IaC** | Terraform | Provisionar e versionar a infraestrutura. |
| **CI/CD** | GitHub Actions | Automatizar build, validação e promoção. |
| **Observabilidade** | CloudWatch + SNS | Monitorar targets unhealthy e enviar alertas. |

## Aplicação

A aplicação está em `app/server.js` e possui duas rotas:

| Método | Rota | Comportamento |
|---|---|---|
| `GET` | `/` | Retorna uma identificação simples da aplicação. |
| `GET` | `/status` | Retorna status, uptime do processo e timestamp. |

Exemplo de resposta:

```json
{
  "status": "ok",
  "uptime_seconds": 315.607,
  "timestamp": "2026-09-15T02:46:44.878Z"
}
```

Nos ambientes AWS, o prefixo é configurado pela variável `APP_PREFIX`:

```text
/devops/staging/status
/devops/production/status
```

A porta da aplicação pode ser configurada pela variável `PORT`. O padrão é `3000`.

## Estrutura do repositório

```text
.
├── app/
│   ├── server.js
│   ├── package.json
│   ├── package-lock.json
│   ├── Dockerfile
│   └── .dockerignore
├── Terraform/
│   ├── backend.tf
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── iam/
│   └── modules/
│       ├── alerts/
│       ├── cloudfront/
│       ├── ecs-cluster/
│       ├── ecs-service/
│       ├── github-oidc/
│       └── network/
├── .github/
│   └── workflows/
│       └── deploy.yml
└── README.md
```

## Execução local

### Node.js

```bash
cd app
npm install
npm start
```

Em outro terminal:

```bash
curl -i http://localhost:3000/status
```

### Docker

```bash
cd app
docker build -t lacrei-status-app .
docker run --rm -p 3000:3000 lacrei-status-app
```

Validação:

```bash
curl -i http://localhost:3000/status
```

O Dockerfile utiliza `node:20-alpine`, instala as dependências com `npm ci --omit=dev`, executa o processo como usuário não-root e inclui um `HEALTHCHECK` baseado na rota `/status`.

## Infraestrutura AWS

A infraestrutura é modularizada em Terraform e utiliza:

- VPC dedicada com CIDR `10.20.0.0/16`.
- Duas subnets públicas e duas subnets privadas.
- NAT Gateway único para reduzir o custo do ambiente de portfólio.
- ECS Cluster com Container Insights habilitado.
- Serviços Fargate separados para staging e production.
- ALB com roteamento por path.
- ECR com `IMMUTABLE` tags.
- CloudFront com HTTPS obrigatório.
- Security groups em camadas.
- IAM Role para GitHub Actions via OIDC.
- CloudWatch Alarms e SNS.

As tasks Fargate executam em subnets privadas, sem IP público. O tráfego permitido para as tasks é originado somente pelo security group do ALB.

### Backend do Terraform

O state é armazenado remotamente no S3:

```text
Bucket: lacrei-desafio-terraform-state
Key:    lacrei-desafio/terraform.tfstate
Region: us-east-1
Lock:   arquivo de lock nativo do backend S3
```

## GitHub Actions

O workflow está em:

```text
.github/workflows/deploy.yml
```

Ele é acionado por push na branch `main` quando há alterações em:

```text
app/**
Terraform/**
.github/workflows/deploy.yml
```

### Segurança

O pipeline usa GitHub Actions OIDC para assumir uma IAM Role temporária na AWS. Não são utilizadas access keys permanentes armazenadas como secrets.

### Tags imutáveis

A imagem recebe uma tag baseada no SHA do commit:

```yaml
IMAGE_TAG: ${{ github.sha }}
```

Antes do push, o workflow verifica se a tag já existe no ECR. Isso permite reexecutar um pipeline sem tentar sobrescrever uma tag imutável que já foi publicada.

### Secrets necessários

Configure em **Settings → Secrets and variables → Actions**:

| Secret | Finalidade |
|---|---|
| `AWS_ROLE_ARN` | ARN da IAM Role assumida pelo GitHub Actions via OIDC. |
| `ALERT_EMAIL` | E-mail utilizado pela subscription do SNS. |

O ambiente `production` deve possuir aprovação manual configurada por meio de um required reviewer.

## Operação do Terraform

Execute os comandos dentro da pasta `Terraform`:

```bash
cd Terraform
AWS_PROFILE=lacrei-desafio terraform init
AWS_PROFILE=lacrei-desafio terraform plan
AWS_PROFILE=lacrei-desafio terraform apply
```

Consulte as URLs publicadas:

```bash
AWS_PROFILE=lacrei-desafio terraform output
```

Não utilize `-lock=false` para contornar um lock. Antes de usar `force-unlock`, confirme que não existe outro `terraform plan`, `terraform apply` ou workflow ativo usando o mesmo state remoto.

## Monitoramento e alertas

Existe um alarme por ambiente para a métrica:

```text
AWS/ApplicationELB/UnHealthyHostCount
```

Configuração principal:

| Parâmetro | Valor |
|---|---|
| Período | 60 segundos |
| Períodos de avaliação | 2 |
| Estatística | Maximum |
| Limite | `>= 1` target unhealthy |
| Ação | Publicação no SNS |
| Dados ausentes | `missing` |

Consultar os alarmes:

```bash
AWS_PROFILE=lacrei-desafio aws cloudwatch describe-alarms \
  --alarm-name-prefix lacrei-desafio \
  --region us-east-1 \
  --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' \
  --output table
```

Consultar a subscription do SNS:

```bash
AWS_PROFILE=lacrei-desafio aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:905542450009:lacrei-desafio-alerts \
  --region us-east-1 \
  --query 'Subscriptions[*].[Protocol,Endpoint,SubscriptionArn]' \
  --output table
```

A subscription de e-mail precisa ser confirmada pelo link enviado pela AWS. Enquanto não for confirmada, seu ARN aparece como `PendingConfirmation` e as notificações não são entregues.

## Limpeza da infraestrutura

Os recursos AWS geram custos enquanto permanecem ativos. Para remover a infraestrutura provisionada por este state:

```bash
cd Terraform
AWS_PROFILE=lacrei-desafio terraform plan -destroy
AWS_PROFILE=lacrei-desafio terraform destroy
```

Revise o plano antes de confirmar a destruição.

<div align="center">

**Desafio Técnico DevOps — Lacrei Saúde**

</div>
