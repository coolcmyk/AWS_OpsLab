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
    error_summary = fields.Char(readonly=True)
    indexed_at = fields.Datetime(readonly=True)

    @api.model_create_multi
    def create(self, values_list):
        records = super().create(values_list)
        for record in records:
            record.source_checksum = record.attachment_id.checksum
        return records

    def action_mark_for_ingestion(self):
        """The AWS S3/SQS handoff is added by the ingestion integration milestone."""
        self.write({"state": "pending", "error_summary": False})
        return True
