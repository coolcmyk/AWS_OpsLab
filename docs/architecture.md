# AWS demo architecture

The current deployment is a deliberately temporary, cost-conscious portfolio demo:

```text
Internet (HTTP only for temporary demo)
  -> ALB (two public subnets)
  -> ECS Fargate task (Odoo + internal FastAPI RAG container)
       -> EFS filestore
       -> private RDS PostgreSQL
       -> CloudWatch Logs
```

The task has a public egress address only to avoid an always-on NAT Gateway during the demo. Its security group accepts Odoo traffic only from the ALB; RDS and EFS accept traffic only from the task. The RAG container has no listener or public security-group rule and is reachable only at `localhost:8000` in the task.

This is not the final PRD architecture: the production-shaped iteration adds private task subnets, NAT/VPC endpoints, ACM HTTPS, S3/SQS/Lambda ingestion, pgvector, Bedrock, CloudTrail, alarms, and GitHub OIDC. Do not upload real data or treat the temporary HTTP deployment as production.
