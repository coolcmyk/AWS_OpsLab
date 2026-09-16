# Odoo ERP Intelligence Hub

A portfolio project that deploys Odoo Community Edition and extends it with a cited, read-only AI assistant. The local development stack includes Odoo, PostgreSQL, a custom `erp_ai_assistant` addon, and a FastAPI mock RAG service.

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

## AWS deployment

AWS infrastructure is being migrated from the previous lab to the Odoo ECS/RDS/EFS architecture in [PRD.md](PRD.md). Do not apply the legacy `infra/` configuration for this project.
