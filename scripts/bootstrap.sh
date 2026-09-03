#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:=ap-southeast-1}"
command -v aws >/dev/null || { echo "AWS CLI v2 is required"; exit 1; }
command -v terraform >/dev/null || { echo "Terraform is required"; exit 1; }
aws sts get-caller-identity

echo "Review the AWS Budget console before provisioning. Budget creation is account-specific and intentionally not automated with broad IAM permissions."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.${AWS_REGION}.amazonaws.com" || true

echo "Next: cp infra/environments/dev/terraform.tfvars.example infra/environments/dev/terraform.tfvars"
