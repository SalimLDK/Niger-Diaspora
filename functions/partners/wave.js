/**
 * Wave Mobile Money Client
 *
 * Handles debit and credit operations with Wave API.
 * Currently in MOCK mode - will be replaced with real API calls.
 */

const { calculatePartnerFee } = require("./fees");

class WaveClient {
    constructor() {
        // Default to mock mode unless explicitly disabled — prevents accidental real debits
        // when the env var is unset (e.g. local dev / staging).
        this.mockMode = process.env.PARTNER_MOCK_MODE !== "false";
        this.apiUrl = process.env.WAVE_API_URL || "https://api.wave.com/v1";
        this.apiKey = process.env.WAVE_API_KEY || "";
        this.webhookSecret = process.env.WAVE_WEBHOOK_SECRET || "";
    }

    /**
     * Debit a Wave account (sender pays)
     *
     * @param {object} params
     * @param {string} params.phone - Phone number with country code
     * @param {number} params.amount - Amount in XOF
     * @param {string} params.currency - Currency code (XOF)
     * @param {string} params.reference - Internal transaction reference
     * @returns {Promise<object>} - Result with transactionId and status
     */
    async debit({ phone, amount, currency, reference }) {
        console.log(`WaveClient.debit: ${amount} ${currency} from ${phone}`);

        if (this.mockMode) {
            return await this._mockDebit({ phone, amount, currency, reference });
        }

        // TODO: Real Wave API implementation
        // Wave uses a different flow - typically QR code or USSD confirmation
        // const response = await fetch(`${this.apiUrl}/checkout`, {
        //     method: "POST",
        //     headers: {
        //         "Authorization": `Bearer ${this.apiKey}`,
        //         "Content-Type": "application/json",
        //     },
        //     body: JSON.stringify({
        //         amount,
        //         currency,
        //         client_reference: reference,
        //         success_url: callbackUrl,
        //         error_url: callbackUrl,
        //     }),
        // });
        // return await response.json();

        throw new Error("Wave API not configured. Set PARTNER_MOCK_MODE=true for testing.");
    }

    /**
     * Credit a Wave account (recipient receives)
     *
     * @param {object} params
     * @param {string} params.phone - Phone number with country code
     * @param {number} params.amount - Amount in XOF
     * @param {string} params.currency - Currency code (XOF)
     * @param {string} params.reference - Internal transaction reference
     * @returns {Promise<object>} - Result with transactionId and status
     */
    async credit({ phone, amount, currency, reference }) {
        console.log(`WaveClient.credit: ${amount} ${currency} to ${phone}`);

        if (this.mockMode) {
            return await this._mockCredit({ phone, amount, currency, reference });
        }

        // TODO: Real Wave API implementation (Wave Payout)
        throw new Error("Wave API not configured. Set PARTNER_MOCK_MODE=true for testing.");
    }

    /**
     * Verify webhook signature
     *
     * @param {string|object} payload - Request body
     * @param {string} signature - Signature from header
     * @returns {boolean} - True if valid
     */
    verifySignature(payload, signature) {
        if (this.mockMode) { return true; }
        // Security: HMAC signature verification for webhook authenticity
        if (!this.webhookSecret || !signature) {
            console.warn("Wave webhook: missing secret or signature — rejecting");
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
            console.error("Wave webhook signature comparison failed:", e.message);
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
        // Mock format - adjust based on real Wave webhook format
        return {
            type: body.type || (body.checkout_status ? "debit" : "credit"),
            transactionId: body.client_reference || body.reference,
            partnerTransactionId: body.wave_transaction_id || body.id,
            status: this._normalizeStatus(body.status || body.checkout_status),
            errorMessage: body.error_message || body.failure_reason,
            amount: body.amount,
            phone: body.mobile || body.phone,
        };
    }

    _normalizeStatus(waveStatus) {
        const statusMap = {
            "succeeded": "success",
            "completed": "success",
            "failed": "failed",
            "cancelled": "failed",
            "pending": "pending",
            "processing": "pending",
        };
        return statusMap[waveStatus?.toLowerCase()] || waveStatus;
    }

    // ===================== MOCK IMPLEMENTATIONS =====================

    async _mockDebit({ phone, amount, currency, reference }) {
        await this._simulateDelay(2000);

        // Simulate random failure (5% chance)
        if (Math.random() < 0.05) {
            return {
                success: false,
                transactionId: null,
                status: "failed",
                errorMessage: "Paiement refuse par l'utilisateur",
            };
        }

        const fee = calculatePartnerFee("wave", "debit", amount);

        return {
            success: true,
            transactionId: `WAVE_D_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            status: "pending", // Webhook will confirm
            fee,
            message: "[MOCK] Wave debit initiated successfully",
        };
    }

    async _mockCredit({ phone, amount, currency, reference }) {
        await this._simulateDelay(1800);

        // Simulate random failure (3% chance)
        if (Math.random() < 0.03) {
            return {
                success: false,
                transactionId: null,
                status: "failed",
                errorMessage: "Compte Wave non trouve",
            };
        }

        const fee = calculatePartnerFee("wave", "credit", amount);

        return {
            success: true,
            transactionId: `WAVE_C_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            status: "pending", // Webhook will confirm
            fee,
            amountCredited: amount - fee,
            message: "[MOCK] Wave credit initiated successfully",
        };
    }

    async _simulateDelay(ms = 1800) {
        await new Promise((resolve) => setTimeout(resolve, ms));
    }
}

// Singleton instance
let instance = null;

function getWaveClient() {
    if (!instance) {
        instance = new WaveClient();
    }
    return instance;
}

module.exports = {
    WaveClient,
    getWaveClient,
};
