variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "athlete-face-api"
}

variable "table_name" {
  type    = string
  default = "Players"
}

variable "bucket_name" {
  type    = string
  default = "athlete-photos-team2"
}

variable "allowed_origins" {
  type    = list(string)
  default = ["*"]
}

variable "index_lambda_timeout" {
  type    = number
  default = 300
}

variable "search_lambda_timeout" {
  type    = number
  default = 30
}

variable "invoke_index_on_apply" {
  type    = bool
  default = true
}