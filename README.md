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
