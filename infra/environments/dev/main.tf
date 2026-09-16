data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  prefix = "${var.name}-${var.environment}"
  azs    = slice(data.aws_availability_zones.available.names, 0, 2)
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${local.prefix}-public-${count.index + 1}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
  name_prefix = "${local.prefix}-alb-"
  description = "Temporary public HTTP entrypoint for the disposable Odoo demo"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Temporary demo HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "task" {
  name_prefix = "${local.prefix}-task-"
  description = "Odoo task accepts traffic only from the ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port       = 8069
    to_port         = 8069
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "database" {
  name_prefix = "${local.prefix}-db-"
  description = "RDS PostgreSQL only accepts Odoo task connections"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.task.id]
  }
}

resource "aws_security_group" "efs" {
  name_prefix = "${local.prefix}-efs-"
  description = "EFS NFS only accepts Odoo task connections"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.task.id]
  }
}

resource "random_password" "database" {
  length  = 32
  special = false
}

resource "random_password" "odoo_superadmin" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "database" {
  name                    = "${local.prefix}/database"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    host            = aws_db_instance.postgres.address
    port            = 5432
    username        = "odoo"
    password        = random_password.database.result
    odoo_superadmin = random_password.odoo_superadmin.result
  })
}

resource "aws_db_subnet_group" "this" {
  name       = local.prefix
  subnet_ids = aws_subnet.public[*].id
}

resource "aws_db_instance" "postgres" {
  identifier                 = local.prefix
  engine                     = "postgres"
  instance_class             = var.db_instance_class
  allocated_storage          = 20
  max_allocated_storage      = 30
  storage_type               = "gp3"
  storage_encrypted          = true
  username                   = "odoo"
  password                   = random_password.database.result
  db_subnet_group_name       = aws_db_subnet_group.this.name
  vpc_security_group_ids     = [aws_security_group.database.id]
  publicly_accessible        = false
  multi_az                   = false
  backup_retention_period    = 1
  deletion_protection        = false
  skip_final_snapshot        = true
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true
}

resource "aws_efs_file_system" "odoo" {
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }
}

resource "aws_efs_mount_target" "odoo" {
  file_system_id  = aws_efs_file_system.odoo.id
  subnet_id       = aws_subnet.public[0].id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_cloudwatch_log_group" "odoo" {
  name              = "/ecs/${local.prefix}/odoo"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "rag" {
  name              = "/ecs/${local.prefix}/rag"
  retention_in_days = 7
}

resource "aws_iam_role" "execution" {
  name = "${local.prefix}-ecs-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "execution_secrets" {
  name = "read-runtime-secret"
  role = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.database.arn
    }]
  })
}

resource "aws_iam_role" "task" {
  name               = "${local.prefix}-ecs-task"
  assume_role_policy = aws_iam_role.execution.assume_role_policy
}

resource "aws_ecs_cluster" "this" {
  name = local.prefix
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_lb" "odoo" {
  name                       = substr("${local.prefix}-alb", 0, 32)
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = aws_subnet.public[*].id
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "odoo" {
  name        = substr("${local.prefix}-odoo", 0, 32)
  port        = 8069
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this.id

  health_check {
    path                = "/web/login"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.odoo.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.odoo.arn
  }
}

resource "aws_ecs_task_definition" "odoo" {
  family                   = local.prefix
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  volume {
    name = "odoo-filestore"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.odoo.id
      transit_encryption = "ENABLED"
    }
  }

  container_definitions = jsonencode([
    {
      name        = "source-bootstrap"
      image       = "alpine/git:2.47.2"
      essential   = false
      command     = ["sh", "-c", "rm -rf /mnt/shared/repository /mnt/shared/erp_ai_assistant && git clone --depth 1 https://github.com/coolcmyk/AWS_OpsLab.git /mnt/shared/repository && cp -R /mnt/shared/repository/odoo/addons/erp_ai_assistant /mnt/shared/erp_ai_assistant"]
      mountPoints = [{ sourceVolume = "odoo-filestore", containerPath = "/mnt/shared", readOnly = false }]
    },
    {
      name             = "rag-service"
      image            = "python:3.12-slim"
      essential        = true
      dependsOn        = [{ containerName = "source-bootstrap", condition = "SUCCESS" }]
      workingDirectory = "/mnt/shared/repository/rag-service"
      command          = ["sh", "-c", "pip install --no-cache-dir -r requirements.txt && uvicorn app:app --host 0.0.0.0 --port 8000"]
      portMappings     = [{ containerPort = 8000, protocol = "tcp" }]
      mountPoints      = [{ sourceVolume = "odoo-filestore", containerPath = "/mnt/shared", readOnly = true }]
      environment      = [{ name = "AI_PROVIDER", value = "mock" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.rag.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name         = "odoo"
      image        = "odoo:17.0"
      essential    = true
      dependsOn    = [{ containerName = "rag-service", condition = "START" }]
      portMappings = [{ containerPort = 8069, protocol = "tcp" }]
      mountPoints = [
        { sourceVolume = "odoo-filestore", containerPath = "/var/lib/odoo", readOnly = false },
        { sourceVolume = "odoo-filestore", containerPath = "/mnt/extra-addons", readOnly = true }
      ]
      command = ["odoo", "-d", "odoo", "-i", "erp_ai_assistant", "--without-demo=all"]
      environment = [
        { name = "PORT", value = "5432" },
        { name = "USER", value = "odoo" },
        { name = "RAG_SERVICE_URL", value = "http://localhost:8000" },
        { name = "ODOO_DEMO_EMAIL", value = "admin@gmail.com" },
        { name = "ODOO_DEMO_PASSWORD", value = "admin" }
      ]
      secrets = [
        { name = "HOST", valueFrom = "${aws_secretsmanager_secret.database.arn}:host::" },
        { name = "PASSWORD", valueFrom = "${aws_secretsmanager_secret.database.arn}:password::" },
        { name = "ODOO_SUPERADMIN_PASSWORD", valueFrom = "${aws_secretsmanager_secret.database.arn}:odoo_superadmin::" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.odoo.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  depends_on = [
    aws_iam_role_policy_attachment.execution,
    aws_iam_role_policy.execution_secrets,
    aws_secretsmanager_secret_version.database,
    aws_efs_mount_target.odoo,
  ]
}

resource "aws_ecs_service" "odoo" {
  name            = local.prefix
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.odoo.arn
  desired_count   = var.deploy_service ? 1 : 0
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = true
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.task.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.odoo.arn
    container_name   = "odoo"
    container_port   = 8069
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${local.prefix}-unhealthy-targets"
  alarm_description   = "Odoo ALB has no healthy targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.odoo.arn_suffix
    TargetGroup  = aws_lb_target_group.odoo.arn_suffix
  }
}
