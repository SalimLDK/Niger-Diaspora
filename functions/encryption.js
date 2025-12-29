const CryptoJS = require("crypto-js");

/**
 * Encryption/Decryption service for Firebase Functions
 * Uses the same AES-256 key as the Flutter app to decrypt messages
 */

// Same key as in Flutter EncryptionService
const KEY_STRING = "DiaspoNigerSecureKey2025ForApps!";

/**
 * Decrypts text from the format "iv:base64ciphertext"
 * Returns the original text if the format is invalid or if decryption fails
 * 
 * @param {string} encryptedFullText - The encrypted text in format "iv:base64ciphertext"
 * @returns {string} - The decrypted text or original text if decryption fails
 */
function decryptText(encryptedFullText) {
    if (!encryptedFullText || encryptedFullText === "") {
        return encryptedFullText;
    }

    try {
        const parts = encryptedFullText.split(":");

        // If not in the correct format (iv:ciphertext), assume it's unencrypted
        if (parts.length !== 2) {
            return encryptedFullText;
        }

        const ivBase64 = parts[0];
        const ciphertextBase64 = parts[1];

        // Parse IV and ciphertext
        const iv = CryptoJS.enc.Base64.parse(ivBase64);
        const ciphertext = CryptoJS.enc.Base64.parse(ciphertextBase64);

        // Create key from string
        const key = CryptoJS.enc.Utf8.parse(KEY_STRING);

        // Decrypt
        const decrypted = CryptoJS.AES.decrypt(
            { ciphertext: ciphertext },
            key,
            {
                iv: iv,
                mode: CryptoJS.mode.CBC,
                padding: CryptoJS.pad.Pkcs7
            }
        );

        // Convert to UTF-8 string
        const decryptedText = decrypted.toString(CryptoJS.enc.Utf8);

        // If decryption resulted in empty string, return original
        if (!decryptedText) {
            return encryptedFullText;
        }

        return decryptedText;
    } catch (error) {
        // If decryption fails (wrong key, corrupted data, legacy format), return original
        // console.log(`Decryption failed for text, returning original: ${error.message}`);
        return encryptedFullText;
    }
}

/**
 * Encrypts text to the format "iv:base64ciphertext"
 * Note: This is primarily for completeness, notifications only need decryption
 * 
 * @param {string} plainText - The text to encrypt
 * @returns {string} - The encrypted text in format "iv:base64ciphertext"
 */
function encryptText(plainText) {
    if (!plainText || plainText === "") {
        return plainText;
    }

    try {
        // Generate random IV
        const iv = CryptoJS.lib.WordArray.random(16);

        // Create key from string
        const key = CryptoJS.enc.Utf8.parse(KEY_STRING);

        // Encrypt
        const encrypted = CryptoJS.AES.encrypt(plainText, key, {
            iv: iv,
            mode: CryptoJS.mode.CBC,
            padding: CryptoJS.pad.Pkcs7
        });

        // Return in format "iv:ciphertext"
        return `${iv.toString(CryptoJS.enc.Base64)}:${encrypted.ciphertext.toString(CryptoJS.enc.Base64)}`;
    } catch (error) {
        console.error(`Encryption failed: ${error.message}`);
        return plainText;
    }
}

module.exports = {
    decryptText,
    encryptText
};
