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

<p align="center">
  <img src="docs/architecture.png" alt="Diagrama vertical da arquitetura AWS do projeto Lacrei Saúde" width="100%" />
</p>

A fonte editável do diagrama está em [`docs/architecture.mmd`](docs/architecture.mmd).



O diagrama destaca três fluxos independentes: **entrega e promoção da imagem**, **entrada de tráfego pelo CloudFront até as tasks privadas** e **monitoramento com notificação SNS**.

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
│   ├── server.test.js
│   ├── package.json
│   ├── package-lock.json
│   ├── .eslintrc.json
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

### Lint e testes automatizados

Antes do build da imagem, o projeto executa uma validação estática com ESLint e testes automatizados com Jest e Supertest:

```bash
cd app
npm install
npm run lint
npm test
```

O lint verifica a sintaxe e regras básicas de qualidade do código. Os testes validam a rota `/status`, o código HTTP `200`, o campo `status`, o uptime, o timestamp e a rota raiz `/`.

O resultado esperado é semelhante a:

```text
ESLint sem erros
Test Suites: 1 passed, 1 total
Tests:       2 passed, 2 total
```

No GitHub Actions, os comandos `npm run lint` e `npm test` são executados depois do checkout e antes do `docker build`. Se qualquer um deles falhar, a imagem não é construída nem publicada no ECR.

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
- Serviços Fargate separados para staging e production, com uma task em staging e duas tasks em production.
- ALB com roteamento por path.
- ECR com `IMMUTABLE` tags.
- CloudFront com HTTPS obrigatório.
- CloudFront restrito aos métodos `GET` e `HEAD`, usados pela aplicação.
- Security groups em camadas.
- IAM Role para GitHub Actions via OIDC.
- CloudWatch Alarms e SNS.

As tasks Fargate executam em subnets privadas, sem IP público. O tráfego permitido para as tasks é originado somente pelo security group do ALB.

O tráfego público entre o usuário e o CloudFront utiliza HTTPS. O origin CloudFront → ALB utiliza HTTP porque o ALB desta entrega usa o domínio padrão `elb.amazonaws.com` e não possui um certificado ACM associado a um domínio controlado pelo projeto. O acesso direto ao ALB é reduzido pelo header secreto exigido nas regras do listener. Em um ambiente produtivo com domínio próprio, o próximo passo seria habilitar listener HTTPS no ALB e configurar `origin_protocol_policy = "https-only"`.

O projeto utiliza um NAT Gateway único como decisão consciente de custo para o ambiente de demonstração. Isso reduz o custo, mas não oferece alta disponibilidade completa para a saída das subnets privadas. Para produção, a alternativa seria um NAT Gateway por AZ ou VPC endpoints quando aplicável.

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

### Sequência de validação

O job de staging executa as etapas nesta ordem:

```text
Checkout
  ↓
Terraform fmt + validate + scan de configuração
  ↓
Autenticação AWS via OIDC
  ↓
npm ci + npm run lint + npm test
  ↓
Docker build
  ↓
Scan de vulnerabilidades da imagem
  ↓
Smoke test HTTP do container
  ↓
Verificação da tag no ECR e push condicional
  ↓
Terraform apply em staging
  ↓
Health-check de staging
```

Depois da aprovação manual do ambiente `production`, o segundo job aplica a mesma tag de imagem em produção e executa o health-check público.

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
| Dados ausentes | `breaching` |

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

## Erros encontrados e decisões técnicas

Durante a implementação, alguns problemas reais exigiram correções no código, no pipeline e na operação da infraestrutura.

| Problema | Causa | Decisão e solução |
|---|---|---|
| A reexecução do pipeline falhou no `docker push` | O ECR estava configurado com tags imutáveis e a imagem do mesmo SHA já havia sido publicada antes de uma falha posterior. | O workflow passou a consultar o ECR antes do push. Se a tag já existir, a imagem publicada é reutilizada. |
| O Terraform ficou aguardando `alert_email` | A variável não possuía valor padrão e não havia sido enviada em uma execução do CI. | O e-mail passou a ser fornecido por `TF_VAR_alert_email` a partir do secret `ALERT_EMAIL`, com validação prévia no workflow. |
| O state remoto ficou bloqueado | Uma execução de `plan` ou `apply` foi interrompida e o lock nativo do backend S3 permaneceu ativo. | Processos locais e workflows ativos passaram a ser verificados antes de usar `force-unlock`. O uso de `-lock=false` foi evitado. |
| O teste com zero tasks produziu `INSUFFICIENT_DATA` | A métrica `UnHealthyHostCount` ficou sem datapoints quando o target group não possuía tasks. | O alarme passou a tratar dados ausentes como `breaching`, reduzindo o risco de esconder uma indisponibilidade. |
| O pipeline poderia promover artefatos diferentes | Um novo build para produção poderia divergir do artefato testado em staging. | A mesma tag baseada no SHA do commit é promovida de staging para produção, sem rebuild. |
| O ALB poderia ser acessado diretamente | O ALB é público por ser o origin do CloudFront. | O listener exige um header secreto enviado pelo CloudFront, enquanto as tasks permanecem em subnets privadas. |

Essas decisões priorizam rastreabilidade, menor privilégio, reexecução segura e separação entre os ambientes. Com `TreatMissingData: breaching`, a ausência de métrica é tratada como uma condição de alerta, evitando que um target sem datapoints oculte uma possível indisponibilidade.

## Processo de rollback

O rollback é feito promovendo novamente uma imagem já publicada no ECR. Como as tags são imutáveis e cada tag representa um commit, não é necessário reconstruir a imagem anterior.

### Rollback por GitHub Actions

1. Identifique o SHA da última versão estável no histórico do Git ou no ECR.
2. Crie uma branch de rollback a partir desse commit.
3. Abra um pull request ou faça o push conforme o processo do repositório.
4. O workflow construirá ou reutilizará a tag correspondente ao SHA.
5. O staging será atualizado e validado pelo health-check.
6. Após a aprovação manual do ambiente `production`, a mesma tag será promovida para produção.

Exemplo para identificar imagens publicadas:

```bash
AWS_PROFILE=lacrei-desafio aws ecr describe-images \
  --repository-name devops-app \
  --region us-east-1 \
  --query 'sort_by(imageDetails,& imagePushedAt)[-10:].[imageTags[0],imagePushedAt,imageDigest]' \
  --output table
```

### Rollback operacional direto no ECS

Em uma indisponibilidade que exija ação imediata, é possível apontar temporariamente cada serviço para a revision anterior da task definition:

```bash
AWS_PROFILE=lacrei-desafio aws ecs list-task-definitions \
  --family-prefix lacrei-desafio-devops-app-staging \
  --status ACTIVE \
  --sort DESC \
  --region us-east-1

AWS_PROFILE=lacrei-desafio aws ecs update-service \
  --cluster lacrei-desafio-cluster \
  --service lacrei-desafio-devops-app-staging \
  --task-definition <REVISION_ESTAVEL> \
  --region us-east-1
```

Repita para production somente após validar a revision no staging:

```bash
AWS_PROFILE=lacrei-desafio aws ecs update-service \
  --cluster lacrei-desafio-cluster \
  --service lacrei-desafio-devops-app-production \
  --task-definition <REVISION_ESTAVEL> \
  --region us-east-1
```

Depois de qualquer rollback manual, valide os endpoints públicos:

```bash
curl -sS -o /dev/null -w "staging: HTTP %{http_code}\n" \
  "https://d1gjy0g4ibj9zk.cloudfront.net/devops/staging/status"

curl -sS -o /dev/null -w "production: HTTP %{http_code}\n" \
  "https://d1gjy0g4ibj9zk.cloudfront.net/devops/production/status"
```

O rollback manual deve ser seguido de uma correção no código ou no pipeline. Caso contrário, o próximo `terraform apply` ou deploy poderá reaplicar a versão defeituosa.

## Checklist de segurança aplicado

| Verificação | Status | Evidência no projeto |
|---|---:|---|
| Credenciais AWS permanentes fora do repositório | ✅ | GitHub Actions utiliza OIDC e IAM Role temporária. |
| Secrets armazenados fora do código | ✅ | `AWS_ROLE_ARN` e `ALERT_EMAIL` são consumidos como GitHub Secrets. |
| Princípio do menor privilégio | ✅ | IAM Role e políticas são limitadas aos recursos e ações do desafio. |
| Permissão mínima do workflow | ✅ | Workflow declara `id-token: write` e `contents: read`. |
| Tags de imagem imutáveis | ✅ | ECR utiliza `image_tag_mutability = "IMMUTABLE"`. |
| Tasks sem IP público | ✅ | Fargate executa em subnets privadas com `assign_public_ip = false`. |
| Tasks protegidas por Security Group | ✅ | A porta do container aceita tráfego somente do Security Group do ALB. |
| Entrada pública via HTTPS | ✅ | CloudFront é o endpoint público e redireciona para HTTPS. |
| Bypass direto do ALB reduzido | ✅ | Listener exige o header secreto de verificação de origem. |
| Confirmação do e-mail de alertas | ✅ | Subscription SNS foi confirmada e recebeu notificação. |
| Logs da aplicação acessíveis | ✅ | Task definition envia logs para CloudWatch Logs. |
| State Terraform remoto e criptografado | ✅ | Backend S3 usa `encrypt = true` e lock nativo. |
| Lock ignorado durante operações | ✅ | `-lock=false` não é usado no procedimento documentado. |
| CORS | N/A | A aplicação expõe apenas um health-check sem fluxo de navegador ou API cross-origin. |

O checklist foi aplicado à configuração entregue. A validação de segurança não substitui revisão periódica de permissões, rotação de secrets ou análise de custos.

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
