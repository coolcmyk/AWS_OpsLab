variable "name" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }

resource "random_password" "db" { length = 28 special = false }
resource "aws_db_subnet_group" "this" { name = "${var.name}-db" subnet_ids = var.subnet_ids }
resource "aws_db_instance" "this" {
  identifier = "${var.name}-postgres"
  engine = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"
  allocated_storage = 20
  max_allocated_storage = 30
  db_name = "secureai"
  username = "secureai"
  password = random_password.db.result
  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible = false
  storage_encrypted = true
  backup_retention_period = 1
  deletion_protection = false
  skip_final_snapshot = true # Demo environment only; do not use in production.
}
resource "aws_secretsmanager_secret" "app" { name = "${var.name}/database" recovery_window_in_days = 0 }
resource "aws_secretsmanager_secret_version" "app" { secret_id = aws_secretsmanager_secret.app.id secret_string = jsonencode({ url = "postgresql://secureai:${random_password.db.result}@${aws_db_instance.this.address}:5432/secureai" }) }
output "app_secret_arn" { value = aws_secretsmanager_secret.app.arn }
