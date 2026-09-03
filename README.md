### [Early Development Phase]

SecureAI Ops Lab is a small, AWS-hosted security-operations platform that receives cloud-security findings, stores their evidence and audit trail, and produces an AI-assisted incident-triage brief. It is a portfolio project designed to demonstrate practical AWS infrastructure, security, observability, Docker, CI/CD, and responsible AI integration.

The product deliberately uses a narrow, demoable workflow rather than attempting to be a full SIEM:

> A GuardDuty-style finding enters EventBridge → a Lambda validates and enriches it → the platform stores the incident and evidence → an operator views the incident, AI summary, and recommended next steps in a FastAPI dashboard/API.

Live GuardDuty findings are optional. Replayed findings must be visibly labelled **simulated** in both the UI and documentation.

## Goals

- Provision a repeatable AWS environment with Terraform.
- Demonstrate secure AWS networking, IAM least privilege, encrypted storage, and auditability.
- Run a Dockerized FastAPI service on a hardened EC2 instance behind an Application Load Balancer (ALB).
- Persist incidents and audit metadata in PostgreSQL on Amazon RDS.
- Route GuardDuty-style events through EventBridge to a Lambda-based AI enricher.
- Provide structured logs, a CloudWatch dashboard, alarms, smoke tests, and an incident runbook.
- Deploy via GitHub Actions using AWS OIDC, with no long-lived AWS credentials in GitHub.
- Keep a CLI bootstrap/verification path to demonstrate AWS operational fluency.

## Run locally

Requirements: Python 3.12+ and Docker (optional).

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r app/requirements.txt
cd app
uvicorn main:app --reload --port 8080
```

Verify the service:

```bash
curl http://localhost:8080/health
```

The local app uses SQLite by default and creates `app/secureai.db`. Run tests from the repository root with:

```bash
pip install pytest httpx
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 pytest app/tests lambda/tests
```

## Deploy the AWS lab

Requirements: AWS CLI v2 configured with a non-root identity, Terraform 1.7+, Docker, Python 3.12+, and `jq`.

> **Cost warning:** This stack can create billable RDS, ALB, NAT Gateway, CloudTrail, and related resources. Create a budget alert first and destroy the environment immediately after the demo.

```bash
aws configure sso
aws sts get-caller-identity
./scripts/bootstrap.sh
cp infra/environments/dev/terraform.tfvars.example infra/environments/dev/terraform.tfvars
# Edit infra/environments/dev/terraform.tfvars before continuing.
./scripts/package-lambda.sh
cd infra/environments/dev
terraform init
terraform plan
terraform apply
```

Terraform creates the ECR repository before the application image exists. Build and push the image, then recreate the EC2 app host:

```bash
REPO=$(terraform output -raw ecr_repository_url)
REGION=ap-southeast-1
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${REPO%/*}"
docker build -t secureai:latest ../../../app
docker tag secureai:latest "$REPO:latest"
docker push "$REPO:latest"
terraform apply -replace=module.compute.aws_instance.app
```

Run the health and simulated-event smoke test from the repository root:

```bash
cd ../../..
./scripts/smoke-test.sh
```

## Teardown

```bash
./scripts/destroy.sh
```

Confirm any manually enabled GuardDuty detector and budget alerts are also handled after teardown.
