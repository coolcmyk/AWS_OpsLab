variable "name" { type = string }
variable "alert_email" { type = string }
variable "lambda_function_name" { type = string }
variable "alb_arn_suffix" { type = string }
variable "target_group_arn_suffix" { type = string }

resource "aws_cloudwatch_metric_alarm" "lambda_errors" { alarm_name = "${var.name}-lambda-errors" namespace = "AWS/Lambda" metric_name = "Errors" statistic = "Sum" period = 300 evaluation_periods = 1 threshold = 1 comparison_operator = "GreaterThanOrEqualToThreshold" dimensions = { FunctionName = var.lambda_function_name } treat_missing_data = "notBreaching" }
resource "aws_cloudwatch_metric_alarm" "alb_5xx" { alarm_name = "${var.name}-alb-5xx" namespace = "AWS/ApplicationELB" metric_name = "HTTPCode_Target_5XX_Count" statistic = "Sum" period = 300 evaluation_periods = 1 threshold = 5 comparison_operator = "GreaterThanOrEqualToThreshold" dimensions = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix } treat_missing_data = "notBreaching" }
resource "aws_cloudwatch_dashboard" "this" { dashboard_name = "${var.name}-ops" dashboard_body = jsonencode({ widgets = [{ type = "metric", properties = { title = "Lambda errors", region = data.aws_region.current.name, metrics = [["AWS/Lambda", "Errors", "FunctionName", var.lambda_function_name]], period = 300, stat = "Sum" } }, { type = "metric", properties = { title = "ALB target 5xx", region = data.aws_region.current.name, metrics = [["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix]], period = 300, stat = "Sum" } }] }) }
data "aws_region" "current" {}
