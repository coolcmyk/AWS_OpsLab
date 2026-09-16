#!/usr/bin/env bash
# Deploys a disposable, HTTP-only portfolio demo. This intentionally uses no NAT
# gateway to limit cost; destroy it immediately after demonstration.
set -euo pipefail

command -v aws >/dev/null || { echo "AWS CLI is required." >&2; exit 1; }
command -v terraform >/dev/null || { echo "Terraform is required." >&2; exit 1; }
aws sts get-caller-identity --no-cli-pager >/dev/null

cd infra/environments/dev
terraform init
terraform apply -auto-approve -var='deploy_service=true'
terraform output demo_url

echo "Demo deployment initiated. Wait for the ECS task to become healthy before sharing the URL."
