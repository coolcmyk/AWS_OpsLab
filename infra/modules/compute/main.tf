variable "name" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_id" { type = string }
variable "alb_security_group_id" { type = string }
variable "app_security_group_id" { type = string }
variable "database_url_secret_arn" { type = string }
variable "image_tag" { type = string }

resource "aws_ecr_repository" "app" { name = "${var.name}-app" image_scanning_configuration { scan_on_push = true } }
resource "aws_ecr_lifecycle_policy" "app" { repository = aws_ecr_repository.app.name policy = jsonencode({ rules = [{ rulePriority = 1, description = "Keep 10 images", selection = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }, action = { type = "expire" } }] }) }
data "aws_iam_policy_document" "ec2_assume" { statement { actions = ["sts:AssumeRole"] principals { type = "Service" identifiers = ["ec2.amazonaws.com"] } } }
resource "aws_iam_role" "app" { name = "${var.name}-app" assume_role_policy = data.aws_iam_policy_document.ec2_assume.json }
resource "aws_iam_role_policy_attachment" "ssm" { role = aws_iam_role.app.name policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" }
resource "aws_cloudwatch_log_group" "app" { name = "/secureai/${var.name}/app" retention_in_days = 14 }
data "aws_iam_policy_document" "app" { statement { actions = ["secretsmanager:GetSecretValue"] resources = [var.database_url_secret_arn] } statement { actions = ["ecr:GetAuthorizationToken"] resources = ["*"] } statement { actions = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"] resources = [aws_ecr_repository.app.arn] } statement { actions = ["logs:CreateLogStream", "logs:PutLogEvents"] resources = ["${aws_cloudwatch_log_group.app.arn}:*"] } }
resource "aws_iam_role_policy" "app" { name = "${var.name}-app-runtime" role = aws_iam_role.app.id policy = data.aws_iam_policy_document.app.json }
resource "aws_iam_instance_profile" "app" { name = "${var.name}-app" role = aws_iam_role.app.name }
data "aws_ami" "al2023" { most_recent = true owners = ["amazon"] filter { name = "name" values = ["al2023-ami-*-x86_64"] } }
resource "aws_instance" "app" {
  ami = data.aws_ami.al2023.id
  instance_type = "t3.micro"
  subnet_id = var.private_subnet_id
  vpc_security_group_ids = [var.app_security_group_id]
  iam_instance_profile = aws_iam_instance_profile.app.name
  metadata_options { http_tokens = "required" }
  user_data = templatefile("${path.module}/user_data.sh.tftpl", { repo = aws_ecr_repository.app.repository_url, tag = var.image_tag, secret_arn = var.database_url_secret_arn, log_group = aws_cloudwatch_log_group.app.name })
  tags = { Name = "${var.name}-app" }
}
resource "aws_lb" "app" { name = substr("${var.name}-alb", 0, 32) internal = false load_balancer_type = "application" security_groups = [var.alb_security_group_id] subnets = var.public_subnet_ids }
resource "aws_lb_target_group" "app" { name = substr("${var.name}-tg", 0, 32) port = 8080 protocol = "HTTP" vpc_id = data.aws_subnet.app.vpc_id health_check { path = "/health" matcher = "200" } }
data "aws_subnet" "app" { id = var.private_subnet_id }
resource "aws_lb_target_group_attachment" "app" { target_group_arn = aws_lb_target_group.app.arn target_id = aws_instance.app.id port = 8080 }
resource "aws_lb_listener" "http" { load_balancer_arn = aws_lb.app.arn port = 80 protocol = "HTTP" default_action { type = "forward" target_group_arn = aws_lb_target_group.app.arn } }
output "alb_dns_name" { value = aws_lb.app.dns_name }
output "alb_arn_suffix" { value = aws_lb.app.arn_suffix }
output "target_group_arn_suffix" { value = aws_lb_target_group.app.arn_suffix }
output "ecr_repository_url" { value = aws_ecr_repository.app.repository_url }
