"""EventBridge finding enricher. AI output is advisory and never remediates resources."""
import json
import os
import uuid
from datetime import datetime, timezone

import boto3


def _finding(event: dict) -> dict:
    detail = event.get("detail", event)
    finding_id = detail.get("id") or detail.get("finding_id")
    if not finding_id:
        raise ValueError("finding id is required")
    severity = str(detail.get("severity", "medium")).lower()
    if severity not in {"low", "medium", "high", "critical"}:
        severity = "medium"
    return {
        "id": finding_id,
        "title": detail.get("title") or detail.get("type") or "Security finding",
        "description": detail.get("description") or "No description supplied.",
        "severity": severity,
        "is_simulated": bool(detail.get("is_simulated", event.get("source") != "aws.guardduty")),
    }


def _database_url() -> str:
    secret = boto3.client("secretsmanager").get_secret_value(SecretId=os.environ["DB_SECRET_ARN"])
    value = json.loads(secret["SecretString"])
    # The provisioner stores a complete URL; this avoids credentials in Lambda config.
    return value["url"]


def _brief(finding: dict) -> str:
    # Swap this deterministic MVP provider for Bedrock behind the same interface.
    return (
        f"AI-generated advisory: {finding['severity'].upper()} finding. Impact: investigate affected resource and identity scope. "
        "Recommended investigation: review CloudTrail activity and associated IAM permissions. "
        "Suggested remediation: validate exposure, apply least privilege, and document the outcome."
    )


def handler(event, _context):
    finding = _finding(event)
    incident_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()
    bucket = os.environ["EVIDENCE_BUCKET"]
    key = f"findings/{now[:10]}/{finding['id']}.json"
    raw = json.dumps(event, default=str).encode()
    boto3.client("s3").put_object(Bucket=bucket, Key=key, Body=raw, ServerSideEncryption="aws:kms", ContentType="application/json")
    evidence_uri = f"s3://{bucket}/{key}"

    enrichment_status, ai_brief = "complete", _brief(finding)
    try:
        # Imported here so schema-validation/unit tests do not need the native DB client.
        import psycopg
        with psycopg.connect(_database_url()) as conn, conn.cursor() as cur:
            cur.execute(
                '''INSERT INTO incidents (id, source_finding_id, title, description, severity, status, is_simulated, evidence_s3_uri, ai_brief, enrichment_status, created_at, updated_at)
                   VALUES (%s, %s, %s, %s, %s, 'enriched', %s, %s, %s, %s, NOW(), NOW())
                   ON CONFLICT (source_finding_id) DO UPDATE SET updated_at = NOW(), ai_brief = EXCLUDED.ai_brief, enrichment_status = EXCLUDED.enrichment_status''',
                (incident_id, finding["id"], finding["title"], finding["description"], finding["severity"], finding["is_simulated"], evidence_uri, ai_brief, enrichment_status),
            )
            cur.execute("INSERT INTO audit_events (id, incident_id, action, actor_type, metadata_json, created_at) VALUES (%s, %s, %s, %s, %s, NOW())", (str(uuid.uuid4()), incident_id, "finding_enriched", "lambda", json.dumps({"is_simulated": finding["is_simulated"]})))
            conn.commit()
    except Exception:
        # Evidence remains in S3. Raising makes EventBridge retry/DLQ visible.
        print(json.dumps({"event": "enrichment_failed", "finding_id": finding["id"]}))
        raise

    print(json.dumps({"event": "finding_enriched", "incident_id": incident_id, "finding_id": finding["id"], "is_simulated": finding["is_simulated"]}))
    return {"incident_id": incident_id, "evidence_s3_uri": evidence_uri, "enrichment_status": enrichment_status}
