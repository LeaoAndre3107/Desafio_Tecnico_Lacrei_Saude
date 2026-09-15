<div align="center">

# 🚀 Desafio Técnico DevOps — Lacrei Saúde

**Pipeline de CI/CD Seguro, Infraestrutura em Nuvem Escalável e Observabilidade na AWS**

[![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)](https://github.com/features/actions)
[![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)](https://nodejs.org/)

</div>

---

## 📌 Visão Geral

Este repositório contém a solução completa para o **Desafio Técnico de DevOps da Lacrei Saúde**. O projeto entrega uma aplicação **Node.js/Express** containerizada executada sobre **Amazon ECS com Fargate**, protegida por um **Application Load Balancer (ALB)** e pela CDN **Amazon CloudFront**.

### 🌟 Destaques da Solução
- **Zero Credentials Vazadas:** Autenticação AWS realizada 100% via **OIDC** (OpenID Connect) com credenciais temporárias, eliminando o uso de `AWS_ACCESS_KEY_ID` estáticas.
- **Imutabilidade de Artefatos:** Imagens Docker marcadas exclusivamente com o SHA do commit. A **mesma imagem** aprovada e testada em *Staging* é promovida para *Produção*.
- **Governança e Pipeline Seguro:** Proteção de ambiente com **aprovação manual obrigatória** antes da promoção para produção.
- **Segurança em Camadas:** CloudFront valida origem com *Header Secreto*, e as tarefas ECS operam em subnets privadas sem IP público.

---

## ✅ Resultados Validados em Ambiente Real

Os ambientes de **Staging** e **Produção** foram provisionados, integrados ao pipeline e validados com resposta `HTTP 200 OK`:

| Ambiente | Status | Endpoint de Validação | Resultado |
| :--- | :---: | :--- | :---: |
| 🟡 **Staging** | ![Active](https://img.shields.io/badge/ONLINE-brightgreen?style=flat-square) | [`/devops/staging/status`](https://d1gjy0g4ibj9zk.cloudfront.net/devops/staging/status) | `HTTP 200` |
| 🟢 **Produção** | ![Active](https://img.shields.io/badge/ONLINE-brightgreen?style=flat-square) | [`/devops/production/status`](https://d1gjy0g4ibj9zk.cloudfront.net/devops/production/status) | `HTTP 200` |

> 🏷️ **Tag da Imagem Promovida:** `deddb239a66829abc8e75cd236671eddfec22e49` *(Commit SHA)*  
> 🔔 **Observabilidade:** Alarmes CloudWatch configurados (`OK`). Subscrição SNS confirmada via e-mail com recebimento de notificações de teste (`INSUFFICIENT_DATA -> OK`).

---

## 🏗️ Arquitetura do Sistema

```text
               ┌─────────────────────────────────────────────────────────┐
               │                     GITHUB ACTIONS                      │
               └────────────────────────────┬────────────────────────────┘
                                            │ Auth via OIDC (Sem Access Keys)
                                            ▼
                                   ┌─────────────────┐
                                   │   Amazon ECR    │
                                   │ (Tags por SHA)  │
                                   └────────┬────────┘
                                            │
                      ┌─────────────────────┴─────────────────────┐
                      │                                           │ (Aprovação Manual)
                      ▼                                           ▼
          ┌───────────────────────┐                   ┌───────────────────────┐
          │  ECS Fargate Staging  │                   │ ECS Fargate Production│
          └───────────┬───────────┘                   └───────────┬───────────┘
                      │                                           │
                      └─────────────────────┬─────────────────────┘
                                            ▼
                               ┌─────────────────────────┐
                               │ Application Load Balancer│ (ALB Target Groups)
                               └────────────▲────────────┘
                                            │
                                            │ (Header Secreto de Origem)
                               ┌────────────┴────────────┐
               🌐 Internet ──►│    Amazon CloudFront    │ (HTTPS / TLS)
                               └─────────────────────────┘
```

---

## 🧩 Componentes e Responsabilidades

| Componente | Tecnologia | Responsabilidade Principal |
| :--- | :--- | :--- |
| **Aplicação** | Node.js 20 / Express | API REST simples expondo rotas `/` e `/status` com health-check. |
| **Container** | Docker (Alpine) | Imagem minimalista e segura, executada com usuário **não-root**. |
| **Registry** | Amazon ECR | Repositório privado com bloqueio de imutabilidade de tags. |
| **Computação** | AWS ECS + Fargate | Execução serverless de containers sem gerenciamento de EC2. |
| **Roteamento** | Application Load Balancer | Distribuição de tráfego baseada em rotas de contexto (`/devops/*`). |
| **Edge & Security**| Amazon CloudFront | Terminação TLS/HTTPS, cache de borda e proteção do ALB. |
| **IaC** | Terraform | Provisionamento modularizado de 100% da infraestrutura em nuvem. |
| **CI/CD** | GitHub Actions | Pipeline automatizado de build, teste de container e deploy contínuo. |
| **Monitoramento** | CloudWatch + SNS | Alertas automáticos de indisponibilidade de réplicas via e-mail. |

---

## 📁 Estrutura do Repositório

```text
.
├── .github/
│   └── workflows/          # Workflows do GitHub Actions (CI/CD Pipeline)
├── app/                    # Código-fonte da aplicação Node.js & Dockerfile
│   ├── index.js
│   ├── package.json
│   └── Dockerfile
└── Terraform/              # Código da Infraestrutura (IaC)
    ├── main.tf             # Declaração dos módulos e provider
    ├── outputs.tf          # Saídas da infraestrutura (URLs, ARNs)
    ├── variables.tf        # Variáveis globais
    ├── iam/                # Políticas e roles de permissão
    └── modules/            # Módulos reutilizáveis
        ├── alerts/         # CloudWatch Alarms & Tópicos SNS
        ├── cloudfront/     # Distribuição CDN e headers de origem
        ├── ecs-cluster/    # Cluster ECS, ALB e ECR
        ├── ecs-service/    # Definição de Tasks Fargate e Target Groups
        ├── github-oidc/    # Integração OIDC com GitHub Actions
        └── network/        # VPC, Subnets Públicas/Privadas, NAT Gateways
```

---

## 💻 Desenvolvimento Local & Docker

### Rotas da Aplicação
* `GET /`: Retorna a identificação básica da API.
* `GET /status`: Retorna o status de integridade (`UP`), `uptime` do serviço e *timestamp* ISO.

### 1. Executando Nativamente

```bash
cd app
npm install
npm start
```
*Em outro terminal, valide o health-check:*
```bash
curl -i http://localhost:3000/status
```

### 2. Executando via Docker

```bash
cd app

# Build da imagem local
docker build -t lacrei-status-app .

# Execução do container isolado
docker run --rm -p 3000:3000 lacrei-status-app
```

---

## 🔄 Pipeline CI/CD (GitHub Actions)

O pipeline é disparado automaticamente a cada `push` na branch `main` que contenha alterações em `app/`, `Terraform/` ou nos próprios arquivos de pipeline.

```text
[Commit/Push] ➔ [OIDC Auth] ➔ [Build & Smoke Test] ➔ [ECR Check/Push] ➔ [Deploy Staging] ➔ [Aprovação Manual] ➔ [Deploy Production]
```

### Etapas Detalhadas:
1. **Autenticação OIDC:** Assume a IAM Role temporária na AWS sem uso de senhas ou chaves salvas.
2. **Build & Validation:** Constrói a imagem Docker e roda um *smoke test* funcional do container.
3. **Idempotência no ECR:** Verifica se a tag (SHA) já existe no ECR para evitar re-uploads desnecessários.
4. **Deploy Staging:** Executa o rollout da nova task no ambiente de Staging.
5. **Health Gate Staging:** Aguarda e valida se a rota `/status` respondeu com HTTP 200.
6. **Manual Approval:** Pausa o workflow exigindo a aprovação de um revisor no ambiente `production` do GitHub.
7. **Promotion to Production:** Promove **exatamente a mesma imagem** para Produção e valida a saúde do ambiente.

---

## 🔐 Configuração de Secrets no GitHub

Para replicar o pipeline, configure as seguintes variáveis em **Settings → Secrets and variables → Actions**:

| Secret | Descrição | Exemplo / Formato |
| :--- | :--- | :--- |
| `AWS_ROLE_ARN` | ARN da Role do IAM criada para acesso OIDC pelo GitHub. | `arn:aws:iam::123456789012:role/GitHubActionsRole` |
| `ALERT_EMAIL` | E-mail para recebimento dos alertas de indisponibilidade do SNS. | `devops@empresa.com.br` |

> ⚠️ **Importante:** Após o provisionamento do SNS, acesse a caixa do e-mail cadastrado e **confirme a subscrição** clicando no link enviado pela AWS.

---

## 🛠️ Gerenciamento da Infraestrutura (Terraform)

O estado da infraestrutura é mantido remotamente no **Amazon S3** com locking via DynamoDB/S3 Native:

* **Bucket S3:** `lacrei-desafio-terraform-state`
* **Key:** `lacrei-desafio/terraform.tfstate`
* **Região:** `us-east-1`

### Comandos para Execução

```bash
cd Terraform

# Inicializa o backend remoto e baixa os provedores
AWS_PROFILE=lacrei-desafio terraform init

# Planeja e visualiza as alterações no ambiente
AWS_PROFILE=lacrei-desafio terraform plan

# Aplica as alterações planejadas
AWS_PROFILE=lacrei-desafio terraform apply
```

> 🛑 **Aviso de Boa Prática:** Nunca utilize `-lock=false` para burlar travamentos de *state*. Verifique se não há pipelines em execução antes de gerenciar o *lock*.

---

## 📊 Observabilidade e Alertas

A infraestrutura conta com alarmes dedicados por ambiente vinculados à métrica `AWS/ApplicationELB/UnHealthyHostCount`.

* **Regra do Alarme:** Disparado (`ALARM`) quando ao menos 1 container falhar nos health-checks durante **2 períodos consecutivos de 60 segundos**.
* **Notificação:** Mensagem instantânea enviada via **Amazon SNS** para o e-mail cadastrado.

### Comandos de Diagnóstico AWS CLI

**Verificar status dos Alarmes:**
```bash
AWS_PROFILE=lacrei-desafio aws cloudwatch describe-alarms \
  --alarm-name-prefix lacrei-desafio \
  --region us-east-1 \
  --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' \
  --output table
```

**Verificar subscrições do Tópico SNS:**
```bash
AWS_PROFILE=lacrei-desafio aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:905542450009:lacrei-desafio-alerts \
  --region us-east-1 \
  --query 'Subscriptions[*].[Protocol,Endpoint,SubscriptionArn]' \
  --output table
```

---

## 🧹 Limpeza de Recursos (Destruição)

Para evitar custos desnecessários em ambientes de teste/demonstração, destrua os recursos provisionados quando não estiverem em uso:

```bash
cd Terraform

# Planeja a destruição dos recursos
AWS_PROFILE=lacrei-desafio terraform plan -destroy

# Executa a remoção completa da infraestrutura
AWS_PROFILE=lacrei-desafio terraform destroy
```

---

## 🔮 Melhorias Futuras

- [ ] Implementação de testes unitários e de integração automatizados na API Node.js.
- [ ] Atualização das Actions do GitHub para sanar avisos de depreciação do runtime Node.js 20.
- [ ] Ajuste granular da política `treat_missing_data` nos alarmes CloudWatch.

---

## 📚 Referências Úteis

- [AWS Fargate Developer Guide](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Amazon CloudWatch Alarms & Email Notifications](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [Configuring OpenID Connect (OIDC) in AWS for GitHub Actions](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Terraform S3 Backend Documentation](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
