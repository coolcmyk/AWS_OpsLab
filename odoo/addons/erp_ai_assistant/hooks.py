"""Development-only demo user provisioning.

The public demo login is deliberately a standard internal user, not an Odoo
administrator. It is created only when ODOO_DEMO_EMAIL is explicitly supplied.
"""
import base64
import os

from odoo import Command, SUPERUSER_ID
from odoo.api import Environment
from odoo.modules.module import get_module_resource


def post_init_hook(env):
    email = os.getenv("ODOO_DEMO_EMAIL")
    password = os.getenv("ODOO_DEMO_PASSWORD")
    superadmin_password = os.getenv("ODOO_SUPERADMIN_PASSWORD")
    if not email or not password:
        return

    superuser_env = Environment(env.cr, SUPERUSER_ID, {})
    if superadmin_password:
        superuser_env["res.users"].browse(SUPERUSER_ID).with_context(no_reset_password=True).write({
            "password": superadmin_password,
        })

    users = superuser_env["res.users"].with_context(no_reset_password=True)
    demo_user = users.search([("login", "=", email)], limit=1)
    if not demo_user:
        internal_user_group = superuser_env.ref("base.group_user")
        demo_user = users.create({
            "name": "ERP Intelligence Demo User",
            "login": email,
            "email": email,
            "password": password,
            "groups_id": [Command.set([internal_user_group.id])],
        })

    documents = superuser_env["erp.ai.document"]
    if documents.search_count([("name", "=", "Synthetic supplier payment terms")]):
        return

    path = get_module_resource("erp_ai_assistant", "data", "synthetic_supplier_terms.csv")
    with open(path, "rb") as demo_file:
        contents = demo_file.read()
    attachment = superuser_env["ir.attachment"].create({
        "name": "synthetic_supplier_terms.csv",
        "datas": base64.b64encode(contents),
        "mimetype": "text/csv",
        "type": "binary",
    })
    documents.create({
        "name": "Synthetic supplier payment terms",
        "attachment_id": attachment.id,
        "owner_id": demo_user.id,
        "state": "indexed",
        "source_excerpt": contents.decode("utf-8"),
    })
