# Runbook

## Triage a finding

1. Confirm whether `is_simulated` is true. Sample events are not real incidents.
2. Look up the incident with `GET /api/incidents/{id}` and record the evidence S3 URI.
3. Inspect Lambda logs in `/aws/lambda/<function-name>` and the CloudWatch dashboard.
4. Review CloudTrail around the finding timestamp and validate the AI brief against source evidence.
5. Apply remediation manually through approved change control; the lab never auto-remediates.

## Failed enrichment

- Check Lambda `Errors`, duration, VPC/NAT connectivity, and Secrets Manager access.
- The original event remains in the evidence bucket if upload succeeded.
- Inspect the EventBridge target retry status and SQS DLQ. Fix the issue, then replay the clearly labelled simulated event.

## Rollback and teardown

- Roll back the app by retagging/redeploying a known ECR image and replacing the EC2 instance.
- Run `scripts/destroy.sh` after the demo. Confirm ALB, NAT Gateway, RDS, EIP, CloudTrail, GuardDuty, and budget resources are no longer billed as intended.
