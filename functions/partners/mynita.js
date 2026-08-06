/**
 * Mynita Mobile Money Client
 *
 * Handles debit and credit operations with Mynita API.
 * Currently in MOCK mode - will be replaced with real API calls.
 */

const { calculatePartnerFee } = require("./fees");

class MynitaClient {
    constructor() {
        // Default to mock mode unless explicitly disabled — prevents accidental real debits
        // when the env var is unset (e.g. local dev / staging).
        this.mockMode = process.env.PARTNER_MOCK_MODE !== "false";
        this.apiUrl = process.env.MYNITA_API_URL || "https://api.mynita.com/v1";
        this.apiKey = process.env.MYNITA_API_KEY || "";
        this.webhookSecret = process.env.MYNITA_WEBHOOK_SECRET || "";
    }

    /**
     * Debit a Mynita account (sender pays)
     *
     * @param {object} params
     * @param {string} params.phone - Phone number with country code
     * @param {number} params.amount - Amount in XOF
     * @param {string} params.currency - Currency code (XOF)
     * @param {string} params.reference - Internal transaction reference
     * @returns {Promise<object>} - Result with transactionId and status
     */
    async debit({ phone, amount, currency, reference }) {
        console.log(`MynitaClient.debit: ${amount} ${currency} from ${phone}`);

        if (this.mockMode) {
            return await this._mockDebit({ phone, amount, currency, reference });
        }

        // TODO: Real API implementation
        // const response = await fetch(`${this.apiUrl}/debit`, {
        //     method: "POST",
        //     headers: {
        //         "Authorization": `Bearer ${this.apiKey}`,
        //         "Content-Type": "application/json",
        //     },
        //     body: JSON.stringify({
        //         phone,
        //         amount,
        //         currency,
        //         reference,
        //         callbackUrl: `https://${process.env.GCLOUD_PROJECT}.cloudfunctions.net/mynitaWebhook`,
        //     }),
        // });
        // return await response.json();

        throw new Error("Mynita API not configured. Set PARTNER_MOCK_MODE=true for testing.");
    }

    /**
     * Credit a Mynita account (recipient receives)
     *
     * @param {object} params
     * @param {string} params.phone - Phone number with country code
     * @param {number} params.amount - Amount in XOF
     * @param {string} params.currency - Currency code (XOF)
     * @param {string} params.reference - Internal transaction reference
     * @returns {Promise<object>} - Result with transactionId and status
     */
    async credit({ phone, amount, currency, reference }) {
        console.log(`MynitaClient.credit: ${amount} ${currency} to ${phone}`);

        if (this.mockMode) {
            return await this._mockCredit({ phone, amount, currency, reference });
        }

        // TODO: Real API implementation
        throw new Error("Mynita API not configured. Set PARTNER_MOCK_MODE=true for testing.");
    }

    /**
     * Verify webhook signature
     *
     * @param {string|object} payload - Request body
     * @param {string} signature - Signature from header
     * @returns {boolean} - True if valid
     */
    verifySignature(payload, signature) {
        // Le mode simule ne doit PAS court-circuiter cette verification —
        // meme raison que dans `wave.js` : `mockMode` est actif par defaut en
        // production (`PARTNER_MOCK_MODE` absent), donc `mynitaWebhook`
        // acceptait n'importe quelle requete forgee et laissait confirmer un
        // debit qui n'avait jamais eu lieu.
        //
        // Simuler concerne les appels SORTANTS. L'authentification d'un
        // endpoint ENTRANT n'en depend pas.

        // Security: HMAC signature verification for webhook authenticity
        if (!this.webhookSecret || !signature) {
            console.warn("Mynita webhook: missing secret or signature — rejecting");
            return false;
        }
        const crypto = require("crypto");
        const expectedSignature = crypto
            .createHmac("sha256", this.webhookSecret)
            .update(typeof payload === "string" ? payload : JSON.stringify(payload))
            .digest("hex");
        try {
            return crypto.timingSafeEqual(
                Buffer.from(signature, "hex"),
                Buffer.from(expectedSignature, "hex")
            );
        } catch (e) {
            console.error("Mynita webhook signature comparison failed:", e.message);
            return false;
        }
    }

    /**
     * Parse webhook event
     *
     * @param {object} body - Webhook request body
     * @returns {object} - Parsed event with type, transactionId, status
     */
    parseWebhookEvent(body) {
        // Mock format - adjust based on real Mynita webhook format
        return {
            type: body.type || body.event?.type,           // 'debit' or 'credit'
            transactionId: body.reference || body.transactionId,
            partnerTransactionId: body.mynitaTransactionId || body.id,
            status: body.status,                           // 'success', 'failed', 'pending'
            errorMessage: body.errorMessage || body.error,
            amount: body.amount,
            phone: body.phone,
        };
    }

    // ===================== MOCK IMPLEMENTATIONS =====================

    async _mockDebit({ phone, amount, currency, reference }) {
        await this._simulateDelay(1500);

        // Simulate random failure (5% chance)
        if (Math.random() < 0.05) {
            return {
                success: false,
                transactionId: null,
                status: "failed",
                errorMessage: "Solde insuffisant",
            };
        }

        const fee = calculatePartnerFee("mynita", "debit", amount);

        return {
            success: true,
            transactionId: `MYN_D_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            status: "pending", // Webhook will confirm
            fee,
            message: "[MOCK] Debit initiated successfully",
        };
    }

    async _mockCredit({ phone, amount, currency, reference }) {
        await this._simulateDelay(2000);

        // Simulate random failure (3% chance)
        if (Math.random() < 0.03) {
            return {
                success: false,
                transactionId: null,
                status: "failed",
                errorMessage: "Numero invalide",
            };
        }

        const fee = calculatePartnerFee("mynita", "credit", amount);

        return {
            success: true,
            transactionId: `MYN_C_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            status: "pending", // Webhook will confirm
            fee,
            amountCredited: amount - fee,
            message: "[MOCK] Credit initiated successfully",
        };
    }

    async _simulateDelay(ms = 1500) {
        await new Promise((resolve) => setTimeout(resolve, ms));
    }
}

// Singleton instance
let instance = null;

function getMynitaClient() {
    if (!instance) {
        instance = new MynitaClient();
    }
    return instance;
}

module.exports = {
    MynitaClient,
    getMynitaClient,
};
