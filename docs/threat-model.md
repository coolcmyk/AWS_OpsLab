# Threat Model

| Asset / threat | Mitigation | Residual risk |
| --- | --- | --- |
| RDS credentials exposed | Secret stored in Secrets Manager; roles receive only `GetSecretValue`; no source-control secrets | Terraform state/backend and operator access must remain protected |
| Public access to workloads or evidence | EC2/RDS private, security-group-only paths, S3 public-access blocks, no SSH ingress | ALB is publicly reachable; HTTPS must be added before broader exposure |
| Event spoofing or malformed payload | EventBridge source pattern, handler validation, idempotent finding ID | Custom event bus permissions must remain account-scoped |
| Sensitive log leakage | Structured/sanitized application logs; evidence reference rather than payload in API | Raw evidence is intentionally retained in S3 for 30 days |
| Over-privileged automation | Separate EC2, Lambda, and GitHub OIDC roles; narrowly scoped runtime policies | ECR auth requires the AWS API action on `*` |
| Unsafe AI suggestion | Advisory label and no automated remediation | Operator must validate suggestions |
| Cost exhaustion | Resource tags, budget alert workflow, explicit destroy script | User must set/monitor the budget alert |
