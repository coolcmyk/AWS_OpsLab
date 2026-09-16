# Disposable AWS demo runbook

## Deploy

```bash
./scripts/deploy-aws-demo.sh
```

Terraform first creates ECR repositories, pushes the Odoo and RAG images, then deploys the ECS service. Obtain the URL with:

```bash
cd infra/environments/dev
terraform output -raw demo_url
```

Wait until the target group is healthy before testing. The public demo login is `admin@gmail.com` / `admin`; it is an intentionally restricted synthetic-data user.

## Tear down

Destroy immediately after the demo to stop ALB, Fargate, RDS, EFS, log, and ECR charges:

```bash
./scripts/destroy-aws-demo.sh
```

## Safety

The temporary endpoint is HTTP-only because no DNS domain was provided for ACM validation. It is for synthetic-data portfolio demonstrations only. Never use real data, real credentials, or the temporary endpoint for production work.
