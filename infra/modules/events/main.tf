variable "name" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "lambda_security_group_id" { type = string }
variable "evidence_bucket_name" { type = string }
variable "database_url_secret_arn" { type = string }

data "archive_file" "lambda" { type = "zip" source_dir = "${path.module}/../../../lambda/.build" output_path = "${path.module}/lambda.zip" excludes = ["tests", "requirements.txt", "__pycache__"] }
resource "aws_cloudwatch_event_bus" "this" { name = "${var.name}-bus" }
resource "aws_sqs_queue" "dlq" { name = "${var.name}-enrichment-dlq" message_retention_seconds = 1209600 }
data "aws_iam_policy_document" "dlq" { statement { principals { type = "Service" identifiers = ["events.amazonaws.com", "lambda.amazonaws.com"] } actions = ["sqs:SendMessage"] resources = [aws_sqs_queue.dlq.arn] } }
resource "aws_sqs_queue_policy" "dlq" { queue_url = aws_sqs_queue.dlq.id policy = data.aws_iam_policy_document.dlq.json }
data "aws_iam_policy_document" "assume" { statement { actions = ["sts:AssumeRole"] principals { type = "Service" identifiers = ["lambda.amazonaws.com"] } } }
resource "aws_iam_role" "lambda" { name = "${var.name}-enricher" assume_role_policy = data.aws_iam_policy_document.assume.json }
resource "aws_iam_role_policy_attachment" "logs" { role = aws_iam_role.lambda.name policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" }
resource "aws_iam_role_policy_attachment" "vpc" { role = aws_iam_role.lambda.name policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole" }
data "aws_iam_policy_document" "lambda" { statement { actions = ["s3:PutObject"] resources = ["arn:aws:s3:::${var.evidence_bucket_name}/findings/*"] } statement { actions = ["secretsmanager:GetSecretValue"] resources = [var.database_url_secret_arn] } }
resource "aws_iam_role_policy" "lambda" { name = "${var.name}-enricher-runtime" role = aws_iam_role.lambda.id policy = data.aws_iam_policy_document.lambda.json }
resource "aws_lambda_function" "this" { function_name = "${var.name}-enricher" role = aws_iam_role.lambda.arn handler = "handler.handler" runtime = "python3.12" timeout = 30 filename = data.archive_file.lambda.output_path source_code_hash = data.archive_file.lambda.output_base64sha256 vpc_config { subnet_ids = var.private_subnet_ids security_group_ids = [var.lambda_security_group_id] } environment { variables = { EVIDENCE_BUCKET = var.evidence_bucket_name DB_SECRET_ARN = var.database_url_secret_arn } } dead_letter_config { target_arn = aws_sqs_queue.dlq.arn } }
resource "aws_cloudwatch_event_rule" "finding" { name = "${var.name}-finding" event_bus_name = aws_cloudwatch_event_bus.this.name event_pattern = jsonencode({ source = ["aws.guardduty", "secureai.demo"] }) }
resource "aws_cloudwatch_event_target" "lambda" { rule = aws_cloudwatch_event_rule.finding.name event_bus_name = aws_cloudwatch_event_bus.this.name arn = aws_lambda_function.this.arn dead_letter_config { arn = aws_sqs_queue.dlq.arn } retry_policy { maximum_event_age_in_seconds = 3600 maximum_retry_attempts = 2 } }
resource "aws_lambda_permission" "events" { statement_id = "AllowEventBridgeInvoke" action = "lambda:InvokeFunction" function_name = aws_lambda_function.this.function_name principal = "events.amazonaws.com" source_arn = aws_cloudwatch_event_rule.finding.arn }
output "function_name" { value = aws_lambda_function.this.function_name }
output "event_bus_name" { value = aws_cloudwatch_event_bus.this.name }
