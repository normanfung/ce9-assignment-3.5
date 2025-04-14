variable "aws_region" {
  default = "us-east-1"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "secret_string" {
  description = "The secret string value for the DB password"
  type        = string
  sensitive   = true
}

variable "ssm_string" {
  description = "The secret string value for the DB password"
  type        = string
  sensitive   = true
}

