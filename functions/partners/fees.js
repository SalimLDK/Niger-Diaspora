/**
 * Partner Fees Configuration
 *
 * Defines the fee structure for each payment partner.
 * These values should be adjusted based on actual contracts with partners.
 */

const PARTNER_FEES = {
    mynita: {
        debit: {
            percent: 0.01,      // 1% for debiting sender
            min: 100,           // Minimum 100 XOF
            max: 5000,          // Maximum 5000 XOF
        },
        credit: {
            percent: 0.005,     // 0.5% for crediting recipient
            min: 50,            // Minimum 50 XOF
            max: 2500,          // Maximum 2500 XOF
        },
    },
    wave: {
        debit: {
            percent: 0.015,     // 1.5% for debiting sender
            min: 150,           // Minimum 150 XOF
            max: 7500,          // Maximum 7500 XOF
        },
        credit: {
            percent: 0.005,     // 0.5% for crediting recipient
            min: 50,            // Minimum 50 XOF
            max: 2500,          // Maximum 2500 XOF
        },
    },
    card: {
        credit: {
            percent: 0.02,      // 2% for Visa Direct / Mastercard Send
            min: 500,           // Minimum 500 XOF
            max: 10000,         // Maximum 10000 XOF
        },
    },
};

/**
 * Calculate partner fee for a given operation
 *
 * @param {string} provider - Partner name ('mynita', 'wave', 'card')
 * @param {string} type - Operation type ('debit' or 'credit')
 * @param {number} amountXof - Amount in XOF
 * @returns {number} - Fee in XOF (rounded)
 */
function calculatePartnerFee(provider, type, amountXof) {
    const config = PARTNER_FEES[provider]?.[type];
    if (!config) return 0;

    // Fixed fee
    if (config.fixed !== undefined) {
        return config.fixed;
    }

    // Percentage-based fee with min/max
    let fee = amountXof * config.percent;
    fee = Math.max(fee, config.min || 0);
    fee = Math.min(fee, config.max || Infinity);
    return Math.round(fee);
}

/**
 * Get total fees for a transfer
 *
 * @param {string} debitProvider - Provider for debit ('stripe', 'mynita', 'wave')
 * @param {string} creditProvider - Provider for credit ('mynita', 'wave', 'card')
 * @param {number} amountXof - Amount in XOF
 * @param {number} platformFeeXof - Platform fee in XOF
 * @returns {object} - Breakdown of all fees
 */
function calculateTotalFees(debitProvider, creditProvider, amountXof, platformFeeXof = 0) {
    const debitFee = calculatePartnerFee(debitProvider, "debit", amountXof);
    const creditFee = calculatePartnerFee(creditProvider, "credit", amountXof);

    return {
        platformFee: platformFeeXof,
        debitFee,
        creditFee,
        totalFees: platformFeeXof + debitFee + creditFee,
        amountAfterFees: amountXof - creditFee,
    };
}

module.exports = {
    PARTNER_FEES,
    calculatePartnerFee,
    calculateTotalFees,
};
