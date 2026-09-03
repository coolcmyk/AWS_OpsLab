#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT/infra/environments/dev"
URL=$(terraform output -raw application_url)
BUS=$(terraform output -raw event_bus_name)
REGION=$(aws configure get region || true)
REGION=${REGION:-ap-southeast-1}

curl --fail --silent --show-error "$URL/health" | jq .
aws events put-events --region "$REGION" --entries "$(jq -cn --arg bus "$BUS" --arg detail "$(jq -c . "$ROOT/examples/simulated-guardduty-event.json" | jq -c .detail)" '[{Source:"secureai.demo",DetailType:"GuardDuty Finding (Simulated)",EventBusName:$bus,Detail:$detail}]')"
echo "Submitted simulated event. Check CloudWatch and /api/incidents after Lambda processing."
