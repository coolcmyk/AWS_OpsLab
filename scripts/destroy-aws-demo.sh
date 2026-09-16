#!/usr/bin/env bash
# Permanently deletes the disposable AWS demo and all associated Terraform-managed resources.
set -euo pipefail

cd "$(dirname "$0")/../infra/environments/dev"
terraform destroy -auto-approve -var='deploy_service=false'
