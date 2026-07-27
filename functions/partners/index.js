/**
 * Payment Partners Module
 *
 * Centralized exports for all payment partner clients.
 * Provides factory methods for getting the appropriate client.
 */

const { MynitaClient, getMynitaClient } = require("./mynita");
const { WaveClient, getWaveClient } = require("./wave");
const { CardPaymentClient, getCardPaymentClient } = require("./card");
const { PARTNER_FEES, calculatePartnerFee, calculateTotalFees } = require("./fees");

/**
 * Get the appropriate debit client based on provider
 *
 * @param {string} provider - Provider name ('mynita', 'wave')
 * @returns {MynitaClient|WaveClient} - Client instance
 * @throws {Error} - If provider is not supported
 */
function getDebitClient(provider) {
    switch (provider?.toLowerCase()) {
        case "mynita":
            return getMynitaClient();
        case "wave":
            return getWaveClient();
        default:
            throw new Error(`Unsupported debit provider: ${provider}`);
    }
}

/**
 * Stub client for recipient types we have not integrated yet (BUG-21, BIZ-06).
 *
 * Returns a not_implemented response so the calling code can mark the
 * transaction as failed and the UI can show a "Bientot disponible" message,
 * instead of throwing an unhandled error.
 */
function _notImplementedClient(label) {
    return {
        async credit() {
            return {
                success: false,
                status: "not_implemented",
                errorMessage: `${label}: ce service sera bientot disponible`,
            };
        },
        async debit() {
            return {
                success: false,
                status: "not_implemented",
                errorMessage: `${label}: ce service sera bientot disponible`,
            };
        },
    };
}

/**
 * Get the appropriate credit client based on recipient type
 *
 * @param {string} recipientType - Recipient type ('mynita', 'wave', 'card', 'bankAccount', 'cashPickup')
 * @returns {object} - Client instance (real or stub)
 * @throws {Error} - If recipient type is not supported
 */
function getCreditClient(recipientType) {
    switch (recipientType?.toLowerCase()) {
        case "mynita":
            return getMynitaClient();
        case "wave":
            return getWaveClient();
        case "card":
            return getCardPaymentClient();
        case "bankaccount":
            return _notImplementedClient("Virement bancaire");
        case "cashpickup":
            return _notImplementedClient("Retrait especes");
        default:
            throw new Error(`Unsupported credit recipient type: ${recipientType}`);
    }
}

/**
 * Check if a provider supports debit operations
 *
 * @param {string} provider - Provider name
 * @returns {boolean}
 */
function supportsDebit(provider) {
    return ["mynita", "wave"].includes(provider?.toLowerCase());
}

/**
 * Check if a recipient type supports credit operations.
 *
 * Note: bankAccount and cashPickup are routed through stub clients that
 * return `not_implemented`, so they are *recognized* but not yet *available*.
 * Use `isCreditTypeAvailable()` to check actual availability.
 *
 * @param {string} recipientType - Recipient type
 * @returns {boolean}
 */
function supportsCredit(recipientType) {
    return ["mynita", "wave", "card", "bankaccount", "cashpickup"].includes(
        recipientType?.toLowerCase()
    );
}

/**
 * Check if the credit recipient type has a fully implemented integration.
 */
function isCreditTypeAvailable(recipientType) {
    return ["mynita", "wave"].includes(recipientType?.toLowerCase());
}

/**
 * Get list of supported debit providers
 *
 * @returns {string[]}
 */
function getSupportedDebitProviders() {
    return ["mynita", "wave"];
}

/**
 * Get list of supported credit recipient types (including stubs).
 *
 * @returns {string[]}
 */
function getSupportedCreditTypes() {
    return ["mynita", "wave", "card", "bankAccount", "cashPickup"];
}

module.exports = {
    // Clients
    MynitaClient,
    WaveClient,
    CardPaymentClient,

    // Singleton getters
    getMynitaClient,
    getWaveClient,
    getCardPaymentClient,

    // Factory methods
    getDebitClient,
    getCreditClient,

    // Helpers
    supportsDebit,
    supportsCredit,
    isCreditTypeAvailable,
    getSupportedDebitProviders,
    getSupportedCreditTypes,

    // Fees
    PARTNER_FEES,
    calculatePartnerFee,
    calculateTotalFees,
};
