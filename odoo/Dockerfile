FROM odoo:17.0

USER root
COPY addons/erp_ai_assistant /mnt/extra-addons/erp_ai_assistant
RUN chown -R odoo:odoo /mnt/extra-addons/erp_ai_assistant
USER odoo
