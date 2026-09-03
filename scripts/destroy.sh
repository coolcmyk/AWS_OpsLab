#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
read -r -p "Destroy SecureAI Ops Lab dev resources? Type DESTROY to continue: " confirmation
[[ "$confirmation" == "DESTROY" ]] || { echo "Cancelled"; exit 1; }
cd "$ROOT/infra/environments/dev"
terraform destroy

echo "Verify AWS Budgets, GuardDuty (if enabled), and any manually created resources are disabled/deleted."
