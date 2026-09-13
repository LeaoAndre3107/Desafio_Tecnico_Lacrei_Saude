variable "github_repo" {
  description = "owner/repo do GitHub, ex: LeaoAndre3107/Desafio_Tecnico_Lacrei_Saude"
  type        = string
}

variable "github_branch" {
  description = "Branch autorizada a assumir a role via OIDC"
  type        = string
  default     = "main"
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
