"""Development-only demo user provisioning.

The public demo login is deliberately a standard internal user, not an Odoo
administrator. It is created only when ODOO_DEMO_EMAIL is explicitly supplied.
"""
import os

from odoo import Command, SUPERUSER_ID
from odoo.api import Environment


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
    existing = users.search([("login", "=", email)], limit=1)
    if existing:
        return

    internal_user_group = superuser_env.ref("base.group_user")
    users.create({
        "name": "ERP Intelligence Demo User",
        "login": email,
        "email": email,
        "password": password,
        "groups_id": [Command.set([internal_user_group.id])],
    })
