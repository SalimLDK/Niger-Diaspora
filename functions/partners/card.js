/**
 * Card Payment Client (Visa Direct / Mastercard Send)
 *
 * Mock implementation for push-to-card payments.
 * Replace with actual API calls when credentials are available.
 */

const MOCK_MODE = process.env.PARTNER_MOCK_MODE !== "false";

class CardPaymentClient {
    constructor(config = {}) {
        this.visaDirectUrl = config.visaDirectUrl || process.env.VISA_DIRECT_URL;
        this.visaDirectApiKey = config.visaDirectApiKey || process.env.VISA_DIRECT_API_KEY;
        this.mastercardSendUrl = config.mastercardSendUrl || process.env.MASTERCARD_SEND_URL;
        this.mastercardSendApiKey = config.mastercardSendApiKey || process.env.MASTERCARD_SEND_API_KEY;
    }

    /**
     * Credit a card (Visa Direct or Mastercard Send)
     *
     * @param {object} params - Credit parameters
     * @param {string} params.cardNumber - Card number (PAN)
     * @param {string} params.cardNetwork - 'visa' or 'mastercard'
     * @param {string} params.recipientName - Cardholder name
     * @param {number} params.amount - Amount in XOF
     * @param {string} params.currency - Currency code (default XOF)
     * @param {string} params.reference - Our transaction reference
     * @returns {Promise<object>} - Credit result
     */
    async credit({ cardNumber, cardNetwork, recipientName, amount, currency = "XOF", reference }) {
        if (MOCK_MODE) {
            await this._simulateDelay();

            // Simulate card validation
            if (!this._isValidCardNumber(cardNumber)) {
                return {
                    success: false,
                    error: "Invalid card number",
                    errorCode: "INVALID_CARD",
                };
            }

            // Simulate network-specific processing
            const prefix = cardNetwork === "visa" ? "VD" : "MC";
            return {
                success: true,
                transactionId: `${prefix}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
                status: "completed", // Push-to-card is typically instant
                amount,
                currency,
                recipientName,
                cardLast4: cardNumber.slice(-4),
                cardNetwork,
                reference,
                processedAt: new Date().toISOString(),
                fee: this._calculateFee(amount),
            };
        }

        // TODO: Implement actual Visa Direct / Mastercard Send API calls
        // Based on cardNetwork, route to appropriate API
        if (cardNetwork === "visa") {
            return this._processVisaDirect({ cardNumber, recipientName, amount, currency, reference });
        } else {
            return this._processMastercardSend({ cardNumber, recipientName, amount, currency, reference });
        }
    }

    /**
     * Check card eligibility for push-to-card
     *
     * @param {string} cardNumber - Card number to check
     * @returns {Promise<object>} - Eligibility result
     */
    async checkEligibility(cardNumber) {
        if (MOCK_MODE) {
            await this._simulateDelay(500);

            // Detect card network from BIN
            const cardNetwork = this._detectCardNetwork(cardNumber);
            if (!cardNetwork) {
                return {
                    eligible: false,
                    error: "Unsupported card network",
                };
            }

            return {
                eligible: true,
                cardNetwork,
                cardLast4: cardNumber.slice(-4),
                supportsInstantCredit: true,
            };
        }

        // TODO: Implement actual eligibility check via Visa/Mastercard APIs
        throw new Error("Card eligibility check not implemented");
    }

    /**
     * Get transaction status
     *
     * @param {string} transactionId - Our transaction ID
     * @returns {Promise<object>} - Transaction status
     */
    async getTransactionStatus(transactionId) {
        if (MOCK_MODE) {
            await this._simulateDelay(300);
            return {
                transactionId,
                status: "completed",
                completedAt: new Date().toISOString(),
            };
        }

        // TODO: Implement actual status check
        throw new Error("Transaction status check not implemented");
    }

    // ============ PRIVATE METHODS ============

    async _processVisaDirect({ cardNumber, recipientName, amount, currency, reference }) {
        // TODO: Implement Visa Direct API call
        // https://developer.visa.com/capabilities/visa_direct
        throw new Error("Visa Direct API not implemented");
    }

    async _processMastercardSend({ cardNumber, recipientName, amount, currency, reference }) {
        // TODO: Implement Mastercard Send API call
        // https://developer.mastercard.com/mastercard-send
        throw new Error("Mastercard Send API not implemented");
    }

    _detectCardNetwork(cardNumber) {
        const cleanNumber = cardNumber.replace(/\D/g, "");
        if (cleanNumber.startsWith("4")) {
            return "visa";
        }
        if (/^5[1-5]/.test(cleanNumber) || /^2[2-7]/.test(cleanNumber)) {
            return "mastercard";
        }
        return null;
    }

    _isValidCardNumber(cardNumber) {
        const cleanNumber = cardNumber.replace(/\D/g, "");
        if (cleanNumber.length < 13 || cleanNumber.length > 19) {
            return false;
        }

        // Luhn algorithm
        let sum = 0;
        let isEven = false;
        for (let i = cleanNumber.length - 1; i >= 0; i--) {
            let digit = parseInt(cleanNumber.charAt(i), 10);
            if (isEven) {
                digit *= 2;
                if (digit > 9) {
                    digit -= 9;
                }
            }
            sum += digit;
            isEven = !isEven;
        }
        return sum % 10 === 0;
    }

    _calculateFee(amount) {
        // 2% fee, min 500 XOF, max 10000 XOF
        let fee = amount * 0.02;
        fee = Math.max(fee, 500);
        fee = Math.min(fee, 10000);
        return Math.round(fee);
    }

    async _simulateDelay(ms = 1500) {
        await new Promise((resolve) => setTimeout(resolve, ms));
    }
}

// Singleton instance
let cardPaymentClientInstance = null;

function getCardPaymentClient() {
    if (!cardPaymentClientInstance) {
        cardPaymentClientInstance = new CardPaymentClient();
    }
    return cardPaymentClientInstance;
}

module.exports = {
    CardPaymentClient,
    getCardPaymentClient,
};
