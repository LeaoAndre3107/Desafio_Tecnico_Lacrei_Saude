# Desafio Técnico DevOps — Lacrei Saúde

## Arquitetura

App Node.js/Express containerizado, rodando em ECS Fargate atrás de um Application Load Balancer, com roteamento por path (`/devops/*`). Infraestrutura 100% como código via Terraform, deploy automatizado via GitHub Actions autenticado por OIDC (sem access keys de longa duração armazenadas como secret).

```
GitHub Actions (OIDC) → build/push imagem → ECR (IMMUTABLE)
                       → terraform apply → ECS Fargate (task nova)
                                          → ALB (path routing) → /devops/status
```

## Estrutura do repositório

```
app/          # App Node.js/Express (rota /status, health-check)
Terraform/    # IaC: VPC, ECS Cluster, ALB, ECR, OIDC role
.github/      # Pipeline de deploy (GitHub Actions)
```

## Decisões técnicas relevantes

- **VPC dedicada** (`10.20.0.0/16`), NAT Gateway único (custo consciente para ambiente de portfólio).
- **ALB único, roteamento por path** (`/devops/*`) em vez de subdomínios — evita custo/complexidade de DNS extra.
- **ECR com `IMMUTABLE` tags** — cada build gera uma tag única (SHA do commit), nunca sobrescreve uma imagem já publicada.
- **Autenticação via OIDC** (GitHub Actions → AWS), sem access keys estáticas guardadas como secret no repositório.
- **Security groups em camadas**: só o ALB aceita tráfego público (porta 80); as tasks Fargate só aceitam tráfego do security group do ALB, nunca da internet direto.
- **IAM escopado por prefixo de recurso** (`lacrei-desafio-*`) onde a API permite, documentado em `Terraform/iam/lacrei-desafio-policy.example.json`.

## Como rodar localmente

```bash
cd app
npm install
npm start
curl http://localhost:3000/status
```

## Deploy

Automático via GitHub Actions a cada push em `main` que altere `app/` ou `Terraform/`. Ver `.github/workflows/deploy.yml`.
