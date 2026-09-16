import hashlib
import json
import os
from urllib import error, request

from odoo import fields, models
from odoo.exceptions import UserError


class ErpAiQuery(models.Model):
    _name = "erp.ai.query"
    _description = "ERP AI Assistant Query"
    _order = "create_date desc"

    question = fields.Text(required=True)
    answer = fields.Text(readonly=True)
    citation_json = fields.Text(readonly=True)
    state = fields.Selection(
        [("draft", "Draft"), ("complete", "Complete"), ("failed", "Failed")], default="draft", required=True
    )
    requester_id = fields.Many2one("res.users", required=True, default=lambda self: self.env.user, readonly=True)
    provider = fields.Char(readonly=True)
    model = fields.Char(readonly=True)
    latency_ms = fields.Integer(readonly=True)
    error_summary = fields.Char(readonly=True)

    def action_ask_assistant(self):
        self.ensure_one()
        if not self.question or not self.question.strip():
            raise UserError("Enter a question before asking the assistant.")

        payload = json.dumps({
            "question": self.question,
            "requester_id": str(self.requester_id.id),
            "allowed_document_ids": self.env["erp.ai.document"].search([("owner_id", "=", self.requester_id.id), ("state", "=", "indexed")]).ids,
            "question_hash": hashlib.sha256(self.question.encode()).hexdigest(),
        }).encode()
        url = os.getenv("RAG_SERVICE_URL", "http://rag-service:8000").rstrip("/") + "/v1/query"
        try:
            outbound = request.Request(url, data=payload, headers={"Content-Type": "application/json"}, method="POST")
            with request.urlopen(outbound, timeout=15) as response:
                result = json.loads(response.read().decode())
        except (error.URLError, TimeoutError, ValueError) as exc:
            self.write({"state": "failed", "error_summary": "Assistant service is unavailable."})
            raise UserError("Assistant service is unavailable. Please try again later.") from exc

        self.write({
            "answer": result["answer"],
            "citation_json": json.dumps(result.get("citations", [])),
            "provider": result.get("provider"),
            "model": result.get("model"),
            "latency_ms": result.get("latency_ms", 0),
            "state": "complete",
            "error_summary": False,
        })
        return True
