{
    "name": "ERP AI Assistant",
    "summary": "Cited, read-only AI assistance for approved ERP documents",
    "version": "17.0.1.0.0",
    "category": "Productivity",
    "license": "LGPL-3",
    "author": "Portfolio Project",
    "depends": ["base", "mail", "purchase", "sale_stock", "stock"],
    "data": [
        "security/ir.model.access.csv",
        "security/erp_ai_security.xml",
        "views/erp_ai_assistant_views.xml",
    ],
    "application": True,
    "installable": True,
    "post_init_hook": "post_init_hook",
}
