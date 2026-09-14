variable "github_owner" {
  description = "Owner/organização do repo no GitHub, ex: LeaoAndre3107"
  type        = string
}

variable "github_owner_id" {
  description = "ID numerico imutavel do owner (obtido via API: /users/<owner> -> id, ou visto no sub claim real via CloudTrail)"
  type        = string
}

variable "github_repo_name" {
  description = "Nome do repositorio, ex: Desafio_Tecnico_Lacrei_Saude"
  type        = string
}

variable "github_repo_id" {
  description = "ID numerico imutavel do repositorio (obtido via API: /repos/<owner>/<repo> -> id, ou visto no sub claim real via CloudTrail)"
  type        = string
}

variable "github_branch" {
  description = "Branch autorizada a assumir a role via OIDC"
  type        = string
  default     = "main"
}

variable "github_production_environment" {
  description = "Nome do GitHub Environment usado pelo job de producao (sub claim muda de formato quando o job declara `environment:`)"
  type        = string
  default     = "production"
}

variable "account_id" {
  description = "Account ID da AWS"
  type        = string
}

variable "terraform_state_bucket" {
  description = "Bucket S3 do state, pro pipeline poder rodar terraform apply"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
