# Desafio Técnico DevOps — Lacrei Saúde

Este projeto implementa uma aplicação Node.js/Express containerizada e executada em **Amazon ECS com Fargate**, atrás de um Application Load Balancer (ALB) e de uma distribuição CloudFront. A infraestrutura é provisionada com Terraform e o deploy é automatizado por GitHub Actions usando autenticação OIDC, sem access keys permanentes armazenadas no repositório.

A solução separa staging e produção, promove para produção a mesma imagem validada em staging e exige aprovação manual antes do deploy produtivo.

## Resultado validado

Os dois ambientes foram publicados e testados pelo endpoint de health-check:

| Ambiente | URL | Resultado validado |
|---|---|---|
| Staging | `https://d1gjy0g4ibj9zk.cloudfront.net/devops/staging/status` | HTTP 200 |
| Produção | `https://d1gjy0g4ibj9zk.cloudfront.net/devops/production/status` | HTTP 200 |

A imagem promovida para os dois ambientes utilizou a mesma tag baseada no commit:

```text
deddb239a66829abc8e75cd236671eddfec22e49
```

Os alarmes de staging e produção foram provisionados no CloudWatch e observados em estado `OK`. A subscription de e-mail do SNS foi confirmada, e uma notificação de recuperação do alarme foi recebida por e-mail. O teste realizado produziu a transição `INSUFFICIENT_DATA -> OK`; uma transição `OK -> ALARM` não deve ser afirmada sem evidência correspondente no histórico do CloudWatch.

## Arquitetura

```text
GitHub Actions
    │ OIDC
    ▼
AWS ECR (tags imutáveis por SHA)
    │
    ├── Deploy staging ──► ECS Fargate staging ──► ALB target group
    │                                      │
    └── Aprovação manual ──► ECS Fargate production ──► ALB target group
                                                       │
Internet ──► CloudFront (HTTPS) ──► ALB ──► tasks privadas
```

O CloudFront encaminha somente requisições legítimas para o ALB por meio de um header secreto de origem. As tasks do ECS executam em subnets privadas e aceitam tráfego somente do security group do ALB.

## Componentes

| Componente | Responsabilidade |
|---|---|
| Node.js/Express | Expõe a aplicação e o health-check `/status`. |
| Docker | Empacota a aplicação em uma imagem com execução como usuário não-root. |
| Amazon ECR | Armazena imagens com tags imutáveis baseadas no SHA do commit. |
| Amazon ECS/Fargate | Executa os serviços de staging e produção sem gerenciamento de servidores. |
| Application Load Balancer | Encaminha os paths de cada ambiente para o target group correspondente. |
| Amazon CloudFront | Fornece entrada HTTPS e impede o bypass direto do ALB. |
| Terraform | Provisiona a rede, segurança, ECS, ALB, ECR, CloudFront, IAM e alertas. |
| GitHub Actions | Constrói, testa, publica e promove a imagem entre os ambientes. |
| CloudWatch e SNS | Monitoram targets unhealthy e enviam notificações por e-mail. |

## Estrutura do repositório

```text
app/                         Aplicação Node.js/Express
Terraform/                   Infraestrutura como código
Terraform/modules/network/   VPC, subnets, NAT e rotas
Terraform/modules/ecs-cluster ECS cluster, ALB e ECR
Terraform/modules/ecs-service Serviços Fargate e target groups
Terraform/modules/cloudfront CloudFront e proteção da origem
Terraform/modules/github-oidc IAM para GitHub Actions via OIDC
Terraform/modules/alerts      CloudWatch alarms e SNS
Terraform/iam/               Exemplo de política IAM
.github/workflows/            Pipeline de deploy
```

## Aplicação local

A aplicação possui duas rotas:

| Rota | Função |
|---|---|
| `GET /` | Retorna uma identificação simples da aplicação. |
| `GET /status` | Retorna o estado, o uptime do processo e um timestamp em ISO 8601. |

Para executar localmente:

```bash
cd app
npm install
npm start
```

Em outro terminal:

```bash
curl -i http://localhost:3000/status
```

A porta pode ser alterada pela variável `PORT`. O prefixo usado nos ambientes AWS é configurado pela variável `APP_PREFIX`.

## Docker

O Dockerfile utiliza `node:20-alpine`, instala dependências com `npm ci --omit=dev`, executa a aplicação como usuário não-root e define um health-check baseado em `/status`.

Para validar localmente:

```bash
cd app
docker build -t lacrei-status-app .
docker run --rm -p 3000:3000 lacrei-status-app
curl -i http://localhost:3000/status
```

## Deploy

O workflow `.github/workflows/deploy.yml` é executado por push na branch `main` quando há mudanças em `app/`, `Terraform/` ou no próprio workflow.

O pipeline executa as etapas abaixo:

1. Obtém credenciais temporárias da AWS por GitHub Actions OIDC.
2. Constrói a imagem Docker.
3. Executa um smoke test no container.
4. Consulta o ECR antes do push para permitir reexecuções de uma tag imutável já publicada.
5. Publica a imagem no ECR quando a tag ainda não existe.
6. Faz deploy em staging com Terraform.
7. Valida o health-check de staging.
8. Aguarda a aprovação do ambiente protegido `production`.
9. Promove para produção a mesma tag validada em staging.
10. Valida o health-check de produção.

As tags das imagens usam o SHA completo do commit. Essa estratégia impede que uma tag existente aponte para uma imagem diferente.

## Secrets do GitHub

Configure os seguintes valores em **Settings → Secrets and variables → Actions**:

| Secret | Uso |
|---|---|
| `AWS_ROLE_ARN` | ARN da IAM Role assumida pelo GitHub Actions via OIDC. |
| `ALERT_EMAIL` | Endereço que recebe as notificações do SNS. |

O ambiente `production` deve possuir uma regra de aprovação manual com um required reviewer.

O endereço de e-mail do SNS precisa ser confirmado pelo link enviado pela AWS. Uma subscription não confirmada permanece como `PendingConfirmation` e não entrega notificações.

## Terraform

O backend remoto utiliza S3 com criptografia e lock remoto:

```text
Bucket: lacrei-desafio-terraform-state
Key:    lacrei-desafio/terraform.tfstate
Region: us-east-1
```

Os comandos devem ser executados dentro de `Terraform/`:

```bash
cd Terraform
AWS_PROFILE=lacrei-desafio terraform init
AWS_PROFILE=lacrei-desafio terraform plan
```

O `terraform apply` deve ser executado somente após revisar o plano:

```bash
AWS_PROFILE=lacrei-desafio terraform apply
```

Não use `terraform plan -lock=false` ou `terraform apply -lock=false` para contornar um lock. Primeiro confirme que não existe outro Terraform local ou workflow do GitHub Actions usando o mesmo state. O `force-unlock` só deve ser usado quando o lock estiver comprovadamente obsoleto.

Para consultar os endpoints publicados:

```bash
AWS_PROFILE=lacrei-desafio terraform output
```

## Monitoramento

Há um alarme CloudWatch por ambiente para a métrica `AWS/ApplicationELB/UnHealthyHostCount`. O alarme entra em `ALARM` quando pelo menos um target permanece unhealthy durante dois períodos de 60 segundos. O tópico SNS possui uma subscription de e-mail confirmada.

A configuração atual utiliza `TreatMissingData: missing`. Isso faz com que a ausência de datapoints possa resultar em `INSUFFICIENT_DATA`, em vez de tratar automaticamente a ausência como falha. Essa decisão deve ser mantida ou alterada de forma explícita, considerando o comportamento desejado para o ambiente.

Para consultar os alarmes:

```bash
AWS_PROFILE=lacrei-desafio aws cloudwatch describe-alarms \
  --alarm-name-prefix lacrei-desafio \
  --region us-east-1 \
  --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' \
  --output table
```

Para consultar a subscription do SNS:

```bash
AWS_PROFILE=lacrei-desafio aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:905542450009:lacrei-desafio-alerts \
  --region us-east-1 \
  --query 'Subscriptions[*].[Protocol,Endpoint,SubscriptionArn]' \
  --output table
```

## Custos e limpeza

A arquitetura pode gerar custos na AWS, principalmente por NAT Gateway, ALB, CloudFront, Fargate, CloudWatch e armazenamento no ECR. Em um ambiente de portfólio, destrua os recursos quando não estiverem em uso:

```bash
cd Terraform
AWS_PROFILE=lacrei-desafio terraform plan -destroy
AWS_PROFILE=lacrei-desafio terraform destroy
```

Revise o plano de destruição antes de confirmar. O comando é destrutivo e remove a infraestrutura provisionada por este state.

## Melhorias futuras

As próximas melhorias técnicas são adicionar testes automatizados para a aplicação, revisar as versões das actions do GitHub Actions que geram aviso de depreciação do Node.js 20 e decidir formalmente a política de `treat_missing_data` dos alarmes.

## Referências

[1]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html "AWS Fargate Developer Guide"
[2]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html "Amazon CloudWatch alarms that send email"
[3]: https://docs.aws.amazon.com/sns/latest/dg/sns-email-notifications.html "Amazon SNS email notifications"
[4]: https://developer.hashicorp.com/terraform/language/settings/backends/s3 "Terraform S3 backend"
[5]: https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services "GitHub Actions OpenID Connect with AWS"
