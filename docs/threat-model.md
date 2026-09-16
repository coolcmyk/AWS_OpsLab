# Threat model — temporary AWS demo

| Threat | Mitigation | Residual risk |
| --- | --- | --- |
| Public demo credentials abused | Synthetic-only restricted Odoo user; administrator password is generated and held in Secrets Manager | HTTP transport means credentials can be observed on untrusted networks |
| Direct task access | Task security group accepts Odoo only from ALB | Task has public egress for cost reasons |
| Database exposure | RDS has no public IP and allows port 5432 only from task security group | Single-AZ demo instance |
| Filestore loss | Encrypted EFS mount | No backup/restore workflow in temporary stack |
| RAG public exposure | RAG container has no public listener and is localhost-only | Mock provider only |

The final PRD deployment must use ACM HTTPS, private task networking, approved attachment ingestion, and the full data controls before any non-synthetic use.
