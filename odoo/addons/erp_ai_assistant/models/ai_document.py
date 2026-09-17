import base64

from odoo import api, fields, models


class ErpAiDocument(models.Model):
    _name = "erp.ai.document"
    _description = "ERP AI Approved Document"
    _inherit = ["mail.thread", "mail.activity.mixin"]
    _order = "create_date desc"

    name = fields.Char(required=True, tracking=True)
    attachment_id = fields.Many2one("ir.attachment", required=True, ondelete="cascade", tracking=True)
    owner_id = fields.Many2one("res.users", required=True, default=lambda self: self.env.user, readonly=True)
    state = fields.Selection(
        [("pending", "Pending"), ("processing", "Processing"), ("indexed", "Indexed"), ("failed", "Failed")],
        default="pending",
        required=True,
        tracking=True,
    )
    source_checksum = fields.Char(readonly=True)
    source_excerpt = fields.Text(readonly=True)
    error_summary = fields.Char(readonly=True)
    indexed_at = fields.Datetime(readonly=True)

    @api.model_create_multi
    def create(self, values_list):
        records = super().create(values_list)
        for record in records:
            record.source_checksum = record.attachment_id.checksum
        return records

    def _text_excerpt(self):
        self.ensure_one()
        if self.attachment_id.mimetype not in ("text/plain", "text/csv"):
            return False
        try:
            raw = base64.b64decode(self.attachment_id.datas or b"")
            return raw.decode("utf-8", errors="replace")[:4000]
        except (ValueError, TypeError):
            return False

    def action_mark_for_ingestion(self):
        """Local demo indexing; production uses the S3/SQS/Lambda workflow."""
        for record in self:
            excerpt = record._text_excerpt()
            if excerpt:
                record.write({"state": "indexed", "source_excerpt": excerpt, "error_summary": False})
            else:
                record.write({
                    "state": "failed",
                    "source_excerpt": False,
                    "error_summary": "The local demo accepts UTF-8 TXT or CSV attachments only.",
                })
        return True
