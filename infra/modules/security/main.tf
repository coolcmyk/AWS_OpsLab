variable "name" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "allowed_cidr" { type = string }

resource "aws_security_group" "alb" { name = "${var.name}-alb" vpc_id = var.vpc_id
  ingress { from_port = 80 to_port = 80 protocol = "tcp" cidr_blocks = [var.allowed_cidr] }
  egress { from_port = 8080 to_port = 8080 protocol = "tcp" cidr_blocks = [var.vpc_cidr] }
}
resource "aws_security_group" "app" { name = "${var.name}-app" vpc_id = var.vpc_id
  ingress { from_port = 8080 to_port = 8080 protocol = "tcp" security_groups = [aws_security_group.alb.id] }
  egress { from_port = 443 to_port = 443 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress { from_port = 5432 to_port = 5432 protocol = "tcp" cidr_blocks = [var.vpc_cidr] }
}
resource "aws_security_group" "lambda" { name = "${var.name}-lambda" vpc_id = var.vpc_id
  egress { from_port = 443 to_port = 443 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress { from_port = 5432 to_port = 5432 protocol = "tcp" cidr_blocks = [var.vpc_cidr] }
}
resource "aws_security_group" "rds" { name = "${var.name}-rds" vpc_id = var.vpc_id
  ingress { from_port = 5432 to_port = 5432 protocol = "tcp" security_groups = [aws_security_group.app.id, aws_security_group.lambda.id] }
}
output "alb_security_group_id" { value = aws_security_group.alb.id }
output "app_security_group_id" { value = aws_security_group.app.id }
output "lambda_security_group_id" { value = aws_security_group.lambda.id }
output "rds_security_group_id" { value = aws_security_group.rds.id }
