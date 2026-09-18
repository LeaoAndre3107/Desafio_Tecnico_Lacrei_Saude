# O provider OIDC do GitHub já existe nesta conta (criado pelo bancox-eks).
# Reaproveitamos via data source - criar de novo daria erro de recurso duplicado.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_region" "current" {}

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
          # Restrito ao repo E (branch main OU job com environment: production)
          # - nenhum PR de fora, nenhum outro branch/environment, consegue
          # assumir esta role.
          # IMPORTANTE: o GitHub inclui IDs imutaveis de owner/repo no sub claim
          # (repo:owner@ownerId/repo@repoId:ref:...), nao so os nomes. Confirmado
          # via CloudTrail. Alem disso, um job que declara `environment:` no
          # workflow gera um sub DIFERENTE do formato ref:refs/heads/... - vira
          # `repo:.../...:environment:<nome>` em vez de incluir o branch. Os
          # dois formatos precisam estar cobertos aqui (tambem confirmado via
          # CloudTrail, nao documentacao).
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo_name}@${var.github_repo_id}:ref:refs/heads/${var.github_branch}",
              "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo_name}@${var.github_repo_id}:environment:${var.github_staging_environment}",
              "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo_name}@${var.github_repo_id}:environment:${var.github_production_environment}"
            ]
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
        Sid      = "CloudFront"
        Effect   = "Allow"
        Action   = ["cloudfront:*"]
        Resource = "*"
      },
      {
        Sid    = "CloudFrontWaf"
        Effect = "Allow"
        Action = [
          "wafv2:CreateWebACL",
          "wafv2:DeleteWebACL",
          "wafv2:GetWebACL",
          "wafv2:ListWebACLs",
          "wafv2:ListTagsForResource",
          "wafv2:TagResource",
          "wafv2:UntagResource",
          "wafv2:UpdateWebACL"
        ]
        Resource = "*"
      },
      {
        Sid    = "AlertsSnsCloudWatch"
        Effect = "Allow"
        Action = [
          "sns:CreateTopic",
          "sns:DeleteTopic",
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes",
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:ListSubscriptionsByTopic",
          "sns:TagResource",
          "sns:ListTagsForResource",
          "sns:GetSubscriptionAttributes",
          "sns:SetSubscriptionAttributes",
          "sns:ListSubscriptions",
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListTagsForResource",
          "cloudwatch:TagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "KmsForAlertsProvisioning"
        Effect = "Allow"
        Action = [
          "kms:CreateAlias",
          "kms:CreateKey",
          "kms:DescribeKey",
          "kms:DisableKey",
          "kms:EnableKey",
          "kms:EnableKeyRotation",
          "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus",
          "kms:ListAliases",
          "kms:ListResourceTags",
          "kms:PutKeyPolicy",
          "kms:ScheduleKeyDeletion",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:UpdateAlias"
        ]
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

# Role exclusiva para deploy da aplicação. Não possui permissões de Terraform,
# VPC, CloudFront, WAF, KMS ou acesso ao state remoto.
resource "aws_iam_role" "app_deploy" {
  name = "lacrei-desafio-app-deploy"

  assume_role_policy = aws_iam_role.github_actions.assume_role_policy
  tags               = var.tags
}

resource "aws_iam_role_policy" "app_deploy" {
  name = "lacrei-desafio-app-deploy-policy"
  role = aws_iam_role.app_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrLogin"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "EcrApplicationRepository"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = "arn:aws:ecr:${data.aws_region.current.name}:${var.account_id}:repository/devops-app"
      },
      {
        Sid    = "EcsDeployment"
        Effect = "Allow"
        Action = [
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassOnlyApplicationRolesToEcs"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          "arn:aws:iam::${var.account_id}:role/lacrei-desafio-devops-app-staging-exec-role",
          "arn:aws:iam::${var.account_id}:role/lacrei-desafio-devops-app-production-exec-role"
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}
