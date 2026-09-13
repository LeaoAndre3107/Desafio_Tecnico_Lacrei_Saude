# O provider OIDC do GitHub já existe nesta conta (criado pelo bancox-eks).
# Reaproveitamos via data source - criar de novo daria erro de recurso duplicado.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions" {
  name = "lacrei-desafio-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          # Restrito ao repo E ao branch main - nenhum PR de fora, nenhum outro
          # branch, consegue assumir esta role.
          # IMPORTANTE: o GitHub inclui IDs imutaveis de owner/repo no sub claim
          # (repo:owner@ownerId/repo@repoId:ref:...), nao so os nomes. Confirmado
          # via CloudTrail (evento AssumeRoleWithWebIdentity real, errorCode
          # AccessDenied) - o formato so-nome nao bate mais com o token emitido.
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo_name}@${var.github_repo_id}:ref:refs/heads/${var.github_branch}"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Mesmo escopo de permissoes do usuario lacrei-desafio-deploy (IAM humano),
# agora numa role assumida via OIDC pelo pipeline - sem access key de longa
# duracao guardada como secret no GitHub.
resource "aws_iam_role_policy" "github_actions" {
  name = "lacrei-desafio-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "NetworkFull"
        Effect   = "Allow"
        Action   = ["ec2:*"]
        Resource = "*"
      },
      {
        Sid      = "EcsEcrElb"
        Effect   = "Allow"
        Action   = ["ecs:*", "ecr:*", "elasticloadbalancing:*"]
        Resource = "*"
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:DescribeLogGroups",
          "logs:TagResource",
          "logs:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "IamRolesForEcsOnly"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:TagRole",
          "iam:ListInstanceProfilesForRole",
          "iam:UpdateAssumeRolePolicy"
        ]
        Resource = "arn:aws:iam::${var.account_id}:role/lacrei-desafio-*"
      },
      {
        Sid      = "OidcProviderReadOnly"
        Effect   = "Allow"
        Action   = ["iam:ListOpenIDConnectProviders"]
        Resource = "*"
      },
      {
        Sid      = "OidcProviderGet"
        Effect   = "Allow"
        Action   = ["iam:GetOpenIDConnectProvider"]
        Resource = "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"
      },
      {
        Sid    = "TerraformStateBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.terraform_state_bucket}",
          "arn:aws:s3:::${var.terraform_state_bucket}/*"
        ]
      }
    ]
  })
}
