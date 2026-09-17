/** @odoo-module **/

import { Component, useState } from "@odoo/owl";
import { registry } from "@web/core/registry";
import { useService } from "@web/core/utils/hooks";

export class ErpAiChatAction extends Component {
    setup() {
        this.orm = useService("orm");
        this.notification = useService("notification");
        this.state = useState({ question: "", loading: false, messages: [] });
    }

    updateQuestion(event) {
        this.state.question = event.target.value;
    }

    onKeydown(event) {
        if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
            event.preventDefault();
            this.send();
        }
    }

    async send() {
        const question = this.state.question.trim();
        if (!question || this.state.loading) {
            return;
        }
        this.state.loading = true;
        this.state.question = "";
        this.state.messages.push({ role: "user", text: question });
        try {
            const [queryId] = await this.orm.create("erp.ai.query", [{ question }]);
            await this.orm.call("erp.ai.query", "action_ask_assistant", [[queryId]]);
            const [query] = await this.orm.read("erp.ai.query", [queryId], [
                "answer", "citation_json", "provider", "model", "latency_ms", "state",
            ]);
            this.state.messages.push({
                role: "assistant",
                text: query.answer || "Insufficient evidence was returned.",
                citations: this.parseCitations(query.citation_json),
                provider: query.provider || "unknown",
                model: query.model || "unknown",
                latency: query.latency_ms || 0,
            });
        } catch (error) {
            this.state.messages.push({
                role: "error",
                text: error.data?.message || error.message || "The assistant could not process this request.",
            });
            this.notification.add("The assistant request could not be completed.", { type: "danger" });
        } finally {
            this.state.loading = false;
        }
    }

    parseCitations(value) {
        try {
            return JSON.parse(value || "[]");
        } catch {
            return [];
        }
    }
}

ErpAiChatAction.template = "erp_ai_assistant.ChatAction";
registry.category("actions").add("erp_ai_assistant.chat", ErpAiChatAction);
