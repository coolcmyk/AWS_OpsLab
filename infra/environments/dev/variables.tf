variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "name" {
  type    = string
  default = "odoo-intelligence"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.80.0.0/16"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "deploy_service" {
  description = "Set only after both ECR images have been pushed."
  type        = bool
  default     = false
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "tags" {
  type    = map(string)
  default = {}
}
