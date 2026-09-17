# Odoo ERP Intelligence Hub

A portfolio project that deploys Odoo Community Edition and extends it with a cited, read-only AI assistant. The local development stack includes Odoo, PostgreSQL, a custom `erp_ai_assistant` addon, and a FastAPI mock RAG service.

Open [the ai assistant dashboard](http://odoo-intelligence-dev-alb-1400469304.ap-southeast-1.elb.amazonaws.com/web#action=441&cids=1&menu_id=283) to start chatting

See [PRD.md](PRD.md) for the AWS target architecture and delivery scope.

## Local development

Requirements: Docker Engine with Docker Compose v2.

```bash
docker compose up --build
```

Open [http://localhost:8069](http://localhost:8069), select the local `odoo` database, then use the public demo account below. It is a deliberately restricted internal Odoo user with synthetic data only — it is **not** an Odoo administrator and must never be used outside a disposable demo environment.

| Login | Password |
| --- | --- |
| `admin@gmail.com` | `admin` |

The initial local Odoo administrator remains `admin` / `admin`; change it immediately if you use the stack for anything other than local development. The RAG service health endpoint is available at:

```bash
curl -s http://localhost:8000/health | jq
```

The Compose stack intentionally uses local-only credentials (`odoo` / `odoo`) and persistent Docker volumes. Never use those credentials outside local development.

Stop the local stack while keeping data:

```bash
docker compose down
```

Remove all local containers and database/filestore volumes:

```bash
docker compose down -v
```

## Tests

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r rag-service/requirements.txt pytest httpx
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 pytest
```

## Security and data policy

- Use Odoo Community Edition only; do not add Enterprise code or credentials.
- Use synthetic ERP records and documents only.
- The current RAG provider is deterministic/mock. Bedrock, S3/SQS ingestion, pgvector, ECS, EFS, and Terraform deployment are subsequent milestones.
- The assistant is advisory and read-only; verify cited sources before operational action.

## Disposable AWS demo deployment

> **Cost and security warning:** this creates billable ALB, Fargate, RDS, EFS, Secrets Manager, and CloudWatch resources. It is a temporary, synthetic-data portfolio demo and currently uses HTTP because no domain was supplied for ACM validation. Destroy it immediately after use.

Authenticate to AWS, then deploy:

```bash
aws login
# If your AWS CLI uses IAM Identity Center:
eval "$(aws configure export-credentials --format env)"
./scripts/deploy-aws-demo.sh
```

The script applies the ECS/RDS/EFS stack; the temporary task bootstraps the public GitHub source onto EFS. It prints the temporary ALB URL. Sign in using the demo account above; do not share the local Odoo administrator account.

Tear down all AWS resources after the demo:

```bash
./scripts/destroy-aws-demo.sh
```

See [docs/runbook.md](docs/runbook.md) for operational notes and [docs/architecture.md](docs/architecture.md) for the temporary architecture and its intentional limitations.
