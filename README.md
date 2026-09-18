<div align="center">

# Desafio Técnico DevOps
## Lacrei Saúde

**Aplicação Node.js executada na AWS com infraestrutura como código, CI/CD seguro e rollback por imagem imutável**

<br />

![AWS](https://img.shields.io/badge/AWS-Cloud-orange?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Container-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-20-339933?style=for-the-badge&logo=node.js&logoColor=white)

</div>

> Este projeto implementa uma aplicação simples de status, mas trata os problemas que aparecem em um ambiente DevOps real: autenticação segura na AWS, separação de permissões, promoção controlada entre ambientes, análise de vulnerabilidades, alta disponibilidade e recuperação por rollback.

## O projeto em uma frase

O código é testado e empacotado em uma imagem Docker. A imagem recebe a SHA completa do commit como tag imutável, é validada em **staging** e depois é promovida para **production** sem um segundo build.

Essa abordagem evita que o artefato testado seja diferente do artefato publicado.

## Resultado validado

Os dois ambientes estão publicados por meio do CloudFront e responderam com sucesso:

| Ambiente | Endpoint | Resultado validado |
|---|---|---|
| **Staging** | [Acessar `/devops/staging/status`](https://d1gjy0g4ibj9zk.cloudfront.net/devops/staging/status) | `HTTP 200` |
| **Production** | [Acessar `/devops/production/status`](https://d1gjy0g4ibj9zk.cloudfront.net/devops/production/status) | `HTTP 200` |

A mesma imagem foi promovida entre os ambientes durante a validação:

```text
deddb239a66829abc8e75cd236671eddfec22e49
```

O rollback também foi executado com sucesso em staging:

```text
GitHub Actions run: 35309972742
Resultado: imagem SHA existente reaplicada no ECS e health-check aprovado
```

## O que foi solicitado e como foi implementado

| Necessidade | Implementação |
|---|---|
| Entrega segura | GitHub Actions assume roles temporárias na AWS usando OIDC. Não há access keys permanentes no repositório. |
| Least privilege | A role de infraestrutura é separada da role usada pelo deploy da aplicação. O deploy não acessa Terraform, state, VPC, WAF ou CloudFront. |
| Imagem rastreável | Cada imagem usa a SHA completa do commit como tag. |
| Tags imutáveis | O ECR impede sobrescrever uma tag já publicada. O pipeline reutiliza a imagem se ela já existir. |
| Promoção controlada | Staging é validado antes da aprovação do ambiente `production`. |
| Alta disponibilidade | Staging usa uma task. Production usa duas tasks Fargate. |
| Segurança da imagem | Trivy bloqueia imagens com vulnerabilidades `HIGH` ou `CRITICAL` corrigíveis. |
| Segurança da infraestrutura | Terraform é validado e examinado pelo Trivy antes do provisionamento. |
| Rollback | Workflow manual reaplica uma imagem SHA já existente no ECR, sem novo build. |
| Observabilidade | CloudWatch monitora targets unhealthy e publica alertas em um tópico SNS criptografado. |

## Arquitetura

<p align="center">
  <img src="docs/architecture.png" alt="Diagrama vertical da arquitetura AWS do projeto Lacrei Saúde" width="100%" />
</p>

A fonte editável do diagrama está em [`docs/architecture.mmd`](docs/architecture.mmd).

### Visão visual dos fluxos

O diagrama abaixo mostra como o código passa pelo GitHub Actions, pelo ECR e pelos ambientes ECS. Ele também evidencia que a mesma imagem validada em staging é promovida para production.

<p align="center">
  <img src="docs/cicd-flow.png" alt="Fluxo visual de CI/CD, validação, staging e promoção para production" width="100%" />
</p>

O diagrama de segurança mostra por que existem duas roles IAM. A role Terraform provisiona a plataforma; a role `app-deploy` executa somente as operações necessárias para ECR, ECS e rollback.

<p align="center">
  <img src="docs/iam-security.png" alt="Separação das roles IAM de Terraform e deploy da aplicação" width="100%" />
</p>

### Como uma requisição chega à aplicação

```text
Usuário
  │ HTTPS
  ▼
CloudFront
  │ Header secreto de origem
  ▼
Application Load Balancer
  │ Roteamento por caminho
  ├── /devops/staging/*    → ECS Fargate staging
  └── /devops/production/* → ECS Fargate production
                                  │
                                  ▼
                         Tasks em subnets privadas
```

### Como uma versão chega aos ambientes

```text
Push na branch main
        │
        ▼
GitHub Actions
        │ OIDC
        ▼
Role de deploy restrita
        │
        ├── npm ci + lint + testes
        ├── Docker build
        ├── Trivy na imagem
        ├── Smoke test local
        └── Push condicional no ECR
                │
                ▼
        Deploy em staging
                │
                ▼
        Health-check staging
                │
                ▼
        Aprovação do Environment production
                │
                ▼
        A mesma SHA em production
```

## Componentes da solução

| Camada | Serviço ou tecnologia | Responsabilidade |
|---|---|---|
| Aplicação | Node.js + Express | Expor a aplicação e a rota de status. |
| Qualidade | Jest, Supertest e ESLint | Testar comportamento e verificar qualidade do código. |
| Container | Docker com Node Alpine | Empacotar a aplicação e executá-la como usuário não-root. |
| Registry | Amazon ECR | Armazenar imagens com tags imutáveis. |
| Computação | Amazon ECS Fargate | Executar staging e production sem administrar servidores. |
| Rede | VPC, subnets públicas e privadas | Separar o tráfego de entrada das tasks da aplicação. |
| Entrada | ALB e CloudFront | Roteamento interno e acesso HTTPS público. |
| Proteção | AWS WAF | Aplicar regras gerenciadas ao CloudFront. |
| Infraestrutura | Terraform | Provisionar recursos AWS de forma reproduzível. |
| CI/CD | GitHub Actions | Validar, publicar, implantar e reverter versões. |
| Monitoramento | CloudWatch e SNS | Detectar targets unhealthy e notificar por e-mail. |

## Aplicação

A aplicação está em [`app/server.js`](app/server.js) e possui duas rotas:

| Método | Rota | Finalidade |
|---|---|---|
| `GET` | `/` | Retorna uma identificação simples da aplicação. |
| `GET` | `/status` | Retorna o estado, o uptime do processo e um timestamp. |

Exemplo de resposta:

```json
{
  "status": "ok",
  "uptime_seconds": 315.607,
  "timestamp": "2026-09-15T02:46:44.878Z"
}
```

Nos ambientes AWS, a variável `APP_PREFIX` adiciona o prefixo do ambiente:

```text
/devops/staging/status
/devops/production/status
```

A porta padrão é `3000` e pode ser alterada pela variável `PORT`.

## Estrutura do repositório

```text
.
├── app/
│   ├── server.js              # Aplicação Express
│   ├── server.test.js         # Testes Jest/Supertest
│   ├── package.json            # Scripts e dependências
│   ├── package-lock.json       # Dependências reproduzíveis
│   ├── .eslintrc.json          # Regras do ESLint
│   ├── Dockerfile              # Imagem de runtime
│   └── .dockerignore
├── scripts/
│   ├── deploy-ecs.sh           # Registra task definition e atualiza ECS
│   └── rollback-ecs.sh         # Reaplica uma imagem SHA existente
├── Terraform/
│   ├── backend.tf              # State remoto no S3
│   ├── main.tf                 # Composição da infraestrutura
│   ├── variables.tf
│   ├── outputs.tf
│   ├── iam/                    # Exemplos de políticas
│   └── modules/
│       ├── alerts/
│       ├── cloudfront/
│       ├── ecs-cluster/
│       ├── ecs-service/
│       ├── github-oidc/
│       └── network/
├── .github/workflows/
│   ├── infrastructure.yml      # Terraform
│   ├── deploy.yml              # Build e deploy da aplicação
│   └── rollback.yml            # Rollback por SHA
├── docs/
│   ├── architecture.mmd
│   └── architecture.png
└── README.md
```

Os scripts `deploy-ecs.sh` e `rollback-ecs.sh` estão versionados com permissão de execução (`755`). Isso evita o erro `Permission denied` ao chamá-los diretamente no runner.

## Executar a aplicação localmente

### Node.js

```bash
cd app
npm ci
npm start
```

Em outro terminal:

```bash
curl -i http://localhost:3000/status
```

### Lint e testes

```bash
cd app
npm run lint
npm test
```

Os testes verificam a rota `/status`, o código HTTP `200`, o campo `status`, o uptime, o timestamp e a rota raiz `/`.

O pipeline executa esses comandos antes do build Docker. Se o lint ou os testes falharem, a imagem não é publicada.

### Docker

```bash
cd app
docker build -t lacrei-status-app .
docker run --rm -p 3000:3000 lacrei-status-app
```

Valide o container:

```bash
curl -i http://localhost:3000/status
```

O Dockerfile utiliza `node:20-alpine`, instala somente as dependências de runtime com `npm ci --omit=dev`, executa o processo como usuário não-root e possui um `HEALTHCHECK` baseado em `/status`.

## Infraestrutura AWS com Terraform

A infraestrutura contém:

- VPC com CIDR `10.20.0.0/16`.
- Duas subnets públicas e duas subnets privadas em duas Availability Zones.
- Um NAT Gateway, escolhido para reduzir o custo do ambiente de demonstração.
- ECS Cluster com Container Insights.
- Serviço Fargate separado para staging e production.
- Uma task desejada em staging e duas tasks desejadas em production.
- ALB com regras por caminho.
- ECR com `image_tag_mutability = "IMMUTABLE"`.
- CloudFront com redirecionamento para HTTPS e métodos `GET` e `HEAD`.
- AWS WAF com `AWSManagedRulesCommonRuleSet`.
- Security Groups em camadas.
- CloudWatch, SNS e uma CMK dedicada para os alertas.

As tasks executam em subnets privadas e não recebem IP público. O Security Group das tasks aceita tráfego somente do Security Group do ALB.

### Limitações e decisões conscientes

O acesso público entre o usuário e o CloudFront utiliza HTTPS. O origin entre CloudFront e ALB utiliza HTTP porque esta entrega usa o domínio padrão `elb.amazonaws.com` e não possui um certificado ACM associado a um domínio controlado pelo projeto. O acesso direto ao ALB é reduzido pelo header secreto exigido no listener.

O NAT Gateway é único. Essa escolha reduz o custo do portfólio, mas significa que a saída das subnets privadas não possui alta disponibilidade completa. A alta disponibilidade da aplicação em production é garantida pelas duas tasks distribuídas nas subnets privadas; ela não deve ser confundida com redundância completa do caminho de saída da VPC.

### Backend do Terraform

O state é armazenado remotamente e protegido no S3:

```text
Bucket: lacrei-desafio-terraform-state
Key:    lacrei-desafio/terraform.tfstate
Region: us-east-1
Lock:   lock nativo do backend S3
```

Nunca use `-lock=false` apenas para contornar um lock. Antes de usar `force-unlock`, confirme que não existe outro Terraform local ou workflow utilizando o mesmo state.

## IAM e autenticação OIDC

OIDC permite que o GitHub Actions troque um token temporário por credenciais AWS. Assim, o repositório não precisa armazenar access keys permanentes.

O projeto separa as responsabilidades:

| Role | Uso | Escopo |
|---|---|---|
| `lacrei-desafio-github-actions` | `infrastructure.yml` | Mais ampla, pois cria e altera recursos de infraestrutura. |
| `lacrei-desafio-app-deploy` | `deploy.yml` e `rollback.yml` | Restrita a ECR e ECS da aplicação. |

A role de deploy não possui acesso ao state Terraform nem às operações de VPC, CloudFront, WAF ou KMS. A permissão `iam:PassRole` é limitada às roles de execução ECS da aplicação.

O princípio de menor privilégio foi aplicado de forma mais rigorosa à role de aplicação. A role Terraform permanece necessariamente mais ampla porque precisa provisionar os componentes do desafio.

A trust policy restringe o repositório, os IDs imutáveis do proprietário e do repositório, a branch `main` e os Environments usados pelos workflows.

## Workflows do GitHub Actions

### `infrastructure.yml`

Responsável pela infraestrutura. Executa:

```text
Terraform fmt
  → Terraform init sem backend
  → Terraform validate
  → Trivy config Terraform
  → autenticação OIDC com role Terraform
  → terraform init com state remoto
  → terraform plan
  → upload do plano
  → apply somente quando acionado manualmente com aprovação
```

Esse workflow não deve ser usado para o deploy rotineiro da aplicação.

### `deploy.yml`

Responsável pela entrega da aplicação. É acionado por alterações em `app/**`, `scripts/**` ou no próprio workflow de deploy. Ele:

1. Faz checkout do código.
2. Assume a role restrita por OIDC.
3. Executa `npm ci`, lint e testes.
4. Constrói a imagem com a SHA do commit.
5. Executa Trivy para vulnerabilidades `HIGH` e `CRITICAL`.
6. Executa um smoke test HTTP no container local.
7. Verifica se a tag já existe no ECR e faz push somente quando necessário.
8. Atualiza o serviço ECS de staging.
9. Aguarda o serviço ficar estável e valida a URL pública.
10. Aguarda a aprovação do Environment `production`.
11. Reutiliza exatamente a mesma SHA em production.
12. Valida a URL pública de production.

A promoção não faz um novo build. Isso reduz o risco de staging e production receberem artefatos diferentes.

### `rollback.yml`

Responsável pelo rollback operacional da aplicação. Ele é acionado manualmente e não executa Terraform.

O fluxo real é:

```text
Selecionar ambiente
  → informar SHA de 40 caracteres
  → digitar ROLLBACK
  → validar que a imagem existe no ECR
  → registrar nova task definition com essa imagem
  → atualizar o ECS
  → aguardar estabilidade
  → executar health-check
```

O rollback não cria uma imagem nova e não depende de uma branch especial. Ele reaplica diretamente uma imagem já publicada e validada no ECR.

### Operação, alertas e rollback em uma única visão

O diagrama abaixo conecta o tráfego do usuário, o monitoramento do ALB, a notificação por SNS e o caminho operacional de rollback.

<p align="center">
  <img src="docs/operations-flow.png" alt="Fluxo de operação, monitoramento, alertas e rollback" width="100%" />
</p>

## Como executar um rollback

### 1. Listar imagens disponíveis

```bash
AWS_PROFILE=lacrei-desafio aws ecr describe-images \
  --repository-name devops-app \
  --region us-east-1 \
  --query 'sort_by(imageDetails,& imagePushedAt)[-10:].[imageTags[0],imagePushedAt,imageDigest]' \
  --output table
```

Escolha uma tag hexadecimal de 40 caracteres que represente uma versão estável.

### 2. Iniciar o workflow

Pelo GitHub:

```text
Actions → Rollback DevOps App → Run workflow
```

Preencha:

```text
environment: staging ou production
image_tag: SHA de 40 caracteres existente no ECR
confirm: ROLLBACK
```

A palavra `ROLLBACK` precisa ser digitada exatamente em letras maiúsculas.

Também é possível iniciar pelo CLI:

```bash
gh workflow run rollback.yml \
  --repo LeaoAndre3107/Desafio_Tecnico_Lacrei_Saude \
  --ref main \
  -f environment=staging \
  -f image_tag=5438c8569dd477faadde95f08a4662e40ed72fc7 \
  -f confirm=ROLLBACK
```

Depois consulte o run:

```bash
gh run list \
  --repo LeaoAndre3107/Desafio_Tecnico_Lacrei_Saude \
  --workflow rollback.yml \
  --limit 3
```

### 3. Validar o resultado

```bash
curl -sS -o /dev/null -w "staging: HTTP %{http_code}\n" \
  "https://d1gjy0g4ibj9zk.cloudfront.net/devops/staging/status"
```

O resultado esperado é:

```text
staging: HTTP 200
```

Para production, use a URL correspondente e siga a aprovação do Environment configurado no GitHub.

### Rollback emergencial direto no ECS

Em uma indisponibilidade que exija ação imediata, é possível apontar temporariamente o serviço para uma revision anterior da task definition:

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

Esse é um procedimento emergencial separado do workflow oficial. Depois dele, valide os endpoints e registre a correção necessária, pois um deploy ou `terraform apply` posterior pode reaplicar a configuração anterior.

## Monitoramento e alertas

Existe um alarme por ambiente para a métrica:

```text
AWS/ApplicationELB/UnHealthyHostCount
```

| Parâmetro | Configuração |
|---|---|
| Período | 60 segundos |
| Avaliação | 2 períodos |
| Estatística | `Maximum` |
| Limite | `>= 1` target unhealthy |
| Dados ausentes | `breaching` |
| Ação | Publicação no SNS |

O tópico SNS é criptografado com uma CMK dedicada. A subscription de e-mail foi confirmada e recebeu notificação de mudança de estado.

Consultar os alarmes:

```bash
AWS_PROFILE=lacrei-desafio aws cloudwatch describe-alarms \
  --alarm-name-prefix lacrei-desafio \
  --region us-east-1 \
  --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' \
  --output table
```

Consultar a subscription:

```bash
AWS_PROFILE=lacrei-desafio aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:905542450009:lacrei-desafio-alerts \
  --region us-east-1 \
  --query 'Subscriptions[*].[Protocol,Endpoint,SubscriptionArn]' \
  --output table
```

## Secrets e variáveis do GitHub

Configure em **Settings → Secrets and variables → Actions**.

### Secrets

| Nome | Tipo | Uso |
|---|---|---|
| `AWS_TERRAFORM_ROLE_ARN` | Secret | ARN da role usada por `infrastructure.yml`. |
| `AWS_DEPLOY_ROLE_ARN` | Secret | ARN da role usada por `deploy.yml` e `rollback.yml`. |
| `ALERT_EMAIL` | Secret | E-mail usado pela subscription SNS e pelo Terraform. |

### Variables

| Nome | Tipo | Valor |
|---|---|---|
| `STAGING_URL` | Variable | `https://d1gjy0g4ibj9zk.cloudfront.net/devops/staging/status` |
| `PRODUCTION_URL` | Variable | `https://d1gjy0g4ibj9zk.cloudfront.net/devops/production/status` |

Nas URLs, o valor deve conter somente o endereço. Não inclua `STAGING_URL=` ou `PRODUCTION_URL=` dentro do campo Value.

O Environment `production` deve possuir um required reviewer para manter a aprovação manual antes da promoção.

## Erros encontrados e decisões técnicas

| Problema | Causa | Solução aplicada |
|---|---|---|
| Push repetido em tag imutável | A imagem do mesmo SHA já existia no ECR após uma execução parcial. | O pipeline consulta o ECR e reutiliza a imagem existente. |
| Falha de lint no runner | A configuração do ESLint não estava no diretório `app`. | A configuração foi colocada em `app/.eslintrc.json`, junto do `package.json`. |
| Falha ao assumir a role no rollback | O job usa GitHub Environment e gera um `sub` OIDC diferente. | A trust policy passou a aceitar os subjects de branch e dos Environments `staging` e `production`. |
| Falha no script ECS | O bit executável não estava garantido no checkout do CI. | Os scripts foram versionados como executáveis e o workflow aplica `chmod +x`. |
| Falha do Trivy com action inexistente | A versão informada da action não existia. | A action foi atualizada para uma versão disponível. |
| Falta de permissão para WAF e KMS | A role Terraform não tinha todas as ações necessárias para os recursos adicionados. | As permissões foram ajustadas na role de infraestrutura, sem concedê-las à role de deploy. |
| Lock remoto do Terraform | Execuções interrompidas deixaram o state bloqueado. | O processo verifica workflows e processos ativos antes de usar `force-unlock`; `-lock=false` não é usado. |
| Alarme sem datapoints | Um target group sem tasks não produzia dados suficientes. | `treat_missing_data = "breaching"` trata ausência de métrica como condição de alerta. |
| Risco de artefatos diferentes | Um novo build poderia ser feito diretamente para production. | A mesma SHA validada em staging é promovida para production. |
| ALB acessível diretamente | O ALB é público porque funciona como origin do CloudFront. | O listener exige um header secreto de verificação de origem e as tasks ficam privadas. |

Esses erros fazem parte da evolução do projeto e foram resolvidos na versão final. Os runs históricos com falha não representam o estado atual do pipeline; eles registram problemas encontrados durante a implementação.

## Checklist de segurança aplicado

| Controle | Status | Evidência |
|---|---:|---|
| Access keys AWS permanentes no GitHub | ✅ | OIDC e credenciais temporárias. |
| Separação entre infraestrutura e aplicação | ✅ | Roles Terraform e app-deploy distintas. |
| Deploy sem acesso ao state Terraform | ✅ | Role `app-deploy` não recebe permissões S3 do state. |
| `iam:PassRole` restrito | ✅ | Limitado às roles de execução ECS da aplicação. |
| Permissões mínimas do workflow | ✅ | `id-token: write` e `contents: read`. |
| Tags ECR imutáveis | ✅ | ECR configurado com `IMMUTABLE`. |
| Tasks sem IP público | ✅ | Fargate em subnets privadas. |
| Security Group das tasks | ✅ | Entrada permitida somente a partir do ALB. |
| HTTPS para usuários | ✅ | CloudFront redireciona para HTTPS. |
| Métodos CloudFront | ✅ | Somente `GET` e `HEAD`. |
| WAF | ✅ | Web ACL associado ao CloudFront. |
| Criptografia de alertas | ✅ | SNS usa CMK dedicada com rotação. |
| Logs da aplicação | ✅ | CloudWatch Logs na task definition. |
| State remoto | ✅ | S3 com criptografia e lock nativo. |
| Alertas por e-mail | ✅ | Subscription confirmada e testada. |
| Rollback validado | ✅ | Run `35309972742` concluído com sucesso. |

A role Terraform continua mais ampla por necessidade de provisionar a infraestrutura completa. O escopo de menor privilégio é especialmente restritivo nas roles que executam deploy e rollback, que são usadas com maior frequência.

## Limpeza da infraestrutura

Os recursos AWS geram custos enquanto permanecem ativos. Para revisar a destruição:

```bash
cd Terraform
AWS_PROFILE=lacrei-desafio terraform plan -destroy
```

Se a destruição for realmente desejada:

```bash
AWS_PROFILE=lacrei-desafio terraform destroy
```

Revise o plano antes de confirmar. A destruição remove a infraestrutura provisionada pelo state e não deve ser executada como parte do fluxo normal de deploy.

## Referências técnicas

[1]: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect "GitHub Actions OpenID Connect"
[2]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html "AWS IAM OIDC identity providers"
[3]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html "Amazon ECS task definition parameters"
[4]: https://developer.hashicorp.com/terraform/language/backend/s3 "Terraform S3 backend"
[5]: https://aquasecurity.github.io/trivy/latest/docs/ "Trivy documentation"

<div align="center">

**Desafio Técnico DevOps — Lacrei Saúde**

</div>
