// Load environment variables from .env file FIRST
require("dotenv").config();

const crypto = require("crypto");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { GoogleAuth } = require("google-auth-library");
const { decryptText } = require("./encryption");
const partners = require("./partners");
// Tokens/profils/conversations : lus dans Supabase, PAS dans Firestore.
const {
  getFcmTokens,
  removeFcmTokens,
  getConversation,
  getUsersForPush,
} = require("./supabase");

admin.initializeApp();

/**
 * Vrai si la valeur ressemble à un placeholder de `.env.example` plutôt qu'à un
 * vrai secret.
 *
 * Un secret non renseigné est facile à détecter ; un secret laissé à sa valeur
 * d'exemple est truthy et franchit tous les gardes `if (!secret)`, pour aller
 * échouer beaucoup plus loin avec un message trompeur. C'est ce qui se passait
 * avec STRIPE_WEBHOOK_SECRET, resté à `whsec_your_webhook_secret_here` en
 * production : chaque webhook Stripe repartait en 400 « signature invalide ».
 *
 * Voir docs/ops/secrets_production.md.
 */
function isPlaceholderSecret(value) {
    if (typeof value !== "string" || value.trim() === "") return true;
    const v = value.toLowerCase();
    return (
        v.includes("your_") ||
        v.includes("_here") ||
        v.includes("replace") ||
        v.includes("changeme") ||
        v.includes("xxx") ||
        v.endsWith("...")
    );
}

// Stripe zero-decimal currencies — amounts must NOT be multiplied by 100
// See: https://stripe.com/docs/currencies#zero-decimal
const ZERO_DECIMAL_CURRENCIES = new Set([
    "bif", "clp", "gnf", "jpy", "kmf", "krw", "mga", "pyg",
    "rwf", "ugx", "vnd", "vuv", "xaf", "xof", "xpf",
]);

// ============================================================================
// TURN CREDENTIALS — Ephemeral HMAC-based (C1 security fix)
// ============================================================================
// Generates short-lived TURN credentials using the TURN REST API pattern.
// The shared secret (TURN_SECRET) must match the coturn configuration
// (use-auth-secret=yes, static-auth-secret=<TURN_SECRET>).
// Credentials are valid for 24 hours by default.
const TURN_TTL_SECONDS = 86400; // 24 hours

exports.getTurnCredentials = functions.https.onCall(async (data, context) => {
    // Require authentication
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }

    const turnSecret = process.env.TURN_SECRET;
    if (!turnSecret) {
        console.error("TURN_SECRET not configured in environment");
        throw new functions.https.HttpsError("internal", "TURN server not configured");
    }

    // Generate time-limited username: "timestamp:uid"
    const timestamp = Math.floor(Date.now() / 1000) + TURN_TTL_SECONDS;
    const username = `${timestamp}:${context.auth.uid}`;

    // Generate HMAC-SHA1 credential (coturn compatible)
    const credential = crypto.createHmac("sha1", turnSecret)
        .update(username)
        .digest("base64");

    return {
        username,
        credential,
        ttl: TURN_TTL_SECONDS,
    };
});
// ============================================================================

/**
 * Checks if a message is E2EE encrypted (cannot be decrypted server-side).
 * E2EE messages have e2eeVersion field in the message data.
 *
 * @param {object} messageData - The message data from RTDB
 * @returns {boolean} - True if message is E2EE encrypted
 */
function isE2EEMessage(messageData) {
    if (!messageData) return false;
    // New format: explicit encryptionLevel field
    if (messageData.encryptionLevel === "e2ee") return true;
    // New format: multi-device payloads map
    if (messageData.e2eePayloads !== undefined) return true;
    // Legacy format: single-device payload (kept for backward compat)
    if (messageData.e2eePayload !== undefined) return true;
    // Very old format: e2eeVersion field
    if (messageData.e2eeVersion !== undefined) return true;
    return false;
}

/**
 * Gets a generic preview for E2EE messages based on message type.
 * Since we cannot decrypt E2EE messages server-side, we show a generic preview.
 *
 * @param {string} messageType - The type of message (text, image, video, etc.)
 * @returns {string} - A generic preview string
 */
function getE2EEMessagePreview(messageType) {
    switch (messageType) {
        case "image":
            return "📸 Photo";
        case "video":
            return "🎥 Vidéo";
        case "audio":
            return "🎙️ Message vocal";
        case "file":
            return "📄 Document";
        case "call":
            return "📞 Appel";
        case "location":
            return "📍 Position partagée";
        default:
            // For E2EE text messages, we cannot show the content
            return "🔒 Nouveau message";
    }
}

/**
 * Safely gets message preview for notifications.
 * Handles both legacy AES encryption and new E2EE messages.
 *
 * @param {object} message - The full message object
 * @param {string} encryptedContent - The encrypted content string
 * @returns {string} - The decrypted preview or generic E2EE preview
 */
function getMessagePreview(message, encryptedContent) {
    // Check if this is an E2EE message
    if (isE2EEMessage(message)) {
        return getE2EEMessagePreview(message.type || "text");
    }

    // Legacy encryption - can be decrypted server-side
    try {
        const decrypted = decryptText(encryptedContent);
        if (decrypted && decrypted.length > 100) {
            return decrypted.substring(0, 100) + "...";
        }
        return decrypted || "Nouveau message";
    } catch (error) {
        console.warn("Failed to decrypt message:", error.message);
        return "Nouveau message";
    }
}

// ============================================================================
// PLAY INTEGRITY API VERIFICATION
// ============================================================================

/**
 * Verifies a Play Integrity token and returns the decoded verdict.
 *
 * Call this from your Flutter app after getting an integrity token:
 *
 * ```dart
 * final result = await FirebaseFunctions.instance
 *     .httpsCallable('verifyPlayIntegrity')
 *     .call({'token': integrityToken, 'nonce': originalNonce});
 * ```
 *
 * The function returns the decoded verdict with all integrity signals.
 */
exports.verifyPlayIntegrity = functions.https.onCall(async (data, context) => {
    // Require authentication
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "User must be authenticated to verify integrity"
        );
    }

    const { token, nonce } = data;

    if (!token) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Integrity token is required"
        );
    }

    try {
        // Get application default credentials
        const auth = new GoogleAuth({
            scopes: ["https://www.googleapis.com/auth/playintegrity"],
        });
        const client = await auth.getClient();
        const accessToken = await client.getAccessToken();

        // Package name must match your Android app
        const packageName = "com.diasponiger.diasponiger";

        // Call Google's Play Integrity API to decode the token
        const response = await fetch(
            `https://playintegrity.googleapis.com/v1/${packageName}:decodeIntegrityToken`,
            {
                method: "POST",
                headers: {
                    "Authorization": `Bearer ${accessToken.token}`,
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({ integrity_token: token }),
            }
        );

        if (!response.ok) {
            const errorText = await response.text();
            console.error("Play Integrity API error:", errorText);
            throw new functions.https.HttpsError(
                "internal",
                `Play Integrity API error: ${response.status}`
            );
        }

        const result = await response.json();
        const payload = result.tokenPayloadExternal;

        if (!payload) {
            throw new functions.https.HttpsError(
                "internal",
                "Invalid response from Play Integrity API"
            );
        }

        // Verify nonce matches (prevents replay attacks)
        if (nonce && payload.requestDetails?.nonce !== nonce) {
            console.warn("Nonce mismatch - possible replay attack");
            throw new functions.https.HttpsError(
                "permission-denied",
                "Nonce verification failed"
            );
        }

        // Verify the request was for our package
        if (payload.requestDetails?.requestPackageName !== packageName) {
            throw new functions.https.HttpsError(
                "permission-denied",
                "Package name mismatch"
            );
        }

        // Extract verdict information
        const deviceIntegrity = payload.deviceIntegrity?.deviceRecognitionVerdict || [];
        const appIntegrity = payload.appIntegrity || {};
        const accountDetails = payload.accountDetails || {};
        const environmentDetails = payload.environmentDetails || {};

        // Build the response with all verdict data
        const verdict = {
            // Device integrity
            meetsBasicIntegrity: deviceIntegrity.includes("MEETS_BASIC_INTEGRITY"),
            meetsDeviceIntegrity: deviceIntegrity.includes("MEETS_DEVICE_INTEGRITY"),
            meetsStrongIntegrity: deviceIntegrity.includes("MEETS_STRONG_INTEGRITY"),

            // App integrity
            isPlayRecognized: appIntegrity.appRecognitionVerdict === "PLAY_RECOGNIZED",
            appVersionCode: appIntegrity.versionCode,
            certificateSha256Digest: appIntegrity.certificateSha256Digest,

            // Account details (license status)
            appLicensingVerdict: accountDetails.appLicensingVerdict,
            isLicensed: accountDetails.appLicensingVerdict === "LICENSED",

            // Recent device activity
            deviceActivityLevel: accountDetails.recentDeviceActivity?.deviceActivityLevel,

            // Environment details (Play Protect & app access risk)
            playProtectVerdict: environmentDetails.playProtectVerdict,
            appAccessRiskVerdict: environmentDetails.appAccessRiskVerdict,

            // Raw payload for advanced use cases
            rawPayload: payload,
        };

        // Determine overall security level
        verdict.isSecure = verdict.meetsBasicIntegrity &&
                          verdict.meetsDeviceIntegrity &&
                          verdict.isPlayRecognized;

        verdict.isHighlySecure = verdict.meetsStrongIntegrity &&
                                 verdict.meetsDeviceIntegrity &&
                                 verdict.isPlayRecognized &&
                                 verdict.isLicensed;

        // Log for monitoring (remove in production if too verbose)
        console.log(`Integrity check for user ${context.auth.uid}:`, {
            meetsBasicIntegrity: verdict.meetsBasicIntegrity,
            meetsStrongIntegrity: verdict.meetsStrongIntegrity,
            isPlayRecognized: verdict.isPlayRecognized,
            isSecure: verdict.isSecure,
        });

        return verdict;

    } catch (error) {
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        console.error("Error verifying Play Integrity token:", error);
        throw new functions.https.HttpsError(
            "internal",
            `Failed to verify integrity: ${error.message}`
        );
    }
});

/**
 * Triggered when a new document is created in the 'notifications' collection.
 * Sends a push notification to the user's devices.
 *
 * NOTE: This function does NOT send notifications for type "message"
 * because onMessageCreated already handles those directly.
 */
exports.sendNotificationOnCreate = functions.firestore
    .document("notifications/{notificationId}")
    .onCreate(async (snapshot, context) => {
        const notificationData = snapshot.data();
        const userId = notificationData.userId;
        const notificationType = String(notificationData.type || "general");

        if (!userId) {
            // console.log("No userId in notification document");
            return null;
        }

        // Skip message notifications - they are handled by onMessageCreated
        if (notificationType === "message") {
            // console.log("Skipping message notification - handled by onMessageCreated");
            return null;
        }

        try {
            // Get the user's FCM tokens
            const userDoc = await admin.firestore().collection("users").doc(userId).get();

            if (!userDoc.exists) {
                // console.log(`User ${userId} does not exist`);
                return null;
            }

            const userData = userDoc.data();
            const fcmTokens = userData.fcmTokens;

            if (!fcmTokens || !Array.isArray(fcmTokens) || fcmTokens.length === 0) {
                // console.log(`No FCM tokens for user ${userId}`);
                return null;
            }

            // Prepare the message payload
            const title = notificationData.title || "Nouvelle notification";
            const body = notificationData.body || "Vous avez une nouvelle notification";

            // Get the appropriate channel based on notification type
            const channelId = notificationType === "order" ? "orders_channel" :
                              notificationType === "newOrder" ? "orders_channel" :
                              notificationType === "orderPaid" ? "orders_channel" :
                              notificationType === "orderShipped" ? "orders_channel" :
                              notificationType === "orderDelivered" ? "orders_channel" :
                              notificationType === "orderCancelled" ? "orders_channel" :
                              notificationType === "orderCompleted" ? "orders_channel" :
                              notificationType === "eventReminder" ? "event_reminders_channel" :
                              notificationType === "eventAttendance" ? "events_channel" :
                              notificationType === "localEvent" ? "events_channel" :
                              notificationType === "audioRoomReminder" ? "audio_rooms_reminders_channel" :
                              notificationType === "audioRoomLive" ? "audio_rooms_reminders_channel" :
                              notificationType === "audioRoomInvite" ? "audio_rooms_reminders_channel" :
                              notificationType === "audioRoomSpeakerRequest" ? "audio_rooms_reminders_channel" :
                              notificationType === "audioRoomEnded" ? "audio_rooms_reminders_channel" :
                              notificationType === "podcastNewEpisode" ? "podcast_reminders_channel" :
                              notificationType === "podcastLiveStarting" ? "podcast_reminders_channel" :
                              notificationType === "podcastLiveNow" ? "podcast_reminders_channel" :
                              notificationType === "transferReminder" ? "transfer_reminders_channel" :
                              notificationType === "transferCompleted" ? "transfer_reminders_channel" :
                              notificationType === "transferReceived" ? "transfer_reminders_channel" :
                              notificationType === "transferFailed" ? "transfer_reminders_channel" :
                              notificationType === "missedCall" ? "calls_channel" :
                              notificationType === "friendRequest" ? "friends_channel" :
                              notificationType === "friendAccepted" ? "friends_channel" :
                              "general_channel";

            // console.log(`Sending ${notificationType} notification to ${fcmTokens.length} tokens for user ${userId}`);

            // Send multicast message with Android/iOS config (using sendEachForMulticast)
            const response = await admin.messaging().sendEachForMulticast({
                tokens: fcmTokens,
                notification: { title, body },
                data: {
                    type: notificationType,
                    title: title,
                    body: body,
                    targetId: String(notificationData.targetId || ""),
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                    ...Object.keys(notificationData.data || {}).reduce((acc, key) => {
                        acc[key] = String(notificationData.data[key]);
                        return acc;
                    }, {}),
                },
                android: {
                    priority: "high",
                    notification: {
                        channelId: channelId,
                        sound: "default",
                    },
                },
                apns: {
                    headers: {
                        "apns-push-type": "alert",
                    },
                    payload: {
                        aps: {
                            sound: "default",
                            badge: 1,
                            "content-available": 1, // Wake app in background for sync
                        },
                    },
                },
            });

            // Remove only permanently-invalid tokens (not transient errors like quota/network)
            if (response.failureCount > 0) {
                const deadTokens = [];
                response.responses.forEach((resp, idx) => {
                    if (!resp.success) {
                        const code = resp.error?.code;
                        if (
                            code === "messaging/invalid-registration-token" ||
                            code === "messaging/registration-token-not-registered"
                        ) {
                            deadTokens.push(fcmTokens[idx]);
                        }
                    }
                });

                if (deadTokens.length > 0) {
                    await admin.firestore().collection("users").doc(userId).update({
                        fcmTokens: admin.firestore.FieldValue.arrayRemove(...deadTokens),
                    });
                }
            }

            return { success: true, sentCount: response.successCount };
        } catch (error) {
            console.error("Error sending notification:", error);
            return null;
        }
    });

/**
 * Triggered when a new message is created in Firebase Realtime Database.
 * Sends push notifications to all participants except the sender.
 *
 * Path: messages/{conversationId}/{messageId}
 *
 * IMPORTANT: The database is in europe-west1, so the function must be in the same region
 */
/**
 * Coeur de l'envoi des notifications push d'un nouveau message.
 *
 * Extrait du declencheur RTDB `onMessageCreated`, ou il avait ete replie :
 * le callable `sendMessagePush` doit executer exactement la meme logique, et
 * la dupliquer aurait fait vivre 350 lignes en double.
 *
 * `callerUid` n'est renseigne que par le callable — c'est ce qui declenche le
 * controle de participation.
 */
async function handleNewMessagePush(message, conversationId, messageId, callerUid = null) {

        // console.log(`New message created in conversation ${conversationId}`);

        try {
            // Conversation lue dans Supabase (les conversations ont migré depuis
            // Firestore). Sans ça, la fonction sortait toujours en amont.
            const conv = await getConversation(conversationId);
            if (!conv) {
                // console.log(`Conversation ${conversationId} not found in Supabase`);
                return null;
            }

            // Appel via callable : l'appelant doit etre participant (anti-spam).
            // Ce controle vient de la version d'origine de `handleNewMessagePush` :
            // sans lui, `sendMessagePush` laisserait pousser vers une conversation
            // dont on ne fait pas partie.
            if (callerUid && !(conv.participantIds || []).includes(callerUid)) {
                console.warn(`sendMessagePush: ${callerUid} n'est pas participant de ${conversationId}`);
                return null;
            }

            // Objet compat pour les usages aval (conversation.name/imageUrl/groupId).
            const conversation = {
                name: conv.name,
                imageUrl: conv.imageUrl,
                groupId: conv.groupId,
            };
            const senderId = message.senderId;
            const participantIds = conv.participantIds;
            const mutedBy = conv.mutedBy;
            const conversationType = conv.type;

            // Helper function to check if user is currently muted
            const isUserMuted = (userId) => {
                const muteValue = mutedBy[userId];
                if (!muteValue) return false;
                if (muteValue === true || muteValue === "forever") return true;
                // Check if it's a timestamp and if it's expired
                const expiration = new Date(muteValue);
                if (isNaN(expiration.getTime())) return true; // Invalid date = treat as forever
                return expiration > new Date(); // Muted if expiration is in the future
            };

            // Get recipients (exclude sender)
            const recipients = participantIds.filter((id) => id !== senderId);

            if (recipients.length === 0) {
                // console.log("No recipients to notify");
                return null;
            }

            // Fetch groupé (1 requête) : expéditeur + destinataires + mentionnés.
            const mentionedIds = (message.mentionedUsers || [])
                .map((m) => m && m.id)
                .filter(Boolean);
            const usersMap = await getUsersForPush([
                senderId,
                ...recipients,
                ...mentionedIds,
            ]);

            // Nom + photo de l'expéditeur (depuis Supabase).
            const senderInfo = usersMap.get(senderId) || {};
            const senderName = senderInfo.displayName || "Un utilisateur";
            const senderPhotoUrl = senderInfo.avatarUrl || "";

            // Prepare notification content based on message type
            const messageType = message.type || "text";
            let messagePreview;

            // Check if this is an E2EE message (cannot decrypt server-side)
            if (isE2EEMessage(message)) {
                messagePreview = getE2EEMessagePreview(messageType);
            } else {
                // Legacy encryption handling
                switch (messageType) {
                    case "image":
                        messagePreview = "📸 Photo";
                        break;
                    case "video":
                        messagePreview = "🎥 Vidéo";
                        break;
                    case "audio":
                        messagePreview = "🎙️ Message vocal";
                        break;
                    case "file":
                        messagePreview = `📄 ${message.fileName || "Document"}`;
                        break;
                    case "location":
                        messagePreview = "📍 Position partagée";
                        break;
                    default:
                        // Decrypt text messages before displaying in notification
                        messagePreview = getMessagePreview(message, message.content || "");
                }
            }

            // Determine notification title and body
            let title, body;
            if (conversationType === "group") {
                title = conversation.name || "Groupe";
                body = `${senderName}: ${messagePreview}`;
            } else {
                title = senderName;
                body = messagePreview;
            }

            // Collect tokens from recipients, grouped by showMessagePreview preference
            const tokensWithPreview = [];
            const tokensWithoutPreview = [];
            const tokenOwnersWithPreview = [];
            const tokenOwnersWithoutPreview = [];

            for (const recipientId of recipients) {
                if (isUserMuted(recipientId)) {
                    // console.log(`User ${recipientId} has muted this conversation`);
                    continue;
                }

                const info = usersMap.get(recipientId);
                if (info) {
                    const tokens = info.fcmTokens;
                    const notificationsEnabled = info.notificationsEnabled;
                    const showMessagePreview = info.showMessagePreview;

                    // Messages système : la préférence dédiée (notifySystemMessages)
                    // n'a pas de colonne Supabase → on garde le défaut historique
                    // (désactivé) et on ne pousse pas les messages système.
                    if (messageType === "system") {
                        continue;
                    }

                    if (notificationsEnabled && tokens.length > 0) {
                        if (showMessagePreview) {
                            tokensWithPreview.push(...tokens);
                            tokens.forEach(() => tokenOwnersWithPreview.push(recipientId));
                        } else {
                            tokensWithoutPreview.push(...tokens);
                            tokens.forEach(() => tokenOwnersWithoutPreview.push(recipientId));
                        }
                    }
                }
            }

            const allTokens = [...tokensWithPreview, ...tokensWithoutPreview];
            const allTokenOwners = [...tokenOwnersWithPreview, ...tokenOwnersWithoutPreview];

            if (allTokens.length === 0) {
                // console.log("No valid tokens to send notification");
                return null;
            }

            // Store notification in Firestore for each recipient (for notification history)
            const notificationPromises = [];
            for (const recipientId of recipients) {
                if (isUserMuted(recipientId)) continue;

                notificationPromises.push(
                    admin.firestore().collection("notifications").add({
                        userId: recipientId,
                        title: title,
                        body: body,
                        type: "message",
                        targetId: conversationId,
                        senderId: senderId,
                        senderPhotoUrl: senderPhotoUrl,
                        data: {
                            conversationId,
                            messageId,
                            senderId,
                        },
                        isRead: false,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    })
                );
            }
            await Promise.all(notificationPromises);
            // console.log(`Stored ${notificationPromises.length} notifications in Firestore`);

            // Prepare E2EE-specific data for client-side decryption
            const isE2EE = isE2EEMessage(message);
            const e2eeData = isE2EE ? {
                isE2EE: "true",
                messageType: messageType,
                // Include encrypted content for client-side decryption (foreground only)
                encryptedPreview: message.content || "",
                senderName: senderName,
                conversationType: conversationType || "individual",
            } : {};

            // Prepare conversation data for navigation
            const conversationData = {
                conversationType: conversationType || "individual",
                conversationTitle: conversationType === "group" ? (conversation.name || "Groupe") : senderName,
                conversationPhotoUrl: conversationType === "group" ? (conversation.imageUrl || "") : senderPhotoUrl,
                groupId: conversationType === "group" ? (conversation.groupId || "") : "",
            };

            // Send push notifications - separate batches for privacy preferences
            let totalSuccessCount = 0;
            const invalidTokens = [];

            // Helper function to send notifications to a batch
            const sendBatch = async (tokens, tokenOwners, showPreview) => {
                if (tokens.length === 0) return;

                // For users without preview, use generic message
                const notifTitle = showPreview ? title : senderName;
                const notifBody = showPreview ? body : "Nouveau message";

                const response = await admin.messaging().sendEachForMulticast({
                    tokens: tokens,
                    notification: { title: notifTitle, body: notifBody },
                    data: {
                        type: "message",
                        title: notifTitle,
                        body: notifBody,
                        conversationId,
                        messageId,
                        senderId,
                        senderName: senderName,
                        senderPhotoUrl: senderPhotoUrl,
                        click_action: "FLUTTER_NOTIFICATION_CLICK",
                        showMessagePreview: showPreview ? "true" : "false",
                        ...e2eeData,
                        ...conversationData,
                    },
                    android: {
                        priority: "high",
                        notification: {
                            channelId: "messages",
                            sound: "default",
                            tag: `msg_${conversationId}`, // Android notification grouping per conversation
                        },
                    },
                    apns: {
                        headers: {
                            "apns-collapse-id": conversationId, // Group notifications per conversation
                            "apns-push-type": "alert",
                        },
                        payload: {
                            aps: {
                                sound: "default",
                                badge: 1,
                                "thread-id": conversationId, // iOS thread grouping per conversation
                                "content-available": 1, // Wake app in background for sync
                            },
                        },
                    },
                });

                totalSuccessCount += response.successCount;

                // Collect invalid tokens
                if (response.failureCount > 0) {
                    response.responses.forEach((resp, idx) => {
                        if (!resp.success && (resp.error?.code === "messaging/invalid-registration-token" || resp.error?.code === "messaging/registration-token-not-registered")) {
                            invalidTokens.push({ token: tokens[idx], userId: tokenOwners[idx] });
                        }
                    });
                }
            };

            // Send to users with preview enabled (full content)
            await sendBatch(tokensWithPreview, tokenOwnersWithPreview, true);

            // Send to users without preview (generic message)
            await sendBatch(tokensWithoutPreview, tokenOwnersWithoutPreview, false);

            // ── Mention notifications ──────────────────────────────────────
            // For group conversations only: increment unreadMentions counter
            // and send a targeted notification to each mentioned user.
            const mentionedUsers = message.mentionedUsers || [];
            if (mentionedUsers.length > 0 && conversationType === "group") {
                for (const mentioned of mentionedUsers) {
                    if (!mentioned.id || mentioned.id === senderId) continue;

                    // Increment unreadMentions (best-effort ; la conversation a
                    // migré vers Supabase, cette écriture Firestore est morte —
                    // .catch pour ne pas interrompre l'envoi des pushes).
                    await admin.firestore()
                        .collection("conversations")
                        .doc(conversationId)
                        .update({
                            [`unreadMentions.${mentioned.id}`]: admin.firestore.FieldValue.increment(1),
                        })
                        .catch(() => {/* conversation absente de Firestore : ignore */});

                    // Store notification document in Firestore (visible in Notifications screen)
                    await admin.firestore().collection("notifications").add({
                        userId: mentioned.id,
                        title: conversation.name || "Groupe",
                        body: `${senderName} vous a mentionné`,
                        type: "mention",
                        targetId: conversationId,
                        senderId: senderId,
                        senderPhotoUrl: senderPhotoUrl,
                        isRead: false,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    }).catch(() => {/* ignore storage errors */});

                    // Send a targeted FCM notification (tokens depuis Supabase)
                    const mentionedInfo = usersMap.get(mentioned.id);
                    const mentionTokens = mentionedInfo ? mentionedInfo.fcmTokens : [];
                    if (mentionTokens.length === 0) continue;

                    const mentionTitle = conversation.name || "Groupe";
                    const mentionBody = `${senderName} vous a mentionné: ${messagePreview}`;

                    await admin.messaging().sendEachForMulticast({
                        tokens: mentionTokens,
                        notification: { title: mentionTitle, body: mentionBody },
                        data: {
                            type: "mention",
                            conversationId,
                            messageId,
                            senderId,
                            senderName,
                            conversationType: "group",
                            click_action: "FLUTTER_NOTIFICATION_CLICK",
                        },
                        android: {
                            priority: "high",
                            notification: { channelId: "messages", sound: "default" },
                        },
                    }).catch(() => {/* ignore mention notification errors */});
                }
            }
            // ── End mention notifications ──────────────────────────────────

            // console.log(`Successfully sent ${totalSuccessCount}/${allTokens.length} push notifications`);

            // Clean up invalid tokens
            if (invalidTokens.length > 0) {
                // console.log(`Removing ${invalidTokens.length} invalid tokens`);
                const updates = {};
                invalidTokens.forEach(({ token, userId }) => {
                    if (!updates[userId]) updates[userId] = [];
                    updates[userId].push(token);
                });

                await Promise.all(
                    Object.entries(updates).map(([userId, tokens]) =>
                        removeFcmTokens(userId, tokens)
                    )
                );
            }

            return { success: true, sentCount: totalSuccessCount };
        } catch (error) {
            console.error("Error sending message notification:", error);
            return null;
        }
}

exports.onMessageCreated = functions
    .region("europe-west1")
    .database.instance("diaspo-niger-default-rtdb")
    .ref("/messages/{conversationId}/{messageId}")
    .onCreate(async (snapshot, context) => {
        const message = snapshot.val();
        const conversationId = context.params.conversationId;
        const messageId = context.params.messageId;
        return handleNewMessagePush(message, conversationId, messageId);
    });

exports.sendMessagePush = functions
    .region("europe-west1")
    .https.onCall(async (data, context) => {
        if (!context.auth) {
            throw new functions.https.HttpsError("unauthenticated", "Authentification requise");
        }
        const conversationId = data && data.conversationId;
        const messageId = data && data.messageId;
        const message = data && data.message;
        if (!conversationId || !messageId || !message || typeof message !== "object") {
            throw new functions.https.HttpsError(
                "invalid-argument",
                "conversationId, messageId et message sont requis",
            );
        }
        // Anti-usurpation : le senderId doit être l'utilisateur authentifié.
        if (message.senderId !== context.auth.uid) {
            throw new functions.https.HttpsError("permission-denied", "senderId invalide");
        }
        return handleNewMessagePush(
            message,
            String(conversationId),
            String(messageId),
            context.auth.uid,
        );
    });

/**
 * Conservee UNIQUEMENT parce qu'elle tourne encore en production : elle avait
 * ete retiree du depot par `1bb0cca` sans etre supprimee cote Firebase, et
 * plus personne ne pouvait la relire. Elle est desactivee depuis longtemps
 * (`return null` en tete) — `onMessageCreated` fait le travail.
 *
 * Recuperee telle quelle depuis `1bb0cca^:functions/index.js`.
 */
exports.sendChatNotification = functions.firestore
    .document("conversations/{conversationId}")
    .onUpdate(async (change, context) => {
        // DISABLED - onMessageCreated handles message notifications
        // console.log("sendChatNotification is disabled - using onMessageCreated instead");
        return null;

        /*
        const before = change.before.data();
        const after = change.after.data();

        // Check if lastMessage changed (new message sent)
        if (!after.lastMessage || before.lastMessage === after.lastMessage) {
            // console.log("No new message detected");
            return null;
        }

        const conversationId = context.params.conversationId;
        const senderId = after.lastMessageSenderId;
        const participantIds = after.participantIds || [];
        const mutedBy = after.mutedBy || [];
        const conversationType = after.type; // 'individual' or 'group'
        const lastMessage = after.lastMessage;

        if (!senderId || participantIds.length === 0) {
            // console.log("Missing sender or participants");
            return null;
        }

        try {
            // Get all participants' tokens (except sender and muted users)
            const recipients = participantIds.filter((id) => id !== senderId && !mutedBy.includes(id));

            if (recipients.length === 0) {
                // console.log("No recipients to notify");
                return null;
            }

            // Fetch sender's name for the notification
            const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
            const senderName = senderDoc.exists ? (senderDoc.data().displayName || "Un utilisateur") : "Un utilisateur";

            // Decrypt the last message for the notification
            const decryptedMessage = decryptText(lastMessage);

            // Determine notification title and body
            let title;
            let body;

            if (conversationType === "group") {
                title = after.name || "Groupe";
                body = `${senderName}: ${decryptedMessage}`;
            } else {
                title = senderName;
                body = decryptedMessage;
            }

            // Collect all tokens from recipients
            const allTokens = [];
            for (const recipientId of recipients) {
                const recipientDoc = await admin.firestore().collection("users").doc(recipientId).get();
                if (recipientDoc.exists) {
                    const tokens = recipientDoc.data().fcmTokens || [];
                    allTokens.push(...tokens);
                }
            }

            // Store notification in Firestore for each recipient (for notification history)
            const notificationPromises = [];
            const truncatedBody = body.length > 100 ? body.substring(0, 100) + "..." : body;

            for (const recipientId of recipients) {
                notificationPromises.push(
                    admin.firestore().collection("notifications").add({
                        userId: recipientId,
                        title: title,
                        body: truncatedBody,
                        type: "message",
                        targetId: conversationId,
                        data: {
                            conversationId: conversationId,
                            senderId: senderId,
                        },
                        isRead: false,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    })
                );
            }
            await Promise.all(notificationPromises);
            // console.log(`Stored ${notificationPromises.length} notifications in Firestore`);

            if (allTokens.length === 0) {
                // console.log("No tokens found for recipients, but notifications stored");
                return { success: true, sentCount: 0, storedCount: notificationPromises.length };
            }

            // console.log(`Sending chat notification to ${allTokens.length} tokens`);

            // Send multicast message with Android/iOS config (using sendEachForMulticast)
            const response = await admin.messaging().sendEachForMulticast({
                tokens: allTokens,
                notification: {
                    title: title,
                    body: truncatedBody,
                },
                data: {
                    type: "message",
                    title: title,
                    body: truncatedBody,
                    conversationId: conversationId,
                    senderId: senderId,
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
                android: {
                    priority: "high",
                    notification: {
                        channelId: "messages",
                        sound: "default",
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            sound: "default",
                            badge: 1,
                        },
                    },
                },
            });

            // console.log(`Successfully sent ${response.successCount} push notifications`);

            return { success: true, sentCount: response.successCount };
        } catch (error) {
            // console.error("Error sending chat notification:", error);
            return null;
        }
        */
    });


/**
 * Index messages for full-text search.
 * Creates a searchable index in Firestore for message content.
 * This enables efficient searching across conversation messages.
 */
exports.onMessageCreatedUpdateSearchIndex = functions
    .region("europe-west1")
    .database.instance("diaspo-niger-default-rtdb")
    .ref("/messages/{conversationId}/{messageId}")
    .onCreate(async (snapshot, context) => {
        const message = snapshot.val();
        if (!message) return null;

        const conversationId = context.params.conversationId;
        const messageId = context.params.messageId;

        try {
            // Build searchable text from message content
            let searchableText = (message.senderName || "").toLowerCase();

            // Only index non-E2EE text messages
            const messageType = message.type || "text";
            const isE2EE = message.isE2EE === true ||
                          (message.encryptionVersion && message.encryptionVersion > 0);

            if (!isE2EE) {
                if (messageType === "text" && message.content) {
                    // Add decrypted/plain text content
                    searchableText += " " + message.content.toLowerCase();
                } else if (messageType === "image") {
                    searchableText += " photo image";
                } else if (messageType === "video") {
                    searchableText += " video vidéo";
                } else if (messageType === "audio") {
                    searchableText += " audio vocal message";
                } else if (messageType === "file" || messageType === "document") {
                    searchableText += " document fichier " + (message.fileName || "").toLowerCase();
                } else if (messageType === "location") {
                    searchableText += " localisation position lieu";
                }
            } else {
                // For E2EE messages, only index sender name and message type
                searchableText += " " + messageType;
            }

            // Store in Firestore search index collection
            await admin.firestore()
                .collection("messages_searchindex")
                .doc(messageId)
                .set({
                    conversationId: conversationId,
                    searchableText: searchableText.trim(),
                    messageType: messageType,
                    senderId: message.senderId || "",
                    senderName: message.senderName || "",
                    createdAt: message.createdAt || Date.now(),
                    isE2EE: isE2EE,
                });

            return { success: true };
        } catch (error) {
            console.error("Error indexing message for search:", error);
            return null;
        }
    });

/**
 * Triggered when a new call is created in the 'calls' collection.
 * Sends a high-priority push notification to the callee to wake up the app
 * and display the incoming call screen.
 *
 * This is essential for calls to work when the app is in background or killed.
 */
exports.onCallCreated = functions.firestore
    .document("calls/{callId}")
    .onCreate(async (snapshot, context) => {
        const callData = snapshot.data();
        const callId = context.params.callId;

        // Only send notification for ringing calls
        if (callData.status !== "ringing") {
            return null;
        }

        const calleeId = callData.calleeId;
        const callerId = callData.callerId;
        const callerName = callData.callerName || "Quelqu'un";
        const callerPhotoUrl = callData.callerPhotoUrl || "";
        const callType = callData.type || "audio"; // "audio" or "video"

        if (!calleeId) {
            console.log("No calleeId in call document");
            return null;
        }

        try {
            // Tokens FCM du destinataire depuis Supabase (users.fcm_tokens).
            const fcmTokens = await getFcmTokens(calleeId);

            if (fcmTokens.length === 0) {
                console.log(`No FCM tokens for callee ${calleeId}`);
                return null;
            }

            // Prepare notification content
            const title = callerName;
            const body = callType === "video" ? "Appel vidéo entrant..." : "Appel vocal entrant...";

            console.log(`Sending incoming call notification to ${fcmTokens.length} tokens for callee ${calleeId}`);

            // Send DATA-ONLY notification to wake up the app
            // IMPORTANT: No 'notification' field so that the Dart background handler
            // is triggered even when the app is killed (Android requires this)
            const response = await admin.messaging().sendEachForMulticast({
                tokens: fcmTokens,
                // Data-only message - triggers background handler on both platforms
                data: {
                    type: "incoming_call",
                    callId: callId,
                    callerId: callerId,
                    callerName: callerName,
                    callerPhotoUrl: callerPhotoUrl,
                    callType: callType,
                    title: title,
                    body: body,
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                    // Timestamp for timeout handling
                    timestamp: String(Date.now()),
                },
                android: {
                    priority: "high",
                    ttl: 60000, // 60 seconds TTL (call timeout)
                    // NO notification block here - this ensures the Dart
                    // firebaseMessagingBackgroundHandler is called even when app is killed
                    // The Dart code will use flutter_callkit_incoming to show the call UI
                },
                apns: {
                    headers: {
                        "apns-priority": "10", // High priority (10 = immediate delivery)
                        "apns-push-type": "background", // Background push (not voip - voip requires PushKit)
                    },
                    payload: {
                        aps: {
                            "content-available": 1, // Wake up app in background
                            "mutable-content": 1,
                            // No alert/sound here - flutter_callkit_incoming handles the call UI
                        },
                        // Custom data for iOS - will be available in background handler
                        callId: callId,
                        callerId: callerId,
                        callerName: callerName,
                        callerPhotoUrl: callerPhotoUrl,
                        callType: callType,
                    },
                },
            });

            console.log(`Successfully sent ${response.successCount}/${fcmTokens.length} call notifications`);

            // Cleanup invalid tokens
            if (response.failureCount > 0) {
                const failedTokens = [];
                response.responses.forEach((resp, idx) => {
                    if (!resp.success && (
                        resp.error?.code === "messaging/invalid-registration-token" ||
                        resp.error?.code === "messaging/registration-token-not-registered"
                    )) {
                        failedTokens.push(fcmTokens[idx]);
                    }
                });

                if (failedTokens.length > 0) {
                    console.log(`Removing ${failedTokens.length} invalid tokens`);
                    await removeFcmTokens(calleeId, failedTokens);
                }
            }

            return { success: true, sentCount: response.successCount };
        } catch (error) {
            console.error("Error sending call notification:", error);
            return null;
        }
    });

/**
 * Triggered when a call status is updated (answered, declined, ended).
 * Sends notification to inform the caller about call status changes.
 */
exports.onCallUpdated = functions.firestore
    .document("calls/{callId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        const callId = context.params.callId;

        // Only process status changes
        if (before.status === after.status) {
            return null;
        }

        const newStatus = after.status;
        const callerId = after.callerId;
        const calleeId = after.calleeId;
        const calleeName = after.calleeName || "L'utilisateur";

        // Notify caller when callee declines or ends the call
        if (newStatus === "declined" || newStatus === "ended" || newStatus === "missed") {
            try {
                const fcmTokens = await getFcmTokens(callerId);

                if (fcmTokens.length === 0) {
                    return null;
                }

                // Prepare notification based on status
                let title, body;
                if (newStatus === "declined") {
                    title = "Appel refusé";
                    body = `${calleeName} a refusé votre appel`;
                } else if (newStatus === "missed") {
                    title = "Appel manqué";
                    body = `${calleeName} n'a pas répondu`;
                } else {
                    // ended - no notification needed for normal end
                    return null;
                }

                await admin.messaging().sendEachForMulticast({
                    tokens: fcmTokens,
                    data: {
                        type: "call_status",
                        callId: callId,
                        status: newStatus,
                        title: title,
                        body: body,
                    },
                    android: {
                        priority: "high",
                        notification: {
                            channelId: "calls_channel",
                        },
                    },
                    apns: {
                        payload: {
                            aps: {
                                "content-available": 1,
                            },
                        },
                    },
                });

                console.log(`Sent call status (${newStatus}) notification to caller ${callerId}`);
                return { success: true };
            } catch (error) {
                console.error("Error sending call status notification:", error);
                return null;
            }
        }

        // NEW: Notify callee when call is missed
        if (newStatus === "missed") {
            try {
                const fcmTokens = await getFcmTokens(calleeId);
                if (fcmTokens.length === 0) {
                    return null;
                }

                const callerName = after.callerName || "Quelqu'un";

                await admin.firestore().collection("notifications").add({
                    userId: calleeId,
                    title: "Appel manqué",
                    body: `${callerName} a essayé de vous appeler`,
                    type: "missedCall",
                    targetId: callId,
                    data: {
                        callerId: callerId,
                        callerName: callerName,
                        callType: after.type || "audio",
                    },
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                console.log(`Created missedCall notification for callee ${calleeId}`);
                return { success: true };
            } catch (error) {
                console.error("Error creating missed call notification:", error);
                return null;
            }
        }

        return null;
    });

/**
 * Scheduled function that runs every 15 minutes to process pending reminders.
 * Handles all reminder types: events, audio rooms, and transfers.
 */
exports.processReminders = functions.pubsub
    .schedule("every 15 minutes")
    .onRun(async (context) => {
        try {
            const now = admin.firestore.Timestamp.now();

            // Get all pending reminders where reminderTime has passed
            const remindersSnapshot = await admin.firestore()
                .collection("reminders")
                .where("status", "==", "pending")
                .where("reminderTime", "<=", now)
                .limit(500)
                .get();

            if (remindersSnapshot.empty) {
                return { success: true, count: 0 };
            }

            const promises = [];

            for (const reminderDoc of remindersSnapshot.docs) {
                const reminder = reminderDoc.data();
                const { userId, type, targetId, targetTitle, reminderOffset, scheduledAt } = reminder;

                // Build notification based on reminder type
                let notificationData;
                const timeUntilEvent = getTimeLabel(reminderOffset);

                switch (type) {
                    case "event":
                        notificationData = {
                            userId,
                            title: "Rappel d'événement",
                            body: `"${targetTitle}" commence ${timeUntilEvent}`,
                            type: "eventReminder",
                            targetId,
                            data: { eventId: targetId, eventTitle: targetTitle },
                            isRead: false,
                            createdAt: admin.firestore.FieldValue.serverTimestamp(),
                        };
                        break;

                    case "audioRoom":
                        notificationData = {
                            userId,
                            title: "Salle audio à venir",
                            body: `"${targetTitle}" commence ${timeUntilEvent}`,
                            type: "audioRoomReminder",
                            targetId,
                            data: { roomId: targetId, roomTitle: targetTitle },
                            isRead: false,
                            createdAt: admin.firestore.FieldValue.serverTimestamp(),
                        };
                        break;

                    case "transfer":
                        notificationData = {
                            userId,
                            title: "Transfert à venir",
                            body: `Rappel: ${targetTitle}`,
                            type: "transferReminder",
                            targetId,
                            data: { transferId: targetId },
                            isRead: false,
                            createdAt: admin.firestore.FieldValue.serverTimestamp(),
                        };
                        break;

                    default:
                        // Skip unknown types
                        continue;
                }

                // Create notification (triggers sendNotificationOnCreate)
                promises.push(
                    admin.firestore().collection("notifications").add(notificationData)
                );

                // Mark reminder as sent
                promises.push(
                    reminderDoc.ref.update({
                        status: "sent",
                        sentAt: admin.firestore.FieldValue.serverTimestamp(),
                    })
                );
            }

            await Promise.all(promises);

            return { success: true, count: remindersSnapshot.size };
        } catch (error) {
            console.error("Error processing reminders:", error);
            return null;
        }
    });

/**
 * Helper function to convert reminder offset to human-readable label
 */
function getTimeLabel(offset) {
    switch (offset) {
        case "1h":
            return "dans 1 heure";
        case "24h":
            return "demain";
        case "1w":
            return "dans une semaine";
        default:
            return "bientôt";
    }
}

/**
 * Legacy: Scheduled function that runs every hour to check for events starting in 24 hours
 * and sends reminder notifications to attendees who haven't set custom reminders.
 * This provides backward compatibility for users who haven't configured custom reminders.
 */
exports.sendEventReminders = functions.pubsub
    .schedule("every 1 hours")
    .onRun(async (context) => {
        try {
            const now = new Date();
            const in24Hours = new Date(now.getTime() + 24 * 60 * 60 * 1000);
            const in25Hours = new Date(now.getTime() + 25 * 60 * 60 * 1000);

            // Get events starting in the next 24-25 hours (1 hour window)
            const eventsSnapshot = await admin.firestore()
                .collection("events")
                .where("startDate", ">=", admin.firestore.Timestamp.fromDate(in24Hours))
                .where("startDate", "<=", admin.firestore.Timestamp.fromDate(in25Hours))
                .where("status", "==", "upcoming")
                .get();

            if (eventsSnapshot.empty) {
                return null;
            }

            const promises = [];

            for (const eventDoc of eventsSnapshot.docs) {
                const event = eventDoc.data();
                const attendeeIds = event.attendeeIds || [];

                if (attendeeIds.length === 0) {
                    continue;
                }

                // For each attendee, check if they have a custom reminder set
                for (const attendeeId of attendeeIds) {
                    // Check if user has custom reminders for this event
                    const customReminders = await admin.firestore()
                        .collection("reminders")
                        .where("userId", "==", attendeeId)
                        .where("targetId", "==", eventDoc.id)
                        .where("type", "==", "event")
                        .limit(1)
                        .get();

                    // Skip if user has custom reminders configured
                    if (!customReminders.empty) {
                        continue;
                    }

                    const notificationData = {
                        userId: attendeeId,
                        title: "Rappel d'événement",
                        body: `"${event.title}" commence demain à ${formatTime(event.startDate)}`,
                        type: "eventReminder",
                        targetId: eventDoc.id,
                        data: {
                            eventId: eventDoc.id,
                            eventTitle: event.title,
                        },
                        isRead: false,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    };

                    promises.push(
                        admin.firestore().collection("notifications").add(notificationData)
                    );
                }
            }

            await Promise.all(promises);

            return { success: true, count: promises.length };
        } catch (error) {
            console.error("Error sending event reminders:", error);
            return null;
        }
    });

/**
 * Helper function to format time
 */
function formatTime(timestamp) {
    if (!timestamp || !timestamp.toDate) {
        return "";
    }
    const date = timestamp.toDate();
    const hours = date.getHours().toString().padStart(2, "0");
    const minutes = date.getMinutes().toString().padStart(2, "0");
    return `${hours}:${minutes}`;
}

/**
 * Triggered when a new podcast episode is created.
 * Sends notifications to all subscribers with notifications enabled.
 */
exports.onPodcastEpisodeCreated = functions.firestore
    .document("podcastEpisodes/{episodeId}")
    .onCreate(async (snapshot, context) => {
        try {
            const episode = snapshot.data();
            const podcastId = episode.podcastId;
            const episodeTitle = episode.title || "Nouvel épisode";
            const podcastTitle = episode.podcastTitle || "";

            if (!podcastId) {
                return null;
            }

            // Get all users' podcast subscriptions
            const usersSnapshot = await admin.firestore()
                .collection("podcastUserData")
                .get();

            const promises = [];

            for (const userDoc of usersSnapshot.docs) {
                const userId = userDoc.id;

                // Get user's subscriptions for this podcast
                const subscriptionsSnapshot = await userDoc.ref
                    .collection("subscriptions")
                    .where("podcastId", "==", podcastId)
                    .where("notificationsEnabled", "==", true)
                    .limit(1)
                    .get();

                if (subscriptionsSnapshot.empty) {
                    continue;
                }

                // Create notification for this subscriber
                const notificationData = {
                    userId,
                    title: "Nouvel épisode disponible",
                    body: podcastTitle ? `${episodeTitle} - ${podcastTitle}` : episodeTitle,
                    type: "podcastNewEpisode",
                    targetId: context.params.episodeId,
                    data: {
                        podcastId,
                        episodeId: context.params.episodeId,
                        episodeTitle,
                    },
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                };

                promises.push(
                    admin.firestore().collection("notifications").add(notificationData)
                );
            }

            await Promise.all(promises);

            return { success: true, count: promises.length };
        } catch (error) {
            console.error("Error sending podcast episode notifications:", error);
            return null;
        }
    });

/**
 * Triggered when an audio room status changes (scheduled -> live).
 * Notifies all users who have a reminder for this room.
 */
exports.onAudioRoomStatusChanged = functions.firestore
    .document("audioRooms/{roomId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        const roomId = context.params.roomId;

        // Only notify when status changes from "scheduled" to "live"
        if (before.status !== "scheduled" || after.status !== "live") {
            return null;
        }

        const roomTitle = after.title || "Salon audio";
        const hostName = after.hostName || "Hôte";

        try {
            // Find all pending reminders for this room
            const remindersSnapshot = await admin.firestore()
                .collection("reminders")
                .where("targetId", "==", roomId)
                .where("status", "==", "pending")
                .where("type", "==", "audioRoom")
                .get();

            if (remindersSnapshot.empty) {
                return null;
            }

            const promises = [];

            for (const reminderDoc of remindersSnapshot.docs) {
                const reminder = reminderDoc.data();
                const userId = reminder.userId;

                // Create notification for this user
                const notificationData = {
                    userId,
                    title: "Salon audio en direct",
                    body: `"${roomTitle}" est maintenant en direct avec ${hostName}`,
                    type: "audioRoomLive",
                    targetId: roomId,
                    data: {
                        roomId,
                        roomTitle,
                        hostName,
                    },
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                };

                promises.push(
                    admin.firestore().collection("notifications").add(notificationData)
                );

                // Mark reminder as sent
                promises.push(
                    reminderDoc.ref.update({
                        status: "sent",
                        sentAt: admin.firestore.FieldValue.serverTimestamp(),
                    })
                );
            }

            await Promise.all(promises);

            return { success: true, count: remindersSnapshot.size };
        } catch (error) {
            console.error("Error sending audio room live notifications:", error);
            return null;
        }
    });

/**
 * Triggered when a user is invited to an audio room.
 */
exports.onAudioRoomInviteCreated = functions.firestore
    .document("audioRooms/{roomId}/invites/{inviteId}")
    .onCreate(async (snapshot, context) => {
        try {
            const invite = snapshot.data();
            const roomId = context.params.roomId;
            const invitedUserId = invite.invitedUserId;
            const inviterName = invite.inviterName || "Quelqu'un";

            if (!invitedUserId) {
                return null;
            }

            // Get room details
            const roomDoc = await admin.firestore()
                .collection("audioRooms")
                .doc(roomId)
                .get();

            const roomTitle = roomDoc.exists ? roomDoc.data().title : "un salon audio";

            // Create notification
            await admin.firestore().collection("notifications").add({
                userId: invitedUserId,
                title: "Invitation salon audio",
                body: `${inviterName} vous invite à rejoindre "${roomTitle}"`,
                type: "audioRoomInvite",
                targetId: roomId,
                data: {
                    roomId,
                    roomTitle,
                    inviterName,
                },
                isRead: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            return { success: true };
        } catch (error) {
            console.error("Error sending audio room invite notification:", error);
            return null;
        }
    });

/**
 * Triggered when a transfer status changes.
 * Notifies sender/recipient of completion, failure, or receipt.
 */
exports.onTransferStatusChanged = functions.firestore
    .document("transfers/{transferId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        const transferId = context.params.transferId;

        // Only process status changes
        if (before.status === after.status) {
            return null;
        }

        const newStatus = after.status;
        const senderId = after.senderId;
        const recipientId = after.recipientId;
        const amount = after.amount || 0;
        const currency = after.currency || "FCFA";
        const recipientName = after.recipientName || "Destinataire";

        try {
            // Notify sender on completion or failure
            if (newStatus === "completed" || newStatus === "failed") {
                const title = newStatus === "completed" ? "Transfert effectué" : "Transfert échoué";
                const body = newStatus === "completed"
                    ? `Votre transfert de ${amount} ${currency} vers ${recipientName} a été effectué.`
                    : `Le transfert de ${amount} ${currency} vers ${recipientName} a échoué.`;

                await admin.firestore().collection("notifications").add({
                    userId: senderId,
                    title,
                    body,
                    type: newStatus === "completed" ? "transferCompleted" : "transferFailed",
                    targetId: transferId,
                    data: {
                        transferId,
                        amount: String(amount),
                        currency,
                        recipientName,
                    },
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }

            // Notify recipient on receipt
            if (newStatus === "completed" && recipientId) {
                const senderName = after.senderName || "Quelqu'un";

                await admin.firestore().collection("notifications").add({
                    userId: recipientId,
                    title: "Transfert reçu",
                    body: `Vous avez reçu ${amount} ${currency} de ${senderName}.`,
                    type: "transferReceived",
                    targetId: transferId,
                    data: {
                        transferId,
                        amount: String(amount),
                        currency,
                        senderName,
                    },
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }

            return { success: true };
        } catch (error) {
            console.error("Error sending transfer status notification:", error);
            return null;
        }
    });

/**
 * Daily scheduled function to send transfer reminders.
 * Runs every day at 9 AM (Africa/Niamey timezone) to check for recurring transfers
 * and create reminder notifications.
 */
exports.sendTransferReminders = functions.pubsub
    .schedule("every day 09:00")
    .timeZone("Africa/Niamey")
    .onRun(async (context) => {
        try {
            const now = new Date();
            const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
            const in3Days = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
            const in7Days = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

            // Get active recurring transfers
            const transfersSnapshot = await admin.firestore()
                .collection("recurringTransfers")
                .where("isActive", "==", true)
                .get();

            if (transfersSnapshot.empty) {
                return { success: true, count: 0 };
            }

            const promises = [];

            for (const transferDoc of transfersSnapshot.docs) {
                const transfer = transferDoc.data();
                const { userId, recipientName, amount, currency, nextDate, reminderDaysBefore } = transfer;

                if (!nextDate || !nextDate.toDate) {
                    continue;
                }

                const nextTransferDate = nextDate.toDate();
                const daysDiff = Math.ceil((nextTransferDate - now) / (24 * 60 * 60 * 1000));

                // Check if reminder should be sent based on reminderDaysBefore setting
                const reminderDays = reminderDaysBefore || 1; // Default to 1 day

                if (daysDiff === reminderDays) {
                    const notificationData = {
                        userId,
                        title: "Transfert à venir",
                        body: `Rappel: Transfert de ${amount} ${currency} vers ${recipientName} prévu ${daysDiff === 1 ? "demain" : `dans ${daysDiff} jours`}`,
                        type: "transferReminder",
                        targetId: transferDoc.id,
                        data: {
                            transferId: transferDoc.id,
                            amount: String(amount),
                            currency,
                            recipientName,
                        },
                        isRead: false,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    };

                    promises.push(
                        admin.firestore().collection("notifications").add(notificationData)
                    );
                }
            }

            await Promise.all(promises);

            return { success: true, count: promises.length };
        } catch (error) {
            console.error("Error sending transfer reminders:", error);
            return null;
        }
    });

/**
 * Stripe Payment Intent Handler
 *
 * This function watches for new documents in the 'payment_intents' collection
 * and creates a Stripe payment intent on the server side.
 *
 * IMPORTANT: Configure Stripe in functions/.env file:
 * STRIPE_SECRET_KEY=sk_test_YOUR_SECRET_KEY
 *
 * For production, use your live secret key:
 * STRIPE_SECRET_KEY=sk_live_YOUR_SECRET_KEY
 */

// Lazy load Stripe to avoid initialization errors if config is not set
let stripe = null;

function getStripe() {
    if (!stripe) {
        // Use environment variables (from .env file)
        const stripeSecretKey = process.env.STRIPE_SECRET_KEY;

        if (!stripeSecretKey) {
            throw new Error(
                "Stripe secret key not configured. " +
                "Add STRIPE_SECRET_KEY to your functions/.env file"
            );
        }

        const Stripe = require("stripe");
        stripe = new Stripe(stripeSecretKey, {
            apiVersion: "2023-10-16",
        });
    }
    return stripe;
}

exports.createStripePaymentIntent = functions.firestore
    .document("payment_intents/{intentId}")
    .onCreate(async (snapshot, context) => {
        const data = snapshot.data();
        const intentId = context.params.intentId;

        try {
            // Validate required fields
            if (!data.transactionId || !data.userId) {
                throw new Error("Missing required fields: transactionId or userId");
            }

            // C3 Security Fix: Derive amount/currency from the trusted transaction
            // document instead of trusting the client-provided values.
            let trustedAmount = data.amount;
            let trustedCurrency = data.currency;

            // Look up the authoritative transaction document
            const transactionRef = admin.firestore()
                .collection("transactions")
                .doc(data.transactionId);
            const transactionSnap = await transactionRef.get();

            if (transactionSnap.exists) {
                const txData = transactionSnap.data();
                // Override client values with trusted server-side values
                trustedAmount = txData.amount || trustedAmount;
                trustedCurrency = txData.currency || trustedCurrency;

                // Verify that the client userId matches the transaction owner
                if (txData.senderId && txData.senderId !== data.userId) {
                    throw new Error("User does not own this transaction");
                }
            } else {
                // Fallback: check marketplace orders
                const orderQuery = await admin.firestore()
                    .collection("orders")
                    .where("transactionId", "==", data.transactionId)
                    .limit(1)
                    .get();

                if (!orderQuery.empty) {
                    const orderData = orderQuery.docs[0].data();
                    trustedAmount = orderData.totalAmount || trustedAmount;
                    trustedCurrency = orderData.currency || trustedCurrency;

                    if (orderData.buyerId && orderData.buyerId !== data.userId) {
                        throw new Error("User does not own this order");
                    }
                }
                // If no transaction/order found, use client-provided values
                // with a maximum safety limit to prevent extreme manipulation
                if (trustedAmount > 10000000) {
                    throw new Error("Amount exceeds safety limit");
                }
            }

            // Validate required payment fields
            if (!trustedAmount || !trustedCurrency) {
                throw new Error("Missing required fields: amount or currency");
            }

            // C4 Idempotency: Check if a PaymentIntent already exists for this document
            if (data.paymentIntentId && data.status === "created") {
                // Already created — return existing
                return {
                    success: true,
                    paymentIntentId: data.paymentIntentId,
                };
            }

            // Get Stripe instance
            const stripeInstance = getStripe();

            // Create payment intent (skip ×100 for zero-decimal currencies like JPY/XOF)
            const piCurrency = trustedCurrency.toLowerCase();
            const piAmount = ZERO_DECIMAL_CURRENCIES.has(piCurrency)
                ? Math.round(trustedAmount)
                : Math.round(trustedAmount * 100);
            const paymentIntent = await stripeInstance.paymentIntents.create({
                amount: piAmount,
                currency: piCurrency,
                metadata: {
                    userId: data.userId,
                    transactionId: data.transactionId || "",
                    ...data.metadata,
                },
                automatic_payment_methods: {
                    enabled: true,
                },
            }, {
                idempotencyKey: `pi_${data.transactionId}`,
            });

            // Update the document with the payment intent details
            await snapshot.ref.update({
                status: "created",
                paymentIntentId: paymentIntent.id,
                clientSecret: paymentIntent.client_secret,
                // Store the server-validated amount for audit trail
                serverValidatedAmount: trustedAmount,
                serverValidatedCurrency: trustedCurrency,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            return {
                success: true,
                paymentIntentId: paymentIntent.id,
            };
        } catch (error) {
            // Update document with error status
            await snapshot.ref.update({
                status: "error",
                error: error.message,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            return {
                success: false,
                error: error.message,
            };
        }
    });

/**
 * Stripe Webhook Handler
 *
 * Handles Stripe webhook events for payment status updates.
 * This ensures your database stays in sync with Stripe's payment state.
 *
 * To configure the webhook:
 * 1. Go to https://dashboard.stripe.com/webhooks
 * 2. Add endpoint: https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/stripeWebhook
 * 3. Select events: payment_intent.succeeded, payment_intent.payment_failed
 * 4. Copy the webhook secret and add it to functions/.env:
 *    STRIPE_WEBHOOK_SECRET=whsec_...
 */
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
    const sig = req.headers["stripe-signature"];
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

    // Le test « absent » ne suffisait pas : la valeur déployée est le
    // placeholder livré avec .env.example, qui est parfaitement truthy. On
    // passait donc le garde pour aller échouer plus loin sur la vérification de
    // signature, avec un 400 indistinguable d'une vraie requête falsifiée —
    // Stripe réessaie, abandonne, et aucun paiement n'est jamais confirmé côté
    // serveur. Mieux vaut refuser tout de suite en le disant.
    if (!webhookSecret || isPlaceholderSecret(webhookSecret)) {
        console.error(
            "STRIPE_WEBHOOK_SECRET absent ou laissé au placeholder — " +
            "voir docs/ops/secrets_production.md"
        );
        return res.status(500).send("Webhook secret not configured");
    }

    let event;

    try {
        const stripeInstance = getStripe();
        event = stripeInstance.webhooks.constructEvent(
            req.rawBody,
            sig,
            webhookSecret
        );
    } catch (err) {
        // console.error("Webhook signature verification failed:", err.message);
        return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    // console.log(`Received webhook event: ${event.type}`);

    try {
        switch (event.type) {
            case "payment_intent.succeeded":
                await handlePaymentSuccess(event.data.object);
                break;

            case "payment_intent.payment_failed":
                await handlePaymentFailure(event.data.object);
                break;

            default:
                // console.log(`Unhandled event type: ${event.type}`);
        }

        res.json({ received: true });
    } catch (error) {
        // console.error("Error processing webhook:", error);
        res.status(500).send("Webhook processing error");
    }
});

/**
 * Handle successful payment
 *
 * Idempotent: only transitions transactions in "pending" or "debiting" states.
 * Re-deliveries from Stripe webhooks (INT-06) are ignored after first success.
 */
async function handlePaymentSuccess(paymentIntent) {
    const transactionId = paymentIntent.metadata.transactionId;
    const paymentType = paymentIntent.metadata.type;

    if (!transactionId) {
        return;
    }

    // Route to the correct handler based on payment type in metadata.
    // Tips, room tickets, and podcast subscriptions are stored in separate collections.
    if (paymentType === "tip") {
        return handleTipPaymentSuccess(transactionId, paymentIntent);
    }
    if (paymentType === "room_ticket") {
        return handleTicketPaymentSuccess(transactionId, paymentIntent);
    }


    // Default: money transfer transactions
    try {
        const txRef = admin.firestore().collection("transactions").doc(transactionId);

        // Idempotency guard: only advance from pending/debiting states
        await admin.firestore().runTransaction(async (tx) => {
            const txDoc = await tx.get(txRef);
            if (!txDoc.exists) {
                console.warn(`handlePaymentSuccess: transaction ${transactionId} not found`);
                return;
            }
            const txData = txDoc.data();
            const allowedStates = ["pending", "debiting"];
            if (!allowedStates.includes(txData.status)) {
                console.log(`handlePaymentSuccess: transaction ${transactionId} already in status=${txData.status}, skipping`);
                return;
            }
            tx.update(txRef, {
                status: "processing",
                paymentIntentId: paymentIntent.id,
                // Stripe API >= 2022-11-15 deprecated `charges.data[]`; use `latest_charge` instead.
                stripeChargeId: paymentIntent.latest_charge || null,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        });
    } catch (error) {
        console.error("handlePaymentSuccess error:", error);
    }
}

/**
 * Marks a tip as completed when Stripe confirms the payment.
 * This triggers the onTipCompleted function which credits the creator's balance.
 */
async function handleTipPaymentSuccess(tipId, paymentIntent) {
    const tipRef = admin.firestore().collection("tips").doc(tipId);
    try {
        await admin.firestore().runTransaction(async (tx) => {
            const tipDoc = await tx.get(tipRef);
            if (!tipDoc.exists) {
                console.warn(`handleTipPaymentSuccess: tip ${tipId} not found`);
                return;
            }
            if (tipDoc.data().status !== "pending") {
                console.log(`handleTipPaymentSuccess: tip ${tipId} already ${tipDoc.data().status}, skipping`);
                return;
            }
            tx.update(tipRef, {
                status: "completed",
                stripePaymentIntentId: paymentIntent.id,
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        });
        console.log(`handleTipPaymentSuccess: tip ${tipId} marked completed`);
    } catch (error) {
        console.error(`handleTipPaymentSuccess: error for tip ${tipId}:`, error);
    }
}

/**
 * Marks a room ticket as active when Stripe confirms the payment.
 * This triggers the onTicketActivated function which credits the seller's balance.
 */
async function handleTicketPaymentSuccess(ticketId, paymentIntent) {
    const ticketRef = admin.firestore().collection("roomTickets").doc(ticketId);
    try {
        await admin.firestore().runTransaction(async (tx) => {
            const ticketDoc = await tx.get(ticketRef);
            if (!ticketDoc.exists) {
                console.warn(`handleTicketPaymentSuccess: ticket ${ticketId} not found`);
                return;
            }
            if (ticketDoc.data().status !== "pending") {
                console.log(`handleTicketPaymentSuccess: ticket ${ticketId} already ${ticketDoc.data().status}, skipping`);
                return;
            }
            const ticketData = ticketDoc.data();
            tx.update(ticketRef, {
                status: "active",
                stripePaymentIntentId: paymentIntent.id,
                purchasedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            // Also grant access to the room
            if (ticketData.roomId && ticketData.buyerId) {
                const roomRef = admin.firestore().collection("audioRooms").doc(ticketData.roomId);
                tx.update(roomRef, {
                    allowedUserIds: admin.firestore.FieldValue.arrayUnion(ticketData.buyerId),
                });
            }
        });
        console.log(`handleTicketPaymentSuccess: ticket ${ticketId} marked active`);
    } catch (error) {
        console.error(`handleTicketPaymentSuccess: error for ticket ${ticketId}:`, error);
    }
}

/**
 * Handle failed payment
 *
 * Updates transaction status and creates an in-app notification for the user (INT-02).
 */
async function handlePaymentFailure(paymentIntent) {
    const transactionId = paymentIntent.metadata.transactionId;

    if (!transactionId) {
        return;
    }

    const failureReason = paymentIntent.last_payment_error?.message || "Payment failed";

    try {
        const db = admin.firestore();
        const txRef = db.collection("transactions").doc(transactionId);

        // Idempotency: only mark as failed if not already in a terminal state
        const txSnapshot = await txRef.get();
        if (!txSnapshot.exists) {
            console.warn(`handlePaymentFailure: transaction ${transactionId} not found`);
            return;
        }
        const txData = txSnapshot.data();
        if (txData.status === "failed" || txData.status === "completed") {
            console.log(`handlePaymentFailure: transaction ${transactionId} already terminal (${txData.status}), skipping`);
            return;
        }

        await txRef.update({
            status: "failed",
            paymentIntentId: paymentIntent.id,
            failureReason,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Notify the user that their payment failed (INT-02)
        if (txData.senderId) {
            await db.collection("notifications").add({
                userId: txData.senderId,
                type: "paymentFailed",
                title: "Paiement echoue",
                body: `Le paiement de votre transfert a echoue: ${failureReason}`,
                data: {
                    transactionId,
                    paymentIntentId: paymentIntent.id,
                },
                isRead: false,
                read: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
    } catch (error) {
        console.error("handlePaymentFailure error:", error);
    }
}

// ============================================================================
// MARKETPLACE: ORDER & PRODUCT QUANTITY MANAGEMENT
// ============================================================================

/**
 * Triggered when a new order is created.
 * Decrements the product quantity securely on the server side.
 */
exports.onOrderCreated = functions.firestore
    .document("orders/{orderId}")
    .onCreate(async (snapshot, context) => {
        const orderData = snapshot.data();
        const orderId = context.params.orderId;

        // console.log(`New order created: ${orderId}`);

        const { productId, quantity, sellerId, buyerId } = orderData;

        if (!productId || !quantity) {
            // console.error("Missing productId or quantity in order");
            return null;
        }

        try {
            const productRef = admin.firestore().collection("products").doc(productId);

            // Use a transaction to ensure atomic update
            await admin.firestore().runTransaction(async (transaction) => {
                const productDoc = await transaction.get(productRef);

                if (!productDoc.exists) {
                    throw new Error(`Product ${productId} not found`);
                }

                const productData = productDoc.data();
                const currentQuantity = productData.quantity || 0;

                if (currentQuantity < quantity) {
                    // Not enough stock - cancel the order
                    transaction.update(snapshot.ref, {
                        status: "cancelled",
                        cancellationReason: "Stock insuffisant",
                        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                    throw new Error(`Insufficient stock: requested ${quantity}, available ${currentQuantity}`);
                }

                // Decrement the quantity
                transaction.update(productRef, {
                    quantity: admin.firestore.FieldValue.increment(-quantity),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                // console.log(`Decremented product ${productId} quantity by ${quantity}`);
            });

            // Notify the seller about the new order
            const buyerDoc = await admin.firestore().collection("users").doc(buyerId).get();
            const buyerName = buyerDoc.exists ? (buyerDoc.data().displayName || "Un acheteur") : "Un acheteur";

            await admin.firestore().collection("notifications").add({
                userId: sellerId,
                title: "Nouvelle commande",
                body: `${buyerName} a passé une commande pour "${orderData.productTitle}"`,
                type: "order",
                targetId: orderId,
                data: {
                    orderId: orderId,
                    productId: productId,
                    buyerId: buyerId,
                },
                isRead: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            return { success: true };
        } catch (error) {
            // console.error("Error processing order creation:", error);
            return { success: false, error: error.message };
        }
    });

/**
 * Triggered when an order is updated.
 * Handles status changes, especially cancellations to restore product quantity.
 */
exports.onOrderUpdated = functions.firestore
    .document("orders/{orderId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        const orderId = context.params.orderId;

        // Check if status changed to cancelled
        if (before.status !== "cancelled" && after.status === "cancelled") {
            // console.log(`Order ${orderId} was cancelled, restoring product quantity`);

            const { productId, quantity, sellerId, buyerId } = after;

            if (!productId || !quantity) {
                // console.error("Missing productId or quantity in order");
                return null;
            }

            try {
                // Restore product quantity inside a transaction so we get a read-modify-write
                // guarantee even if other order updates race against this cancellation (BUG-28).
                const productRef = admin.firestore().collection("products").doc(productId);
                await admin.firestore().runTransaction(async (tx) => {
                    const productDoc = await tx.get(productRef);
                    if (!productDoc.exists) {
                        // Product was deleted in the meantime — nothing to restore
                        return;
                    }
                    tx.update(productRef, {
                        quantity: admin.firestore.FieldValue.increment(quantity),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                });

                // Notify the other party about the cancellation
                const cancelledBy = after.cancelledBy || (before.status === "pending" ? buyerId : sellerId);
                const otherPartyId = cancelledBy === buyerId ? sellerId : buyerId;

                const cancellerDoc = await admin.firestore().collection("users").doc(cancelledBy).get();
                const cancellerName = cancellerDoc.exists ?
                    (cancellerDoc.data().displayName || "L'utilisateur") : "L'utilisateur";

                await admin.firestore().collection("notifications").add({
                    userId: otherPartyId,
                    title: "Commande annulée",
                    body: `${cancellerName} a annulé la commande pour "${after.productTitle}"`,
                    type: "orderCancelled",
                    targetId: orderId,
                    data: {
                        orderId: orderId,
                        productId: productId,
                        reason: after.cancellationReason || "Aucune raison spécifiée",
                    },
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                return { success: true };
            } catch (error) {
                // console.error("Error restoring product quantity:", error);
                return { success: false, error: error.message };
            }
        }

        // Check if status changed to shipped
        if (before.status !== "shipped" && after.status === "shipped") {
            // console.log(`Order ${orderId} was shipped, notifying buyer`);

            await admin.firestore().collection("notifications").add({
                userId: after.buyerId,
                title: "Commande expédiée",
                body: `Votre commande "${after.productTitle}" a été expédiée${after.trackingNumber ? ` (Suivi: ${after.trackingNumber})` : ""}`,
                type: "orderShipped",
                targetId: orderId,
                data: {
                    orderId: orderId,
                    trackingNumber: after.trackingNumber || "",
                },
                isRead: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        // Check if status changed to delivered
        if (before.status !== "delivered" && after.status === "delivered") {
            // console.log(`Order ${orderId} was delivered, notifying seller`);

            await admin.firestore().collection("notifications").add({
                userId: after.sellerId,
                title: "Commande livrée",
                body: `L'acheteur a confirmé la réception de "${after.productTitle}"`,
                type: "orderDelivered",
                targetId: orderId,
                data: {
                    orderId: orderId,
                },
                isRead: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        // Check if status changed to completed (escrow released)
        if (before.status !== "completed" && after.status === "completed") {
            // console.log(`Order ${orderId} completed, escrow released`);

            await admin.firestore().collection("notifications").add({
                userId: after.sellerId,
                title: "Paiement libéré",
                body: `Le paiement pour "${after.productTitle}" a été libéré. Montant: ${after.sellerAmount} ${after.currency}`,
                type: "orderCompleted",
                targetId: orderId,
                data: {
                    orderId: orderId,
                    amount: String(after.sellerAmount),
                    currency: after.currency,
                },
                isRead: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        return null;
    });

/**
 * Triggered when a new event is created.
 * Sends push notifications to users in the same city/country who have enabled local events notifications.
 */
exports.notifyLocalEventCreated = functions.firestore
    .document("events/{eventId}")
    .onCreate(async (snapshot, context) => {
        const eventData = snapshot.data();
        const eventId = context.params.eventId;

        // console.log(`New event created: ${eventId} - ${eventData.title}`);

        const eventCity = eventData.city || eventData.location?.city;
        const eventCountry = eventData.country || eventData.location?.country;
        const organizerId = eventData.organizerId;

        if (!eventCity && !eventCountry) {
            // console.log("Event has no location info, skipping local notifications");
            return null;
        }

        try {
            // Find users in the same city or country who want local event notifications
            let usersQuery = admin.firestore().collection("users")
                .where("notifyLocalEvents", "==", true);

            // Add location filter - prefer city if available, otherwise country
            if (eventCity) {
                usersQuery = usersQuery.where("currentCity", "==", eventCity);
            } else if (eventCountry) {
                usersQuery = usersQuery.where("currentCountry", "==", eventCountry);
            }

            const usersSnapshot = await usersQuery.get();

            // console.log(`Found ${usersSnapshot.size} users in the same location`);

            if (usersSnapshot.empty) {
                return null;
            }

            const promises = [];
            let notificationCount = 0;

            for (const userDoc of usersSnapshot.docs) {
                const userId = userDoc.id;

                // Skip the event organizer
                if (userId === organizerId) {
                    continue;
                }

                const userData = userDoc.data();

                // Double-check notifications are enabled
                if (userData.notificationsEnabled === false) {
                    continue;
                }

                notificationCount++;

                // Create notification document
                const notificationData = {
                    userId: userId,
                    title: "Nouvel événement dans votre ville",
                    body: `"${eventData.title}" - ${eventCity || eventCountry}`,
                    type: "localEvent",
                    targetId: eventId,
                    data: {
                        eventId: eventId,
                        eventTitle: eventData.title,
                        city: eventCity || "",
                        country: eventCountry || "",
                    },
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                };

                // This will trigger sendNotificationOnCreate
                promises.push(
                    admin.firestore().collection("notifications").add(notificationData)
                );
            }

            await Promise.all(promises);
            // console.log(`Created ${notificationCount} local event notifications`);

            return { success: true, count: notificationCount };
        } catch (error) {
            // console.error("Error sending local event notifications:", error);
            return null;
        }
    });

// ============================================================================
// USER DATA CLEANUP ON ACCOUNT DELETION
// ============================================================================

/**
 * Triggered when a user account is deleted from Firebase Auth.
 * Cleans up ALL user data across Firestore, Realtime Database, and Storage.
 *
 * This ensures GDPR compliance (right to be forgotten) and prevents orphaned data.
 */
exports.cleanupUserData = functions.auth.user().onDelete(async (user) => {
    const userId = user.uid;
    const userEmail = user.email || "unknown";

    console.log(`Starting cleanup for deleted user: ${userId} (${userEmail})`);

    const db = admin.firestore();
    const rtdb = admin.database();
    const storage = admin.storage().bucket();

    const results = {
        firestore: { deleted: 0, updated: 0, errors: [] },
        realtimeDb: { deleted: 0, errors: [] },
        storage: { deleted: 0, errors: [] },
    };

    try {
        // ================================================================
        // 0. AUDIT LOG - Conserver les statistiques pour l'admin
        // ================================================================

        const userDocRef = db.collection("users").doc(userId);
        const userDoc = await userDocRef.get();
        const profileDocRef = db.collection("profiles").doc(userId);
        const profileDoc = await profileDocRef.get();

        // Collecter les statistiques avant suppression
        const [
            userOrders,
            userProducts,
            userBusinesses,
            userTransactions,
            userEvents,
        ] = await Promise.all([
            db.collection("orders").where("sellerId", "==", userId).get(),
            db.collection("products").where("sellerId", "==", userId).get(),
            db.collection("businesses").where("ownerId", "==", userId).get(),
            db.collection("transactions").where("senderId", "==", userId).get(),
            db.collection("events").where("organizerId", "==", userId).get(),
        ]);

        // Calculer le total des ventes
        let totalSales = 0;
        userOrders.docs.forEach((doc) => {
            const order = doc.data();
            if (order.status === "completed") {
                totalSales += order.totalPrice || 0;
            }
        });

        // Créer le log d'audit pour l'admin
        const auditData = {
            eventType: "user_deleted",
            userId: userId,
            userEmail: userEmail,
            deletedAt: admin.firestore.FieldValue.serverTimestamp(),
            // Données anonymisées pour statistiques
            userStats: {
                displayName: userDoc.exists ? (userDoc.data().displayName || "N/A") : "N/A",
                createdAt: userDoc.exists ? userDoc.data().createdAt : null,
                lastLoginAt: userDoc.exists ? userDoc.data().lastLoginAt : null,
                // Localisation (pour stats géographiques)
                country: profileDoc.exists ? (profileDoc.data().currentCountry || "N/A") : "N/A",
                region: profileDoc.exists ? (profileDoc.data().originRegion || "N/A") : "N/A",
            },
            activityStats: {
                totalOrders: userOrders.size,
                totalSales: totalSales,
                totalProducts: userProducts.size,
                totalBusinesses: userBusinesses.size,
                totalTransactionsSent: userTransactions.size,
                totalEventsOrganized: userEvents.size,
            },
            // Ces données permettent de garder les KPIs corrects
            wasAdmin: userDoc.exists ? (userDoc.data().adminRole !== "none") : false,
            wasBanned: userDoc.exists ? (userDoc.data().isBanned || false) : false,
        };

        await db.collection("admin_audit_logs").add(auditData);
        console.log(`Audit log created for deleted user: ${userId}`);

        // ================================================================
        // 1. FIRESTORE CLEANUP
        // ================================================================

        if (userDoc.exists) {
            // Delete subcollections: friends, blocked_users, cart, sessions
            const subcollections = ["friends", "blocked_users", "cart", "sessions"];
            for (const subcol of subcollections) {
                const subcolDocs = await userDocRef.collection(subcol).get();

                // Une amitie est symetrique : `acceptFriendRequest` ecrit
                // `users/A/friends/B` ET `users/B/friends/A`. Ne supprimer que
                // la liste du compte efface laisse donc une entree miroir chez
                // chacun de ses anciens amis — et c'est CETTE sous-collection
                // que l'app lit (`getFriends`, `areFriends`), pas le tableau
                // `friendIds` nettoye plus bas. Sans ca, le compte supprime
                // reste indefiniment dans la liste d'amis des autres, avec son
                // nom et sa photo, et `areFriends` repond toujours « oui ».
                //
                // On passe par la liste du compte lui-meme plutot que par une
                // requete de groupe de collections : c'est exactement
                // l'ensemble des personnes ayant une entree miroir, et ca
                // n'exige aucun index supplementaire.
                if (subcol === "friends" && !subcolDocs.empty) {
                    const miroir = db.batch();
                    subcolDocs.docs.forEach((doc) => {
                        miroir.delete(
                            db.collection("users").doc(doc.id)
                                .collection("friends").doc(userId),
                        );
                    });
                    await miroir.commit();
                    results.firestore.deleted += subcolDocs.size;
                }

                const batch = db.batch();
                subcolDocs.docs.forEach((doc) => batch.delete(doc.ref));
                if (!subcolDocs.empty) {
                    await batch.commit();
                    results.firestore.deleted += subcolDocs.size;
                }
            }
            await userDocRef.delete();
            results.firestore.deleted++;
        }

        // 1.2 Delete profile document
        if (profileDoc.exists) {
            await profileDocRef.delete();
            results.firestore.deleted++;
        }

        // 1.3 Delete friend requests (sent and received)
        const sentRequests = await db.collection("friend_requests")
            .where("senderId", "==", userId).get();
        const receivedRequests = await db.collection("friend_requests")
            .where("receiverId", "==", userId).get();

        for (const doc of [...sentRequests.docs, ...receivedRequests.docs]) {
            await doc.ref.delete();
            results.firestore.deleted++;
        }

        // 1.4 Remove user from other users' friend lists (blockedByUserIds, friendIds)
        const usersWithFriend = await db.collection("users")
            .where("friendIds", "array-contains", userId).get();
        for (const doc of usersWithFriend.docs) {
            await doc.ref.update({
                friendIds: admin.firestore.FieldValue.arrayRemove(userId),
            });
            results.firestore.updated++;
        }

        // 1.5 Delete notifications
        const notifications = await db.collection("notifications")
            .where("userId", "==", userId).get();
        for (const doc of notifications.docs) {
            await doc.ref.delete();
            results.firestore.deleted++;
        }

        // 1.6 Handle conversations
        const conversations = await db.collection("conversations")
            .where("participantIds", "array-contains", userId).get();

        for (const convDoc of conversations.docs) {
            const convData = convDoc.data();
            const participantIds = convData.participantIds || [];

            if (participantIds.length <= 2) {
                // Individual conversation - delete entirely
                // First delete messages subcollection
                const messages = await convDoc.ref.collection("messages").get();
                for (const msgDoc of messages.docs) {
                    await msgDoc.ref.delete();
                    results.firestore.deleted++;
                }
                await convDoc.ref.delete();
                results.firestore.deleted++;
            } else {
                // Group conversation - just remove user
                await convDoc.ref.update({
                    participantIds: admin.firestore.FieldValue.arrayRemove(userId),
                    adminIds: admin.firestore.FieldValue.arrayRemove(userId),
                });
                results.firestore.updated++;
            }
        }

        // 1.7 Handle groups
        const memberGroups = await db.collection("groups")
            .where("memberIds", "array-contains", userId).get();

        for (const groupDoc of memberGroups.docs) {
            const groupData = groupDoc.data();
            const isCreator = groupData.creatorId === userId;
            const memberCount = (groupData.memberIds || []).length;

            if (isCreator && memberCount <= 1) {
                // Creator is leaving and no other members - delete group
                await groupDoc.ref.delete();
                results.firestore.deleted++;
            } else {
                // Just remove user from group
                await groupDoc.ref.update({
                    memberIds: admin.firestore.FieldValue.arrayRemove(userId),
                    adminIds: admin.firestore.FieldValue.arrayRemove(userId),
                });
                results.firestore.updated++;
            }
        }

        // 1.8 Delete group requests and invites
        const groupRequests = await db.collection("group_requests")
            .where("requesterId", "==", userId).get();
        const groupInvites = await db.collection("group_invites")
            .where("inviteeId", "==", userId).get();

        for (const doc of [...groupRequests.docs, ...groupInvites.docs]) {
            await doc.ref.delete();
            results.firestore.deleted++;
        }

        // 1.9 Handle events
        const organizedEvents = await db.collection("events")
            .where("organizerId", "==", userId).get();
        const attendingEvents = await db.collection("events")
            .where("attendeeIds", "array-contains", userId).get();

        for (const eventDoc of organizedEvents.docs) {
            await eventDoc.ref.delete();
            results.firestore.deleted++;
        }

        for (const eventDoc of attendingEvents.docs) {
            if (eventDoc.data().organizerId !== userId) {
                await eventDoc.ref.update({
                    attendeeIds: admin.firestore.FieldValue.arrayRemove(userId),
                });
                results.firestore.updated++;
            }
        }

        // 1.10 Delete products (marketplace)
        const products = await db.collection("products")
            .where("sellerId", "==", userId).get();
        for (const doc of products.docs) {
            await doc.ref.delete();
            results.firestore.deleted++;
        }

        // 1.11 Handle orders (keep for record but anonymize)
        const buyerOrders = await db.collection("orders")
            .where("buyerId", "==", userId).get();
        const sellerOrders = await db.collection("orders")
            .where("sellerId", "==", userId).get();

        for (const doc of buyerOrders.docs) {
            await doc.ref.update({ buyerId: "deleted_user", buyerName: "Utilisateur supprimé" });
            results.firestore.updated++;
        }
        for (const doc of sellerOrders.docs) {
            await doc.ref.update({ sellerId: "deleted_user", sellerName: "Utilisateur supprimé" });
            results.firestore.updated++;
        }

        // 1.12 Delete businesses and related data
        const businesses = await db.collection("businesses")
            .where("ownerId", "==", userId).get();

        for (const bizDoc of businesses.docs) {
            const bizId = bizDoc.id;

            // Delete business posts
            const posts = await db.collection("business_posts")
                .where("businessId", "==", bizId).get();
            for (const postDoc of posts.docs) {
                await postDoc.ref.delete();
                results.firestore.deleted++;
            }

            // Delete business boosts
            const boosts = await db.collection("business_boosts")
                .where("businessId", "==", bizId).get();
            for (const boostDoc of boosts.docs) {
                await boostDoc.ref.delete();
                results.firestore.deleted++;
            }

            await bizDoc.ref.delete();
            results.firestore.deleted++;
        }

        // 1.13 Delete business reviews written by user
        const reviews = await db.collection("business_reviews")
            .where("reviewerId", "==", userId).get();
        for (const doc of reviews.docs) {
            await doc.ref.delete();
            results.firestore.deleted++;
        }

        // 1.14 Handle transactions (anonymize for financial records)
        const sentTransactions = await db.collection("transactions")
            .where("senderId", "==", userId).get();
        const receivedTransactions = await db.collection("transactions")
            .where("receiverId", "==", userId).get();

        for (const doc of sentTransactions.docs) {
            await doc.ref.update({ senderId: "deleted_user", senderName: "Utilisateur supprimé" });
            results.firestore.updated++;
        }
        for (const doc of receivedTransactions.docs) {
            await doc.ref.update({ receiverId: "deleted_user", receiverName: "Utilisateur supprimé" });
            results.firestore.updated++;
        }

        // 1.15 Delete saved recipients
        const recipients = await db.collection("recipients")
            .where("userId", "==", userId).get();
        for (const doc of recipients.docs) {
            await doc.ref.delete();
            results.firestore.deleted++;
        }

        // 1.16 Delete payment intents
        const paymentIntents = await db.collection("payment_intents")
            .where("userId", "==", userId).get();
        for (const doc of paymentIntents.docs) {
            await doc.ref.delete();
            results.firestore.deleted++;
        }

        // 1.17 Delete reports created by user
        const reports = await db.collection("reports")
            .where("reporterId", "==", userId).get();
        for (const doc of reports.docs) {
            await doc.ref.delete();
            results.firestore.deleted++;
        }

        // ================================================================
        // 2. REALTIME DATABASE CLEANUP
        // ================================================================

        try {
            // 2.1 Delete presence data
            await rtdb.ref(`presence/${userId}`).remove();
            results.realtimeDb.deleted++;

            // 2.2 Delete all RTDB chat messages sent by this user (GDPR)
            const convSnap = await db.collection("conversations")
                .where("participantIds", "array-contains", userId).get();
            for (const convDoc of convSnap.docs) {
                const convId = convDoc.id;
                const msgSnap = await rtdb.ref(`messages/${convId}`)
                    .orderByChild("senderId").equalTo(userId).once("value");
                if (msgSnap.exists()) {
                    const updates = {};
                    msgSnap.forEach((child) => { updates[child.key] = null; });
                    await rtdb.ref(`messages/${convId}`).update(updates);
                    results.realtimeDb.deleted += Object.keys(updates).length;
                }
            }

            // 2.3 Delete typing indicators (transient — cleaned up naturally)
        } catch (rtdbError) {
            results.realtimeDb.errors.push(rtdbError.message);
        }

        // ================================================================
        // 3. FIREBASE STORAGE CLEANUP
        // ================================================================

        try {
            // 3.1 Delete profile photos
            const [profileFiles] = await storage.getFiles({ prefix: `profiles/${userId}/` });
            for (const file of profileFiles) {
                await file.delete();
                results.storage.deleted++;
            }
        } catch (storageError) {
            // Storage might not have files for this user
            if (!storageError.message.includes("No such object")) {
                results.storage.errors.push(storageError.message);
            }
        }

        // ================================================================
        // 4. LOG CLEANUP RESULTS
        // ================================================================

        console.log(`Cleanup completed for user ${userId}:`, {
            firestoreDeleted: results.firestore.deleted,
            firestoreUpdated: results.firestore.updated,
            realtimeDbDeleted: results.realtimeDb.deleted,
            storageDeleted: results.storage.deleted,
            errors: [
                ...results.firestore.errors,
                ...results.realtimeDb.errors,
                ...results.storage.errors,
            ],
        });

        return { success: true, results };

    } catch (error) {
        console.error(`Error cleaning up user ${userId}:`, error);
        return { success: false, error: error.message, partialResults: results };
    }
});

// ============================================================================
// BUSINESS REVIEWS: RATING AGGREGATION
// ============================================================================

/**
 * Helper function to recalculate business rating from all reviews.
 * @param {string} businessId - The ID of the business to update
 */
async function recalculateBusinessRating(businessId) {
    const db = admin.firestore();

    const reviewsSnapshot = await db.collection("business_reviews")
        .where("businessId", "==", businessId)
        .where("status", "==", "published")
        .get();

    let totalRating = 0;
    let reviewCount = 0;

    reviewsSnapshot.docs.forEach((doc) => {
        const review = doc.data();
        if (review.rating) {
            totalRating += review.rating;
            reviewCount++;
        }
    });

    const averageRating = reviewCount > 0
        ? Math.round((totalRating / reviewCount) * 10) / 10
        : 0;

    await db.collection("businesses").doc(businessId).update({
        averageRating: averageRating,
        reviewCount: reviewCount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Updated business ${businessId}: ${averageRating} rating, ${reviewCount} reviews`);
}

/**
 * Triggered when a new review is created.
 * Updates the business's averageRating and reviewCount.
 */
exports.onReviewCreated = functions.firestore
    .document("business_reviews/{reviewId}")
    .onCreate(async (snapshot, context) => {
        const review = snapshot.data();
        const businessId = review.businessId;

        if (!businessId) {
            console.log("No businessId in review");
            return null;
        }

        try {
            await recalculateBusinessRating(businessId);
            return { success: true };
        } catch (error) {
            console.error("Error updating business rating on create:", error);
            return { success: false, error: error.message };
        }
    });

/**
 * Triggered when a review is updated.
 * Recalculates the business rating if the rating changed.
 */
exports.onReviewUpdated = functions.firestore
    .document("business_reviews/{reviewId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();

        // Only recalculate if rating or status changed
        if (before.rating === after.rating && before.status === after.status) {
            return null;
        }

        const businessId = after.businessId;

        if (!businessId) {
            console.log("No businessId in review");
            return null;
        }

        try {
            await recalculateBusinessRating(businessId);
            return { success: true };
        } catch (error) {
            console.error("Error updating business rating on update:", error);
            return { success: false, error: error.message };
        }
    });

/**
 * Triggered when a review is deleted.
 * Recalculates the business rating.
 */
exports.onReviewDeleted = functions.firestore
    .document("business_reviews/{reviewId}")
    .onDelete(async (snapshot, context) => {
        const review = snapshot.data();
        const businessId = review.businessId;

        if (!businessId) {
            console.log("No businessId in review");
            return null;
        }

        try {
            await recalculateBusinessRating(businessId);
            return { success: true };
        } catch (error) {
            console.error("Error updating business rating on delete:", error);
            return { success: false, error: error.message };
        }
    });

// ============================================================================
// STRIPE CONNECT - CREATOR PAYOUTS
// ============================================================================

/**
 * Handle Stripe Connect requests.
 *
 * This function watches for new documents in 'stripe_connect_requests'
 * and processes them accordingly (create account, create account link, etc.)
 *
 * IMPORTANT: Configure Stripe secret key in functions/.env:
 * STRIPE_SECRET_KEY=sk_test_YOUR_SECRET_KEY
 */
exports.processStripeConnectRequest = functions.firestore
    .document("stripe_connect_requests/{requestId}")
    .onCreate(async (snapshot, context) => {
        const data = snapshot.data();
        const requestId = context.params.requestId;

        console.log(`Processing Stripe Connect request: ${requestId}, type: ${data.type}`);

        try {
            const stripeInstance = getStripe();
            let result = {};

            switch (data.type) {
                case "create_account": {
                    // Create a new Stripe Connect Express account
                    const account = await stripeInstance.accounts.create({
                        type: "express",
                        country: data.country || "NE",
                        email: data.email,
                        business_type: data.businessType || "individual",
                        capabilities: {
                            transfers: { requested: true },
                        },
                        metadata: {
                            userId: data.userId,
                        },
                    });

                    result = {
                        accountId: account.id,
                        status: "incomplete",
                    };

                    console.log(`Created Connect account: ${account.id} for user ${data.userId}`);
                    break;
                }

                case "create_account_link": {
                    // Verify the accountId belongs to the requesting user
                    const ownerAccountId = await resolveSellerStripeAccountId(data.userId);
                    if (!ownerAccountId || ownerAccountId !== data.accountId) {
                        throw new Error("accountId does not belong to the requesting user");
                    }
                    // Create onboarding link for account setup
                    const accountLink = await stripeInstance.accountLinks.create({
                        account: data.accountId,
                        refresh_url: data.refreshUrl || "diasponiger://stripe-connect/refresh",
                        return_url: data.returnUrl || "diasponiger://stripe-connect/return",
                        type: "account_onboarding",
                    });

                    result = {
                        url: accountLink.url,
                        expiresAt: accountLink.expires_at,
                    };

                    console.log(`Created account link for: ${data.accountId}`);
                    break;
                }

                case "create_login_link": {
                    // Verify the accountId belongs to the requesting user
                    const ownerAccountIdLogin = await resolveSellerStripeAccountId(data.userId);
                    if (!ownerAccountIdLogin || ownerAccountIdLogin !== data.accountId) {
                        throw new Error("accountId does not belong to the requesting user");
                    }
                    // Create Express dashboard login link
                    const loginLink = await stripeInstance.accounts.createLoginLink(
                        data.accountId
                    );

                    result = {
                        url: loginLink.url,
                    };

                    console.log(`Created login link for: ${data.accountId}`);
                    break;
                }

                case "get_account_status": {
                    // Verify the accountId belongs to the requesting user
                    const ownerAccountIdStatus = await resolveSellerStripeAccountId(data.userId);
                    if (!ownerAccountIdStatus || ownerAccountIdStatus !== data.accountId) {
                        throw new Error("accountId does not belong to the requesting user");
                    }
                    // Retrieve account details
                    const account = await stripeInstance.accounts.retrieve(data.accountId);

                    result = {
                        chargesEnabled: account.charges_enabled,
                        payoutsEnabled: account.payouts_enabled,
                        detailsSubmitted: account.details_submitted,
                        status: account.details_submitted
                            ? (account.charges_enabled && account.payouts_enabled ? "enabled" : "restricted")
                            : "incomplete",
                        currentlyDue: account.requirements?.currently_due || [],
                        eventuallyDue: account.requirements?.eventually_due || [],
                        errors: account.requirements?.errors?.map((e) => e.reason) || [],
                        defaultCurrency: account.default_currency,
                        country: account.country,
                        businessType: account.business_type,
                    };

                    // Get external account info if available
                    if (account.external_accounts?.data?.length > 0) {
                        const extAccount = account.external_accounts.data[0];
                        result.externalAccountLast4 = extAccount.last4;
                        result.externalAccountBankName = extAccount.bank_name;
                    }

                    console.log(`Retrieved account status for: ${data.accountId}`);
                    break;
                }

                default:
                    throw new Error(`Unknown request type: ${data.type}`);
            }

            // Update document with result
            await snapshot.ref.update({
                status: "completed",
                result: result,
                completedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            return { success: true, result };

        } catch (error) {
            console.error("Error processing Connect request:", error);

            await snapshot.ref.update({
                status: "error",
                error: error.message,
                completedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            return { success: false, error: error.message };
        }
    });

/**
 * Process payout requests.
 *
 * When a payout document is created with status 'pending',
 * this function creates a Stripe Transfer to the creator's Connect account.
 *
 * The payout flow:
 * 1. User requests payout (creates document with status 'pending')
 * 2. This function creates a Stripe Transfer to their Connect account
 * 3. Stripe automatically pays out to their bank (based on payout schedule)
 */
exports.processPayoutRequest = functions.firestore
    .document("payouts/{payoutId}")
    .onCreate(async (snapshot, context) => {
        const data = snapshot.data();
        const payoutId = context.params.payoutId;

        console.log(`Processing payout request: ${payoutId}`);

        try {
            const stripeInstance = getStripe();
            const db = admin.firestore();

            // Atomically claim this payout: pending → processing.
            // Prevents double-transfers when Firebase retries the function.
            try {
                await db.runTransaction(async (tx) => {
                    const doc = await tx.get(snapshot.ref);
                    if (doc.data().status !== "pending") {
                        throw Object.assign(new Error(`Payout ${payoutId} status is ${doc.data().status}, expected 'pending'`), { bailCode: "already_processed" });
                    }
                    tx.update(snapshot.ref, {
                        status: "processing",
                        processedAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                });
            } catch (txErr) {
                if (txErr.bailCode === "already_processed") {
                    console.log(`Payout ${payoutId} already processed, skipping`);
                    return null;
                }
                throw txErr;
            }

            // Resolve stripeAccountId server-side — never trust client-supplied value
            const resolvedStripeAccountId = await resolveSellerStripeAccountId(data.creatorId);
            if (!resolvedStripeAccountId) {
                throw new Error("No Stripe Connect account found for this creator");
            }

            // Validate requested amount against server-side available balance
            const creatorDoc = await db.collection("creatorProfiles").doc(data.creatorId).get();
            if (!creatorDoc.exists) {
                throw new Error("Creator profile not found");
            }
            const availableBalance = creatorDoc.data().availableBalance || 0;
            if (data.amount <= 0 || data.amount > availableBalance) {
                throw new Error(`Requested amount ${data.amount} exceeds available balance ${availableBalance}`);
            }

            // Verify the Connect account is enabled
            const account = await stripeInstance.accounts.retrieve(resolvedStripeAccountId);

            if (!account.payouts_enabled) {
                throw new Error("Le compte Stripe Connect n'est pas encore activé pour les paiements");
            }

            // Create a transfer to the Connect account
            const transfer = await stripeInstance.transfers.create({
                amount: data.amount,
                currency: data.currency.toLowerCase(),
                destination: resolvedStripeAccountId,
                metadata: {
                    payoutId: payoutId,
                    creatorId: data.creatorId,
                },
            });

            console.log(`Transfer created: ${transfer.id} for payout ${payoutId}`);

            // Calculate estimated arrival (typically 2-7 business days)
            const estimatedArrival = new Date();
            estimatedArrival.setDate(estimatedArrival.getDate() + 5);

            // Update payout with transfer info
            await snapshot.ref.update({
                status: "completed",
                stripeTransferId: transfer.id,
                completedAt: admin.firestore.FieldValue.serverTimestamp(),
                estimatedArrival: admin.firestore.Timestamp.fromDate(estimatedArrival),
            });

            // Create notification for the creator
            await db.collection("notifications").add({
                userId: data.creatorId,
                title: "Paiement en cours",
                body: `Votre retrait de ${ZERO_DECIMAL_CURRENCIES.has((data.currency || "").toLowerCase()) ? data.amount : data.amount / 100} ${data.currency} est en cours de traitement`,
                type: "payout",
                targetId: payoutId,
                data: {
                    payoutId: payoutId,
                    amount: String(data.amount),
                    currency: data.currency,
                },
                isRead: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`Payout ${payoutId} completed successfully`);

            return { success: true, transferId: transfer.id };

        } catch (error) {
            console.error("Error processing payout:", error);

            const db = admin.firestore();

            // Update payout with error
            await snapshot.ref.update({
                status: "failed",
                errorMessage: error.message,
                failedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Restore the creator's balance
            await db.collection("creatorProfiles").doc(data.creatorId).update({
                availableBalance: admin.firestore.FieldValue.increment(data.amount),
            });

            // Notify the creator of the failure
            await db.collection("notifications").add({
                userId: data.creatorId,
                title: "Échec du paiement",
                body: `Votre retrait de ${data.amount / 100} ${data.currency} a échoué: ${error.message}`,
                type: "payout_failed",
                targetId: context.params.payoutId,
                data: {
                    payoutId: context.params.payoutId,
                    error: error.message,
                },
                isRead: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            return { success: false, error: error.message };
        }
    });

// ============================================================================
// LEGAL CONTENT MANAGEMENT
// ============================================================================

const legalSeedData = require("./legal_seed_data");

/**
 * Seed or update legal content in Firestore.
 *
 * This function can be called via HTTP or from the admin panel.
 * It deploys the legal documents (Terms, Privacy Policy, Code of Conduct)
 * to the legal_content collection.
 *
 * Usage (CLI):
 * firebase functions:call seedLegalContent --data '{"force": true}'
 *
 * Or via HTTP (admin only):
 * POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/seedLegalContent
 */
exports.seedLegalContent = functions.https.onCall(async (data, context) => {
    // Require admin authentication
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "User must be authenticated"
        );
    }

    // Check if user is admin
    const userDoc = await admin.firestore().collection("users").doc(context.auth.uid).get();
    if (!userDoc.exists || !userDoc.data().adminRole || userDoc.data().adminRole === "none") {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Only admins can seed legal content"
        );
    }

    const force = data?.force === true;
    const results = {
        terms: null,
        privacy: null,
        conduct: null,
    };

    const db = admin.firestore();
    const batch = db.batch();

    try {
        for (const [docId, content] of Object.entries(legalSeedData)) {
            const docRef = db.collection("legal_content").doc(docId);
            const existingDoc = await docRef.get();

            // Check if we should update
            if (existingDoc.exists && !force) {
                const existingVersion = existingDoc.data().version;
                if (existingVersion === content.version) {
                    results[docId] = {
                        status: "skipped",
                        reason: `Version ${content.version} already exists`,
                    };
                    continue;
                }
            }

            // Prepare document data
            const docData = {
                ...content,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };

            batch.set(docRef, docData);
            results[docId] = {
                status: "updated",
                version: content.version,
            };
        }

        await batch.commit();

        console.log("Legal content seeded successfully:", results);

        return {
            success: true,
            results: results,
            timestamp: new Date().toISOString(),
        };

    } catch (error) {
        console.error("Error seeding legal content:", error);
        throw new functions.https.HttpsError(
            "internal",
            `Failed to seed legal content: ${error.message}`
        );
    }
});

/**
 * HTTP endpoint to seed legal content (for initial deployment or web admin).
 *
 * Requires an admin API key in the Authorization header.
 */
exports.seedLegalContentHttp = functions.https.onRequest(async (req, res) => {
    // Only allow POST requests
    if (req.method !== "POST") {
        return res.status(405).send("Method Not Allowed");
    }

    // Check for admin API key (simple auth for deployment scripts)
    const adminKey = process.env.ADMIN_API_KEY;
    const providedKey = req.headers.authorization?.replace("Bearer ", "");

    if (!adminKey || providedKey !== adminKey) {
        return res.status(401).json({ error: "Unauthorized" });
    }

    // Security: simple rate limiting for admin API endpoint
    const rateLimitDoc = admin.firestore().collection("_rate_limits").doc("seedLegalContent");
    const rateLimitSnap = await rateLimitDoc.get();
    const now = Date.now();
    if (rateLimitSnap.exists) {
      const lastCall = rateLimitSnap.data().lastCallAt || 0;
      if (now - lastCall < 60000) { // 1 minute cooldown
        return res.status(429).json({ error: "Too many requests. Try again later." });
      }
    }
    await rateLimitDoc.set({ lastCallAt: now }, { merge: true });

    const force = req.body?.force === true;
    const results = {};

    const db = admin.firestore();
    const batch = db.batch();

    try {
        for (const [docId, content] of Object.entries(legalSeedData)) {
            const docRef = db.collection("legal_content").doc(docId);
            const existingDoc = await docRef.get();

            // Check if we should update
            if (existingDoc.exists && !force) {
                const existingVersion = existingDoc.data().version;
                if (existingVersion === content.version) {
                    results[docId] = {
                        status: "skipped",
                        reason: `Version ${content.version} already exists`,
                    };
                    continue;
                }
            }

            // Prepare document data
            const docData = {
                ...content,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };

            batch.set(docRef, docData);
            results[docId] = {
                status: "updated",
                version: content.version,
            };
        }

        await batch.commit();

        console.log("Legal content seeded via HTTP:", results);

        res.json({
            success: true,
            results: results,
            timestamp: new Date().toISOString(),
        });

    } catch (error) {
        console.error("Error seeding legal content:", error);
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

/**
 * Get legal content by type.
 * Public endpoint for web display.
 */
exports.getLegalContent = functions.https.onRequest(async (req, res) => {
    // Enable CORS
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
        return res.status(204).send("");
    }

    if (req.method !== "GET") {
        return res.status(405).send("Method Not Allowed");
    }

    const type = req.query.type;

    if (!type || !["terms", "privacy", "conduct"].includes(type)) {
        return res.status(400).json({
            error: "Invalid type. Must be one of: terms, privacy, conduct",
        });
    }

    try {
        const doc = await admin.firestore()
            .collection("legal_content")
            .doc(type)
            .get();

        if (!doc.exists) {
            return res.status(404).json({ error: "Document not found" });
        }

        const data = doc.data();

        // Format response for web
        res.json({
            id: data.id,
            type: data.type,
            title: data.title,
            version: data.version,
            updatedAt: data.updatedAt?.toDate?.()?.toISOString() || null,
            sections: data.sections.map((s) => ({
                title: s.title,
                content: s.content,
            })),
        });

    } catch (error) {
        console.error("Error fetching legal content:", error);
        res.status(500).json({ error: "Internal server error" });
    }
});

/**
 * Stripe Connect Webhook Handler
 *
 * Handles Stripe Connect account update events.
 *
 * Configure webhook at: https://dashboard.stripe.com/webhooks
 * Endpoint: https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/stripeConnectWebhook
 * Events to select:
 * - account.updated
 * - transfer.created
 * - transfer.failed
 * - payout.paid
 * - payout.failed
 */
exports.stripeConnectWebhook = functions.https.onRequest(async (req, res) => {
    const sig = req.headers["stripe-signature"];
    const webhookSecret = process.env.STRIPE_CONNECT_WEBHOOK_SECRET || process.env.STRIPE_WEBHOOK_SECRET;

    if (!webhookSecret) {
        console.error("Connect webhook secret not configured");
        return res.status(500).send("Webhook secret not configured");
    }

    let event;

    try {
        const stripeInstance = getStripe();
        event = stripeInstance.webhooks.constructEvent(
            req.rawBody,
            sig,
            webhookSecret
        );
    } catch (err) {
        console.error("Connect webhook signature verification failed:", err.message);
        return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    console.log(`Received Connect webhook event: ${event.type}`);

    const db = admin.firestore();

    try {
        switch (event.type) {
            case "account.updated": {
                const account = event.data.object;
                const userId = account.metadata?.userId;

                if (userId) {
                    // Update creator profile with account status
                    await db.collection("creatorProfiles").doc(userId).update({
                        isStripeAccountComplete: account.charges_enabled && account.payouts_enabled,
                        stripeAccountStatus: account.details_submitted
                            ? (account.charges_enabled && account.payouts_enabled ? "enabled" : "restricted")
                            : "incomplete",
                    });

                    console.log(`Updated creator profile for user ${userId}`);

                    // Notify user if account is now fully enabled
                    if (account.charges_enabled && account.payouts_enabled) {
                        await db.collection("notifications").add({
                            userId: userId,
                            title: "Compte Stripe activé",
                            body: "Votre compte est maintenant prêt à recevoir des paiements!",
                            type: "stripe_account_enabled",
                            isRead: false,
                            createdAt: admin.firestore.FieldValue.serverTimestamp(),
                        });
                    }
                }
                break;
            }

            case "transfer.failed": {
                const transfer = event.data.object;
                const payoutId = transfer.metadata?.payoutId;
                const creatorId = transfer.metadata?.creatorId;

                if (payoutId && creatorId) {
                    // Update payout status
                    await db.collection("payouts").doc(payoutId).update({
                        status: "failed",
                        errorMessage: "Le transfert Stripe a échoué",
                        failedAt: admin.firestore.FieldValue.serverTimestamp(),
                    });

                    // Restore balance
                    await db.collection("creatorProfiles").doc(creatorId).update({
                        availableBalance: admin.firestore.FieldValue.increment(transfer.amount),
                    });

                    console.log(`Transfer failed for payout ${payoutId}`);
                }
                break;
            }

            case "payout.paid": {
                // A payout to a connected account's bank has been paid
                const payout = event.data.object;
                console.log(`Payout paid: ${payout.id}`);
                break;
            }

            case "payout.failed": {
                // A payout to a connected account's bank has failed
                const payout = event.data.object;
                console.log(`Payout failed: ${payout.id}, reason: ${payout.failure_message}`);
                break;
            }

            default:
                console.log(`Unhandled Connect event: ${event.type}`);
        }

        res.json({ received: true });

    } catch (error) {
        console.error("Error processing Connect webhook:", error);
        res.status(500).send("Webhook processing error");
    }
});

// ============================================================================
// SUPPORT TICKET NOTIFICATIONS
// ============================================================================

/**
 * When a new message is added to a support ticket, send a push notification
 * to the appropriate party (user if support replied, or nothing if user replied
 * since admins check the dashboard).
 */
exports.onSupportMessageCreated = functions.firestore
    .document("support_tickets/{ticketId}/messages/{messageId}")
    .onCreate(async (snapshot, context) => {
        const messageData = snapshot.data();
        const ticketId = context.params.ticketId;

        // Only notify users when support replies
        if (!messageData.isFromSupport) {
            return null;
        }

        try {
            // Get the ticket to find the user
            const ticketDoc = await admin.firestore()
                .collection("support_tickets")
                .doc(ticketId)
                .get();

            if (!ticketDoc.exists) {
                console.log(`Support ticket ${ticketId} not found`);
                return null;
            }

            const ticketData = ticketDoc.data();
            const userId = ticketData.userId;

            if (!userId) {
                return null;
            }

            // Get user's FCM tokens
            const userDoc = await admin.firestore()
                .collection("users")
                .doc(userId)
                .get();

            if (!userDoc.exists) {
                return null;
            }

            const userData = userDoc.data();
            const fcmTokens = userData.fcmTokens;

            if (!fcmTokens || !Array.isArray(fcmTokens) || fcmTokens.length === 0) {
                return null;
            }

            const title = "Réponse du support";
            const body = `Votre ticket "${ticketData.subject}" a reçu une réponse`;

            const response = await admin.messaging().sendEachForMulticast({
                tokens: fcmTokens,
                notification: { title, body },
                data: {
                    type: "support_reply",
                    ticketId: ticketId,
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
                android: {
                    notification: {
                        channelId: "general_channel",
                        priority: "high",
                        sound: "default",
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            sound: "default",
                            badge: 1,
                        },
                    },
                },
            });

            // Clean up invalid tokens
            const failedTokens = [];
            response.responses.forEach((resp, idx) => {
                if (!resp.success) {
                    const errorCode = resp.error?.code;
                    if (
                        errorCode === "messaging/invalid-registration-token" ||
                        errorCode === "messaging/registration-token-not-registered"
                    ) {
                        failedTokens.push(fcmTokens[idx]);
                    }
                }
            });

            if (failedTokens.length > 0) {
                await admin.firestore().collection("users").doc(userId).update({
                    fcmTokens: admin.firestore.FieldValue.arrayRemove(...failedTokens),
                });
            }

            // Also create a notification document for in-app notification list
            await admin.firestore().collection("notifications").add({
                userId: userId,
                type: "support_reply",
                title: title,
                body: body,
                data: { ticketId: ticketId },
                read: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`Support notification sent for ticket ${ticketId} to user ${userId}`);
            return null;
        } catch (error) {
            console.error("Error sending support notification:", error);
            return null;
        }
    });

// ============================================================================
// LIVEKIT TOKEN GENERATION FOR GROUP CALLS
// ============================================================================

const { AccessToken, EgressClient, RoomServiceClient } = require("livekit-server-sdk");

/**
 * Generate a LiveKit access token for group video/audio calls.
 *
 * Call from Flutter:
 * ```dart
 * final result = await FirebaseFunctions.instance
 *     .httpsCallable('getLiveKitToken')
 *     .call({
 *       'roomName': 'group_call_123',
 *       'participantName': 'John Doe',
 *     });
 * final token = result.data['token'];
 * ```
 *
 * Required Firebase Functions config:
 * ```bash
 * firebase functions:config:set livekit.api_key="YOUR_API_KEY" livekit.api_secret="YOUR_API_SECRET"
 * ```
 */
exports.getLiveKitToken = functions.https.onCall(async (data, context) => {
    // Require authentication
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "User must be authenticated to get LiveKit token"
        );
    }

    const { roomName, participantName } = data;

    if (!roomName || typeof roomName !== "string") {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Room name is required and must be a string"
        );
    }

    if (!participantName || typeof participantName !== "string") {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Participant name is required and must be a string"
        );
    }

    // Get LiveKit credentials from config or environment
    const apiKey = process.env.LIVEKIT_API_KEY || functions.config().livekit?.api_key;
    const apiSecret = process.env.LIVEKIT_API_SECRET || functions.config().livekit?.api_secret;

    if (!apiKey || !apiSecret) {
        console.error("LiveKit API credentials not configured");
        throw new functions.https.HttpsError(
            "failed-precondition",
            "LiveKit API credentials not configured"
        );
    }

    try {
        // Create access token
        const at = new AccessToken(apiKey, apiSecret, {
            identity: context.auth.uid,
            name: participantName,
            // Token expires in 6 hours (enough for long calls)
            ttl: "6h",
        });


    // Security: verify caller is a participant in the group call.
    // Deny by default — if no matching room doc is found, reject the request.
    const callDoc = await admin.firestore().collection("group_calls").where("roomName", "==", roomName).limit(1).get();
    if (callDoc.empty) {
        throw new functions.https.HttpsError("not-found", "No active group call found for this room");
    }
    const callData = callDoc.docs[0].data();
    const participantIds = callData.participantIds || [];
    if (!participantIds.includes(context.auth.uid) && callData.hostId !== context.auth.uid) {
        throw new functions.https.HttpsError("permission-denied", "You are not a participant in this call");
    }

        // Grant permissions for the room
        at.addGrant({
            room: roomName,
            roomJoin: true,
            canPublish: true,
            canPublishData: true,
            canSubscribe: true,
            canUpdateOwnMetadata: true,
        });

        // Generate JWT token
        const token = await at.toJwt();

        console.log(`LiveKit token generated for user ${context.auth.uid} in room ${roomName}`);

        return {
            token: token,
            roomName: roomName,
            identity: context.auth.uid,
        };
    } catch (error) {
        console.error("Error generating LiveKit token:", error);
        throw new functions.https.HttpsError(
            "internal",
            "Failed to generate LiveKit token"
        );
    }
});

/**
 * Create a LiveKit room with specific configuration.
 *
 * This can be used to pre-create rooms with specific settings
 * before participants join.
 */
exports.createLiveKitRoom = functions.https.onCall(async (data, context) => {
    // Require authentication
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "User must be authenticated"
        );
    }

    const { roomName, maxParticipants = 50, emptyTimeout = 300 } = data;

    if (!roomName || typeof roomName !== "string") {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Room name is required"
        );
    }

    // Store room info in Firestore for tracking
    const db = admin.firestore();

    try {
        await db.collection("group_calls").doc(roomName).set({
            roomName: roomName,
            hostId: context.auth.uid,
            maxParticipants: maxParticipants,
            emptyTimeout: emptyTimeout,
            status: "waiting",
            mode: "sfu",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            participantIds: [context.auth.uid],
        });

        console.log(`LiveKit room ${roomName} created by ${context.auth.uid}`);

        return {
            success: true,
            roomName: roomName,
        };
    } catch (error) {
        console.error("Error creating LiveKit room:", error);
        throw new functions.https.HttpsError(
            "internal",
            "Failed to create room"
        );
    }
});

// ============================================================================
// PARTNER PAYMENT PROCESSING (Mynita, Wave, Bank)
// ============================================================================

/**
 * Process Debit Request
 *
 * Triggered when a new document is created in 'debit_requests' collection.
 * Initiates debit from sender's Mynita/Wave account.
 */
exports.processDebitRequest = functions.firestore
    .document("debit_requests/{requestId}")
    .onCreate(async (snapshot, context) => {
        const data = snapshot.data();
        const requestId = context.params.requestId;
        const db = admin.firestore();

        console.log(`Processing debit request: ${requestId}`);

        try {
            const { transactionId, provider, phone, amount, currency } = data;

    // Security: cross-validate amount against the transaction document
    if (transactionId) {
      const transactionDoc = await admin.firestore().collection("transactions").doc(transactionId).get();
      if (transactionDoc.exists) {
        const txData = transactionDoc.data();
        // Compare against amountInXof (the canonical XOF amount the partner will be debited for)
        const expectedAmount = txData.amountInXof ?? txData.amount;
        if (expectedAmount !== amount) {
          console.error(`Amount mismatch: debit_request=${amount}, transaction.amountInXof=${expectedAmount}`);
          await snapshot.ref.update({ status: "failed", error: "Amount mismatch" });
          return;
        }
      }
    }

            // Validate required fields
            if (!transactionId || !provider || !phone || !amount) {
                throw new Error("Missing required fields");
            }

            // Check if provider supports debit
            if (!partners.supportsDebit(provider)) {
                throw new Error(`Provider ${provider} does not support debit`);
            }

            // Update transaction status to "debiting"
            await db.collection("transactions").doc(transactionId).update({
                status: "debiting",
                debitProvider: provider,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Get the appropriate client and initiate debit
            const client = partners.getDebitClient(provider);
            const result = await client.debit({
                phone,
                amount,
                currency: currency || "XOF",
                reference: transactionId,
            });

            // Update debit request with result
            await snapshot.ref.update({
                status: result.success ? "initiated" : "failed",
                partnerTransactionId: result.transactionId || null,
                fee: result.fee || 0,
                error: result.errorMessage || null,
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // If debit failed immediately, update transaction
            if (!result.success) {
                await db.collection("transactions").doc(transactionId).update({
                    status: "failed",
                    failureReason: result.errorMessage || "Debit failed",
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            } else {
                // Store debit transaction ID
                await db.collection("transactions").doc(transactionId).update({
                    debitTransactionId: result.transactionId,
                    debitFee: result.fee || 0,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }

            console.log(`Debit request ${requestId} processed: ${result.success ? "success" : "failed"}`);
            return { success: result.success };
        } catch (error) {
            console.error(`Error processing debit request ${requestId}:`, error);

            // Update request with error
            await snapshot.ref.update({
                status: "error",
                error: error.message,
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Update transaction as failed
            if (data.transactionId) {
                await db.collection("transactions").doc(data.transactionId).update({
                    status: "failed",
                    failureReason: error.message,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }

            return { success: false, error: error.message };
        }
    });

/**
 * Process Credit to Recipient
 *
 * Triggered when a transaction status changes to "processing".
 * Initiates credit to recipient's Mynita/Wave/Bank account.
 */
exports.processCreditToRecipient = functions.firestore
    .document("transactions/{transactionId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        const transactionId = context.params.transactionId;
        const db = admin.firestore();

        // Only process when status changes to "processing"
        if (before.status === "processing" || after.status !== "processing") {
            return null;
        }

        console.log(`Processing credit for transaction: ${transactionId}`);

        try {
            // Get recipient info
            const recipientDoc = await db.collection("recipients").doc(after.recipientId).get();
            if (!recipientDoc.exists) {
                throw new Error("Recipient not found");
            }

            const recipient = recipientDoc.data();
            const recipientType = recipient.type || "mynita";

            // Check if recipient type supports credit
            if (!partners.supportsCredit(recipientType)) {
                throw new Error(`Recipient type ${recipientType} does not support credit`);
            }

            // Update transaction status to "sending"
            await change.after.ref.update({
                status: "sending",
                creditProvider: recipientType,
                sentToPartnerAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Get the appropriate client
            const client = partners.getCreditClient(recipientType);
            let result;

            if (recipientType === "bankAccount" || recipientType === "bank") {
                // Bank transfer
                result = await client.credit({
                    iban: recipient.iban || recipient.accountNumber,
                    bankName: recipient.bankName,
                    accountName: recipient.fullName,
                    bankCode: recipient.bankCode,
                    amount: after.amountInXof,
                    currency: "XOF",
                    reference: transactionId,
                });
            } else {
                // Mobile money (Mynita/Wave)
                result = await client.credit({
                    phone: `${recipient.phoneCountryCode || ""}${recipient.phone}`,
                    amount: after.amountInXof,
                    currency: "XOF",
                    reference: transactionId,
                });
            }

            // Update transaction with credit result
            if (result.success) {
                await change.after.ref.update({
                    creditTransactionId: result.transactionId,
                    creditFee: result.fee || 0,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            } else {
                await change.after.ref.update({
                    status: "failed",
                    failureReason: result.errorMessage || "Credit failed",
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }

            console.log(`Credit for transaction ${transactionId}: ${result.success ? "initiated" : "failed"}`);
            return { success: result.success };
        } catch (error) {
            console.error(`Error processing credit for ${transactionId}:`, error);

            await change.after.ref.update({
                status: "failed",
                failureReason: error.message,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            return { success: false, error: error.message };
        }
    });

/**
 * Mynita Webhook Handler
 *
 * Receives callbacks from Mynita for debit and credit confirmations.
 * Endpoint: https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/mynitaWebhook
 */
exports.mynitaWebhook = functions.https.onRequest(async (req, res) => {
    if (req.method !== "POST") {
        return res.status(405).send("Method not allowed");
    }

    const db = admin.firestore();
    const client = partners.getMynitaClient();

    try {
        // Verify signature (in production)
        const signature = req.headers["x-mynita-signature"];
        if (!client.verifySignature(req.body, signature)) {
            console.warn("Mynita webhook: Invalid signature");
            return res.status(401).send("Invalid signature");
        }

        // Parse webhook event
        const event = client.parseWebhookEvent(req.body);
        console.log(`Mynita webhook received: ${event.type} - ${event.status}`);

        const transactionId = event.transactionId;
        if (!transactionId) {
            return res.status(400).send("Missing transaction reference");
        }

        // Get transaction
        const transactionRef = db.collection("transactions").doc(transactionId);
        const transactionDoc = await transactionRef.get();

        if (!transactionDoc.exists) {
            console.warn(`Mynita webhook: Transaction ${transactionId} not found`);
            return res.status(404).send("Transaction not found");
        }

        const transaction = transactionDoc.data();

        if (event.type === "debit") {
            // Debit confirmation
            if (event.status === "success") {
                // Debit successful - move to processing to trigger credit
                await transactionRef.update({
                    status: "processing",
                    debitConfirmedAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                console.log(`Transaction ${transactionId}: Debit confirmed, moving to processing`);
            } else if (event.status === "failed") {
                // Debit failed
                await transactionRef.update({
                    status: "failed",
                    failureReason: event.errorMessage || "Debit failed",
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                console.log(`Transaction ${transactionId}: Debit failed - ${event.errorMessage}`);
            }
        } else if (event.type === "credit") {
            // Credit confirmation
            if (event.status === "success") {
                // Credit successful - transaction complete
                await transactionRef.update({
                    status: "completed",
                    creditConfirmedAt: admin.firestore.FieldValue.serverTimestamp(),
                    completedAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                // Send notification to recipient
                await sendTransferNotification(transaction, "completed");

                console.log(`Transaction ${transactionId}: Credit confirmed, completed`);
            } else if (event.status === "failed") {
                // Credit failed - may need refund
                await transactionRef.update({
                    status: "failed",
                    failureReason: event.errorMessage || "Credit failed",
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                // TODO: Initiate refund if debit was already done

                console.log(`Transaction ${transactionId}: Credit failed - ${event.errorMessage}`);
            }
        }

        res.json({ received: true });
    } catch (error) {
        console.error("Mynita webhook error:", error);
        res.status(500).send("Webhook processing error");
    }
});

/**
 * Wave Webhook Handler
 *
 * Receives callbacks from Wave for debit and credit confirmations.
 * Endpoint: https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/waveWebhook
 */
exports.waveWebhook = functions.https.onRequest(async (req, res) => {
    if (req.method !== "POST") {
        return res.status(405).send("Method not allowed");
    }

    const db = admin.firestore();
    const client = partners.getWaveClient();

    try {
        // Verify signature (in production)
        const signature = req.headers["x-wave-signature"] || req.headers["wave-signature"];
        if (!client.verifySignature(req.body, signature)) {
            console.warn("Wave webhook: Invalid signature");
            return res.status(401).send("Invalid signature");
        }

        // Parse webhook event
        const event = client.parseWebhookEvent(req.body);
        console.log(`Wave webhook received: ${event.type} - ${event.status}`);

        const transactionId = event.transactionId;
        if (!transactionId) {
            return res.status(400).send("Missing transaction reference");
        }

        // Get transaction
        const transactionRef = db.collection("transactions").doc(transactionId);
        const transactionDoc = await transactionRef.get();

        if (!transactionDoc.exists) {
            console.warn(`Wave webhook: Transaction ${transactionId} not found`);
            return res.status(404).send("Transaction not found");
        }

        const transaction = transactionDoc.data();

        if (event.type === "debit") {
            if (event.status === "success") {
                await transactionRef.update({
                    status: "processing",
                    debitConfirmedAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                console.log(`Transaction ${transactionId}: Wave debit confirmed`);
            } else if (event.status === "failed") {
                await transactionRef.update({
                    status: "failed",
                    failureReason: event.errorMessage || "Wave debit failed",
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
        } else if (event.type === "credit") {
            if (event.status === "success") {
                await transactionRef.update({
                    status: "completed",
                    creditConfirmedAt: admin.firestore.FieldValue.serverTimestamp(),
                    completedAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                await sendTransferNotification(transaction, "completed");
                console.log(`Transaction ${transactionId}: Wave credit confirmed, completed`);
            } else if (event.status === "failed") {
                await transactionRef.update({
                    status: "failed",
                    failureReason: event.errorMessage || "Wave credit failed",
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
        }

        res.json({ received: true });
    } catch (error) {
        console.error("Wave webhook error:", error);
        res.status(500).send("Webhook processing error");
    }
});

/**
 * Bank Transfer Webhook Handler
 *
 * Receives callbacks from banking partner for transfer confirmations.
 * Endpoint: https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/bankWebhook
 */
exports.bankWebhook = functions.https.onRequest(async (req, res) => {
    if (req.method !== "POST") {
        return res.status(405).send("Method not allowed");
    }

    // Security: bank transfer client not yet implemented — return 503
    return res.status(503).json({ error: "Bank transfers not yet implemented" });
});

/**
 * Helper: Send transfer notification to recipient
 */
async function sendTransferNotification(transaction, status) {
    const db = admin.firestore();

    try {
        // Get recipient user info if they have an account
        const recipientDoc = await db.collection("recipients").doc(transaction.recipientId).get();
        if (!recipientDoc.exists) return;

        const recipient = recipientDoc.data();

        // If recipient has a linked userId, send push notification
        if (recipient.linkedUserId) {
            const userDoc = await db.collection("users").doc(recipient.linkedUserId).get();
            if (userDoc.exists) {
                const user = userDoc.data();

                // Collect tokens from new fcmTokens array (preferred) and legacy fcmToken (backward compat).
                const tokens = [];
                if (Array.isArray(user.fcmTokens)) {
                    for (const t of user.fcmTokens) {
                        if (typeof t === "string" && t.length > 0) tokens.push(t);
                    }
                }
                if (typeof user.fcmToken === "string" && user.fcmToken.length > 0 && !tokens.includes(user.fcmToken)) {
                    tokens.push(user.fcmToken);
                }

                if (tokens.length > 0) {
                    const multicastMessage = {
                        notification: {
                            title: status === "completed"
                                ? "Transfert recu!"
                                : "Transfert echoue",
                            body: status === "completed"
                                ? `Vous avez recu ${transaction.amountInXof} XOF`
                                : `Le transfert de ${transaction.amountInXof} XOF a echoue`,
                        },
                        data: {
                            type: "transfer",
                            transactionId: transaction.id || "",
                            status: status,
                        },
                        tokens,
                    };

                    try {
                        const response = await admin.messaging().sendEachForMulticast(multicastMessage);
                        // Cleanup invalid tokens to keep the user document healthy
                        if (response.failureCount > 0) {
                            const invalidTokens = [];
                            response.responses.forEach((resp, idx) => {
                                if (!resp.success) {
                                    const code = resp.error && resp.error.code;
                                    if (
                                        code === "messaging/invalid-registration-token" ||
                                        code === "messaging/registration-token-not-registered"
                                    ) {
                                        invalidTokens.push(tokens[idx]);
                                    }
                                }
                            });
                            if (invalidTokens.length > 0) {
                                await db.collection("users").doc(recipient.linkedUserId).update({
                                    fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
                                });
                            }
                        }
                    } catch (err) {
                        console.error("sendTransferNotification: multicast error", err);
                    }
                }
            }
        }

        // Create in-app notification
        await db.collection("notifications").add({
            userId: recipient.linkedUserId || recipient.userId,
            type: "transfer",
            title: status === "completed" ? "Transfert recu" : "Transfert echoue",
            body: status === "completed"
                ? `Vous avez recu ${transaction.amountInXof} XOF`
                : `Le transfert a echoue`,
            data: {
                transactionId: transaction.id,
                amount: transaction.amountInXof,
                senderId: transaction.senderId,
            },
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    } catch (error) {
        console.error("Error sending transfer notification:", error);
    }
}

// ============================================================================
// CONVERSATION DELETION WITH SERVER-SIDE VALIDATION
// ============================================================================

/**
 * Supprimer une conversation pour tous avec validation des permissions cote serveur.
 * Seul un admin ou le createur de la conversation peut supprimer pour tous.
 *
 * Appeler depuis Flutter:
 * ```dart
 * final result = await FirebaseFunctions.instance
 *     .httpsCallable('deleteConversationForEveryone')
 *     .call({'conversationId': 'xxx'});
 * ```
 */
exports.deleteConversationForEveryone = functions.https.onCall(async (data, context) => {
    // Verifier authentification
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Authentification requise"
        );
    }

    const { conversationId } = data;
    const userId = context.auth.uid;

    if (!conversationId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "conversationId est requis"
        );
    }

    try {
        // Recuperer la conversation
        const convDoc = await admin.firestore()
            .collection("conversations")
            .doc(conversationId)
            .get();

        if (!convDoc.exists) {
            throw new functions.https.HttpsError(
                "not-found",
                "Conversation introuvable"
            );
        }

        const convData = convDoc.data();
        const creatorId = convData.createdBy;
        const adminIds = convData.adminIds || [];

        // Verifier permissions COTE SERVEUR
        if (creatorId !== userId && !adminIds.includes(userId)) {
            throw new functions.https.HttpsError(
                "permission-denied",
                "Seul un admin ou le createur peut supprimer pour tous"
            );
        }

        // Proceder a la suppression
        const batch = admin.firestore().batch();

        // 1. Supprimer messages RTDB
        await admin.database().ref(`messages/${conversationId}`).remove();

        // 2. Supprimer indicateurs de frappe RTDB
        await admin.database().ref(`typing/${conversationId}`).remove();

        // 3. Supprimer participants RTDB
        await admin.database().ref(`conversations/${conversationId}`).remove();

        // 4. Supprimer fichiers Storage (async, ne bloque pas)
        try {
            const bucket = admin.storage().bucket();
            await bucket.deleteFiles({ prefix: `messages/${conversationId}/` });
        } catch (storageError) {
            console.warn("Storage cleanup warning:", storageError.message);
            // Continue meme si le nettoyage du storage echoue
        }

        // 5. Supprimer conversation Firestore
        batch.delete(convDoc.ref);

        await batch.commit();

        console.log(`Conversation ${conversationId} supprimee par ${userId}`);

        return { success: true };
    } catch (error) {
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        console.error("Error deleting conversation:", error);
        throw new functions.https.HttpsError(
            "internal",
            `Erreur lors de la suppression: ${error.message}`
        );
    }
});

/**
 * Trigger sur mise a jour de message pour notifier les participants d'une suppression "pour tous"
 */
exports.onMessageDeleted = functions
    .region("europe-west1")
    .database.instance("diaspo-niger-default-rtdb")
    .ref("/messages/{conversationId}/{messageId}")
    .onUpdate(async (change, context) => {
        const before = change.before.val();
        const after = change.after.val();

        // Verifier si c'est une suppression "pour tous"
        if (!before.deletedForEveryone && after.deletedForEveryone) {
            const conversationId = context.params.conversationId;

            try {
                // Recuperer les participants
                const convDoc = await admin.firestore()
                    .collection("conversations")
                    .doc(conversationId)
                    .get();

                if (!convDoc.exists) return null;

                const convData = convDoc.data();
                const participants = convData.participantIds || [];
                const senderId = after.senderId;

                // Envoyer notification aux autres participants
                const notificationPromises = [];
                for (const participantId of participants) {
                    if (participantId !== senderId) {
                        notificationPromises.push(
                            admin.firestore()
                                .collection("users")
                                .doc(participantId)
                                .collection("notifications")
                                .add({
                                    type: "message_deleted",
                                    conversationId,
                                    deletedBy: senderId,
                                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                                })
                        );
                    }
                }

                await Promise.all(notificationPromises);

                return { success: true };
            } catch (error) {
                console.error("Error sending deletion notifications:", error);
                return null;
            }
        }

        return null;
    });

// ============================================================================
// AUDIO ROOMS MONETIZATION - SERVER-SIDE COMMISSION CALCULATIONS
// ============================================================================

/**
 * Process tip creation - calculates commission server-side for security.
 * Commission rate: 20%
 *
 * This prevents malicious users from manipulating commission amounts.
 */
exports.processTip = functions.firestore
    .document("tips/{tipId}")
    .onCreate(async (snap, context) => {
        const tip = snap.data();
        const tipId = context.params.tipId;

        try {
            const amount = tip.amount;

            if (typeof amount !== "number" || amount <= 0) {
                console.error(`Invalid tip amount for ${tipId}: ${amount}`);
                await snap.ref.update({
                    status: "failed",
                    error: "Invalid amount",
                    processedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                return null;
            }

            // Server-side commission calculation (20% for tips)
            const COMMISSION_RATE = 0.20;
            const commissionAmount = Math.round(amount * COMMISSION_RATE);
            const recipientAmount = amount - commissionAmount;

            // Update with server-calculated values
            await snap.ref.update({
                commissionAmount: commissionAmount,
                recipientAmount: recipientAmount,
                commissionRate: COMMISSION_RATE,
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`Tip ${tipId} processed: amount=${amount}, commission=${commissionAmount}, recipient=${recipientAmount}`);

            return { success: true, tipId };
        } catch (error) {
            console.error(`Error processing tip ${tipId}:`, error);
            return null;
        }
    });

/**
 * Process room ticket purchase - calculates commission server-side for security.
 * Commission rate: 15%
 *
 * This prevents malicious users from manipulating commission amounts.
 */
exports.processRoomTicket = functions.firestore
    .document("roomTickets/{ticketId}")
    .onCreate(async (snap, context) => {
        const ticket = snap.data();
        const ticketId = context.params.ticketId;

        try {
            const priceAmount = ticket.priceAmount;

            if (typeof priceAmount !== "number" || priceAmount <= 0) {
                console.error(`Invalid ticket price for ${ticketId}: ${priceAmount}`);
                await snap.ref.update({
                    status: "failed",
                    error: "Invalid price",
                    processedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                return null;
            }

            // Server-side commission calculation (15% for tickets)
            const COMMISSION_RATE = 0.15;
            const commissionAmount = Math.round(priceAmount * COMMISSION_RATE);
            const sellerAmount = priceAmount - commissionAmount;

            // Update with server-calculated values
            await snap.ref.update({
                commissionAmount: commissionAmount,
                sellerAmount: sellerAmount,
                commissionRate: COMMISSION_RATE,
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`Ticket ${ticketId} processed: price=${priceAmount}, commission=${commissionAmount}, seller=${sellerAmount}`);

            return { success: true, ticketId };
        } catch (error) {
            console.error(`Error processing ticket ${ticketId}:`, error);
            return null;
        }
    });

/**
 * Credit creator balance when a tip payment is confirmed (status → 'completed').
 * Uses server-calculated recipientAmount from processTip to avoid client manipulation.
 * The balanceCredited flag prevents double-crediting on retries.
 */
exports.onTipCompleted = functions.firestore
    .document("tips/{tipId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();

        if (before.status === after.status) return null;
        if (after.status !== "completed") return null;
        if (after.balanceCredited === true) return null;

        const recipientAmount = after.recipientAmount;
        const recipientId = after.recipientId;

        if (typeof recipientAmount !== "number" || recipientAmount <= 0 || !recipientId) {
            console.error(`onTipCompleted: invalid data for tip ${context.params.tipId}`);
            return null;
        }

        try {
            await admin.firestore().collection("creatorProfiles").doc(recipientId).set({
                totalTipEarnings: admin.firestore.FieldValue.increment(recipientAmount),
                availableBalance: admin.firestore.FieldValue.increment(recipientAmount),
                currentMonthEarnings: admin.firestore.FieldValue.increment(recipientAmount),
            }, { merge: true });

            await change.after.ref.update({ balanceCredited: true });
            console.log(`onTipCompleted: credited ${recipientAmount} to creator ${recipientId}`);
        } catch (error) {
            console.error(`onTipCompleted: error crediting creator ${recipientId}:`, error);
        }

        return null;
    });

/**
 * Credit creator balance when a room ticket payment is confirmed (status → 'active').
 * Uses server-calculated sellerAmount from processRoomTicket to avoid client manipulation.
 * The balanceCredited flag prevents double-crediting on retries.
 */
exports.onTicketActivated = functions.firestore
    .document("roomTickets/{ticketId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();

        if (before.status === after.status) return null;
        if (after.status !== "active") return null;
        if (after.balanceCredited === true) return null;

        const sellerAmount = after.sellerAmount;
        const sellerId = after.sellerId;

        if (typeof sellerAmount !== "number" || sellerAmount <= 0 || !sellerId) {
            console.error(`onTicketActivated: invalid data for ticket ${context.params.ticketId}`);
            return null;
        }

        try {
            await admin.firestore().collection("creatorProfiles").doc(sellerId).set({
                totalTicketEarnings: admin.firestore.FieldValue.increment(sellerAmount),
                availableBalance: admin.firestore.FieldValue.increment(sellerAmount),
                currentMonthEarnings: admin.firestore.FieldValue.increment(sellerAmount),
            }, { merge: true });

            await change.after.ref.update({ balanceCredited: true });
            console.log(`onTicketActivated: credited ${sellerAmount} to seller ${sellerId}`);
        } catch (error) {
            console.error(`onTicketActivated: error crediting seller ${sellerId}:`, error);
        }

        return null;
    });

/**
 * Handle user leaving audio room - ensures cleanup even if app crashes.
 * Called from the client app when user leaves a room.
 */
exports.onUserLeaveRoom = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "User must be authenticated"
        );
    }

    const { roomId, userId } = data;
    const callerUserId = context.auth.uid;

    // User can only mark themselves as leaving
    if (userId !== callerUserId) {
        throw new functions.https.HttpsError(
            "permission-denied",
            "You can only leave rooms yourself"
        );
    }

    if (!roomId || !userId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "roomId and userId are required"
        );
    }

    try {
        const participantRef = admin.firestore()
            .collection("audioRooms")
            .doc(roomId)
            .collection("participants")
            .doc(userId);

        const participantSnap = await participantRef.get();

        if (participantSnap.exists) {
            await participantRef.update({
                status: "left",
                leftAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        // Decrement participant count
        await admin.firestore()
            .collection("audioRooms")
            .doc(roomId)
            .update({
                participantCount: admin.firestore.FieldValue.increment(-1),
            });

        console.log(`User ${userId} left room ${roomId}`);

        return { success: true };
    } catch (error) {
        console.error(`Error removing user ${userId} from room ${roomId}:`, error);
        throw new functions.https.HttpsError(
            "internal",
            `Failed to leave room: ${error.message}`
        );
    }
});

/**
 * Scheduled function to cleanup stale participants in audio rooms.
 * Runs every 5 minutes to remove participants without recent heartbeat.
 */
exports.cleanupStaleParticipants = functions.pubsub
    .schedule("every 5 minutes")
    .onRun(async (context) => {
        try {
            // Participants without heartbeat for 2 minutes are considered stale
            const staleThreshold = new Date(Date.now() - 2 * 60 * 1000);

            // Get all active audio rooms
            const roomsSnapshot = await admin.firestore()
                .collection("audioRooms")
                .where("status", "==", "live")
                .get();

            if (roomsSnapshot.empty) {
                return { success: true, cleaned: 0 };
            }

            let totalCleaned = 0;

            for (const roomDoc of roomsSnapshot.docs) {
                const roomId = roomDoc.id;

                // Get stale participants
                const staleParticipants = await admin.firestore()
                    .collection("audioRooms")
                    .doc(roomId)
                    .collection("participants")
                    .where("status", "==", "active")
                    .where("lastHeartbeat", "<", staleThreshold)
                    .get();

                if (!staleParticipants.empty) {
                    const batch = admin.firestore().batch();

                    staleParticipants.docs.forEach(doc => {
                        batch.update(doc.ref, {
                            status: "stale",
                            markedStaleAt: admin.firestore.FieldValue.serverTimestamp(),
                        });
                    });

                    // Update room participant count
                    batch.update(roomDoc.ref, {
                        participantCount: admin.firestore.FieldValue.increment(-staleParticipants.size),
                    });

                    await batch.commit();
                    totalCleaned += staleParticipants.size;

                    console.log(`Cleaned up ${staleParticipants.size} stale participants from room ${roomId}`);
                }

                // End the room if no active participants remain after cleanup
                const remaining = await roomDoc.ref.collection("participants")
                    .where("status", "==", "active")
                    .get();

                if (remaining.empty) {
                    await roomDoc.ref.update({
                        status: "ended",
                        endedAt: admin.firestore.FieldValue.serverTimestamp(),
                        endReason: "all_participants_disconnected",
                    });
                    console.log(`Room ${roomId}: no active participants left, marked as ended`);
                }
            }

            return { success: true, cleaned: totalCleaned };
        } catch (error) {
            console.error("Error cleaning up stale participants:", error);
            return { success: false, error: error.message };
        }
    });

// ============================================================================
// MESSAGE DELETION WITH SERVER-SIDE VALIDATION
// ============================================================================

/**
 * Supprimer un message pour tous avec validation des permissions cote serveur.
 * Seul l'expediteur peut supprimer son message, et uniquement dans un delai d'1 heure.
 *
 * Appeler depuis Flutter:
 * ```dart
 * final result = await FirebaseFunctions.instance
 *     .httpsCallable('deleteMessageForEveryone')
 *     .call({'conversationId': 'xxx', 'messageId': 'yyy'});
 * ```
 */
exports.deleteMessageForEveryone = functions.https.onCall(async (data, context) => {
    // Verifier authentification
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Authentification requise"
        );
    }

    const { conversationId, messageId } = data;
    const userId = context.auth.uid;

    if (!conversationId || !messageId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "conversationId et messageId sont requis"
        );
    }

    try {
        // Recuperer le message depuis RTDB
        const messageRef = admin.database().ref(`messages/${conversationId}/${messageId}`);
        const messageSnapshot = await messageRef.get();

        if (!messageSnapshot.exists()) {
            throw new functions.https.HttpsError(
                "not-found",
                "Message introuvable"
            );
        }

        const messageData = messageSnapshot.val();

        // VALIDATION COTE SERVEUR: Verifier que l'appelant est l'expediteur
        if (messageData.senderId !== userId) {
            throw new functions.https.HttpsError(
                "permission-denied",
                "Seul l'expediteur peut supprimer ce message pour tous"
            );
        }

        // VALIDATION COTE SERVEUR: Verifier le delai (1 heure max)
        const createdAt = new Date(messageData.createdAt);
        const now = new Date();
        const hourInMs = 60 * 60 * 1000;

        if (now - createdAt > hourInMs) {
            throw new functions.https.HttpsError(
                "failed-precondition",
                "Le delai de suppression est depasse (1 heure max)"
            );
        }

        // Supprimer les fichiers associes dans Storage
        if (messageData.fileUrl) {
            try {
                const bucket = admin.storage().bucket();
                // Extraire le path depuis l'URL Firebase Storage
                const urlMatch = messageData.fileUrl.match(/o\/(.+?)\?/);
                if (urlMatch) {
                    const filePath = decodeURIComponent(urlMatch[1]);
                    await bucket.file(filePath).delete();
                    console.log(`Deleted media file: ${filePath}`);
                }
            } catch (storageError) {
                console.warn("Failed to delete media file:", storageError.message);
                // Continue meme si le fichier ne peut pas etre supprime
            }
        }

        if (messageData.thumbnailUrl) {
            try {
                const bucket = admin.storage().bucket();
                const urlMatch = messageData.thumbnailUrl.match(/o\/(.+?)\?/);
                if (urlMatch) {
                    const filePath = decodeURIComponent(urlMatch[1]);
                    await bucket.file(filePath).delete();
                }
            } catch (storageError) {
                console.warn("Failed to delete thumbnail:", storageError.message);
            }
        }

        // Mettre a jour le message pour marquer comme supprime
        await messageRef.update({
            deletedForEveryone: true,
            deletedAt: new Date().toISOString(),
            content: "",
            fileUrl: null,
            thumbnailUrl: null,
            audioWaveform: null,
            linkPreviewData: null,
        });

        console.log(`Message ${messageId} deleted for everyone by ${userId}`);

        return { success: true };
    } catch (error) {
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        console.error("Error deleting message:", error);
        throw new functions.https.HttpsError(
            "internal",
            `Erreur lors de la suppression: ${error.message}`
        );
    }
});

// ============================================================================
// GROUP MANAGEMENT WITH SERVER-SIDE VALIDATION
// ============================================================================

/**
 * Allow a member to leave a group.
 * Validates permissions server-side and handles atomic updates.
 */
exports.leaveGroup = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Authentification requise"
        );
    }

    const { groupId } = data;
    const userId = context.auth.uid;

    if (!groupId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "groupId est requis"
        );
    }

    try {
        const groupRef = admin.firestore().collection("groups").doc(groupId);

        // Use transaction for atomic operations
        await admin.firestore().runTransaction(async (transaction) => {
            const groupDoc = await transaction.get(groupRef);

            if (!groupDoc.exists) {
                throw new functions.https.HttpsError(
                    "not-found",
                    "Groupe introuvable"
                );
            }

            const groupData = groupDoc.data();
            const memberIds = groupData.memberIds || [];

            // Verify user is a member
            if (!memberIds.includes(userId)) {
                throw new functions.https.HttpsError(
                    "permission-denied",
                    "Vous n'etes pas membre de ce groupe"
                );
            }

            // Creator cannot leave - must delete or transfer ownership
            if (groupData.creatorId === userId) {
                throw new functions.https.HttpsError(
                    "failed-precondition",
                    "Le createur ne peut pas quitter le groupe. Supprimez le groupe ou transferez la propriete."
                );
            }

            // Remove user from memberIds
            const updatedMemberIds = memberIds.filter(id => id !== userId);

            // Update memberJoinedAt to remove the user's entry
            const memberJoinedAt = groupData.memberJoinedAt || {};
            delete memberJoinedAt[userId];

            transaction.update(groupRef, {
                memberIds: updatedMemberIds,
                memberJoinedAt: memberJoinedAt,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        });

        console.log(`User ${userId} left group ${groupId}`);
        return { success: true };
    } catch (error) {
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        console.error("Error leaving group:", error);
        throw new functions.https.HttpsError(
            "internal",
            `Erreur: ${error.message}`
        );
    }
});

/**
 * Remove a member from a group (admin action).
 * Only group creator or admins can remove members.
 */
exports.removeMemberFromGroup = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Authentification requise"
        );
    }

    const { groupId, targetUserId } = data;
    const requesterId = context.auth.uid;

    if (!groupId || !targetUserId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "groupId et targetUserId sont requis"
        );
    }

    try {
        const groupRef = admin.firestore().collection("groups").doc(groupId);

        await admin.firestore().runTransaction(async (transaction) => {
            const groupDoc = await transaction.get(groupRef);

            if (!groupDoc.exists) {
                throw new functions.https.HttpsError(
                    "not-found",
                    "Groupe introuvable"
                );
            }

            const groupData = groupDoc.data();
            const memberIds = groupData.memberIds || [];
            const adminIds = groupData.adminIds || [];

            // Verify requester is creator or admin
            const isCreator = groupData.creatorId === requesterId;
            const isAdmin = adminIds.includes(requesterId);

            if (!isCreator && !isAdmin) {
                throw new functions.https.HttpsError(
                    "permission-denied",
                    "Seuls le createur et les admins peuvent retirer des membres"
                );
            }

            // Cannot remove the creator
            if (targetUserId === groupData.creatorId) {
                throw new functions.https.HttpsError(
                    "failed-precondition",
                    "Impossible de retirer le createur du groupe"
                );
            }

            // Cannot remove an admin unless you're the creator
            if (adminIds.includes(targetUserId) && !isCreator) {
                throw new functions.https.HttpsError(
                    "permission-denied",
                    "Seul le createur peut retirer un administrateur"
                );
            }

            // Verify target is actually a member
            if (!memberIds.includes(targetUserId)) {
                throw new functions.https.HttpsError(
                    "not-found",
                    "L'utilisateur n'est pas membre du groupe"
                );
            }

            // Remove from memberIds and adminIds
            const updatedMemberIds = memberIds.filter(id => id !== targetUserId);
            const updatedAdminIds = adminIds.filter(id => id !== targetUserId);

            // Update memberJoinedAt
            const memberJoinedAt = groupData.memberJoinedAt || {};
            delete memberJoinedAt[targetUserId];

            transaction.update(groupRef, {
                memberIds: updatedMemberIds,
                adminIds: updatedAdminIds,
                memberJoinedAt: memberJoinedAt,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        });

        console.log(`User ${targetUserId} removed from group ${groupId} by ${requesterId}`);
        return { success: true };
    } catch (error) {
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        console.error("Error removing member from group:", error);
        throw new functions.https.HttpsError(
            "internal",
            `Erreur: ${error.message}`
        );
    }
});

/**
 * Delete a group completely (creator action only).
 * Cleans up all related data atomically.
 */
exports.deleteGroup = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Authentification requise"
        );
    }

    const { groupId } = data;
    const userId = context.auth.uid;

    if (!groupId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "groupId est requis"
        );
    }

    try {
        const groupRef = admin.firestore().collection("groups").doc(groupId);
        const groupDoc = await groupRef.get();

        if (!groupDoc.exists) {
            throw new functions.https.HttpsError(
                "not-found",
                "Groupe introuvable"
            );
        }

        const groupData = groupDoc.data();

        // Only creator can delete the group
        if (groupData.creatorId !== userId) {
            throw new functions.https.HttpsError(
                "permission-denied",
                "Seul le createur peut supprimer le groupe"
            );
        }

        const batch = admin.firestore().batch();

        // Delete group invites
        const invitesSnapshot = await admin.firestore()
            .collection("group_invites")
            .where("groupId", "==", groupId)
            .get();

        invitesSnapshot.docs.forEach(doc => {
            batch.delete(doc.ref);
        });

        // Delete group requests
        const requestsSnapshot = await admin.firestore()
            .collection("group_requests")
            .where("groupId", "==", groupId)
            .get();

        requestsSnapshot.docs.forEach(doc => {
            batch.delete(doc.ref);
        });

        // Delete the group document
        batch.delete(groupRef);

        // Delete group image from storage if exists
        if (groupData.imageUrl) {
            try {
                const bucket = admin.storage().bucket();
                const urlMatch = groupData.imageUrl.match(/o\/(.+?)\?/);
                if (urlMatch) {
                    const filePath = decodeURIComponent(urlMatch[1]);
                    await bucket.file(filePath).delete();
                    console.log(`Deleted group image: ${filePath}`);
                }
            } catch (storageError) {
                console.warn("Failed to delete group image:", storageError.message);
            }
        }

        await batch.commit();

        console.log(`Group ${groupId} deleted by creator ${userId}`);
        return { success: true };
    } catch (error) {
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        console.error("Error deleting group:", error);
        throw new functions.https.HttpsError(
            "internal",
            `Erreur lors de la suppression du groupe: ${error.message}`
        );
    }
});

// ============================================================================
// EPHEMERAL MESSAGES CLEANUP
// ============================================================================

/**
 * Scheduled function to clean up expired ephemeral messages.
 * Runs every hour to delete messages where expiresAt < now.
 * Also deletes associated files from Storage.
 */
exports.cleanupExpiredMessages = functions.pubsub
    .schedule("every 1 hours")
    .onRun(async (context) => {
        console.log("Starting ephemeral messages cleanup...");
        const db = admin.database();
        const storage = admin.storage().bucket();
        const now = new Date().toISOString();

        let totalDeleted = 0;
        let totalFilesDeleted = 0;

        try {
            // Get all conversations from Firestore
            const conversationsSnapshot = await admin.firestore()
                .collection("conversations")
                .get();

            for (const convDoc of conversationsSnapshot.docs) {
                const conversationId = convDoc.id;

                // Get messages from RTDB for this conversation
                const messagesRef = db.ref(`messages/${conversationId}`);
                const messagesSnapshot = await messagesRef
                    .orderByChild("expiresAt")
                    .endAt(now)
                    .once("value");

                if (!messagesSnapshot.exists()) continue;

                const messagesToDelete = [];
                const filesToDelete = [];

                messagesSnapshot.forEach((messageSnap) => {
                    const message = messageSnap.val();
                    if (message.expiresAt && message.expiresAt <= now) {
                        messagesToDelete.push(messageSnap.key);

                        // Collect files to delete
                        if (message.fileUrl) {
                            try {
                                const urlMatch = message.fileUrl.match(/o\/(.+?)\?/);
                                if (urlMatch) {
                                    const filePath = decodeURIComponent(urlMatch[1]);
                                    filesToDelete.push(filePath);
                                }
                            } catch (e) {
                                console.warn("Failed to parse file URL:", e.message);
                            }
                        }

                        // Also delete thumbnail if exists
                        if (message.thumbnailUrl) {
                            try {
                                const urlMatch = message.thumbnailUrl.match(/o\/(.+?)\?/);
                                if (urlMatch) {
                                    const filePath = decodeURIComponent(urlMatch[1]);
                                    filesToDelete.push(filePath);
                                }
                            } catch (e) {
                                console.warn("Failed to parse thumbnail URL:", e.message);
                            }
                        }
                    }
                });

                // Delete messages from RTDB
                const updates = {};
                for (const messageId of messagesToDelete) {
                    updates[messageId] = null;
                }

                if (Object.keys(updates).length > 0) {
                    await messagesRef.update(updates);
                    totalDeleted += messagesToDelete.length;
                    console.log(`Deleted ${messagesToDelete.length} expired messages from conversation ${conversationId}`);
                }

                // Delete files from Storage
                for (const filePath of filesToDelete) {
                    try {
                        await storage.file(filePath).delete();
                        totalFilesDeleted++;
                    } catch (e) {
                        // File may already be deleted or not exist
                        console.warn(`Failed to delete file ${filePath}:`, e.message);
                    }
                }
            }

            console.log(`Cleanup complete. Deleted ${totalDeleted} messages and ${totalFilesDeleted} files.`);
            return null;
        } catch (error) {
            console.error("Error during ephemeral messages cleanup:", error);
            throw error;
        }
    });

// ============================================================================
// MEDIA FILE TTL CLEANUP (15-day expiry)
// ============================================================================

/**
 * Runs every 6 hours. Finds media messages whose 15-day Storage TTL has elapsed,
 * deletes the files from Firebase Storage, and marks the messages as mediaExpired.
 * The RTDB message record is preserved so the conversation history stays intact.
 */
exports.cleanupExpiredMediaFiles = functions.pubsub
    .schedule("every 6 hours")
    .onRun(async (context) => {
        const now = new Date().toISOString();
        const db = admin.database();
        const bucket = admin.storage().bucket();
        let totalMessages = 0;
        let totalFiles = 0;

        try {
            const convSnapshot = await db.ref("conversations").once("value");
            if (!convSnapshot.exists()) return null;

            for (const convId of Object.keys(convSnapshot.val())) {
                try {
                    const messagesRef = db.ref(`messages/${convId}`);
                    const snapshot = await messagesRef
                        .orderByChild("mediaExpiresAt")
                        .endAt(now)
                        .once("value");

                    if (!snapshot.exists()) continue;

                    const messages = snapshot.val();
                    const updates = {};
                    const filesToDelete = [];

                    for (const [msgId, msg] of Object.entries(messages)) {
                        if (msg.mediaExpired) continue;       // already processed
                        if (!msg.mediaExpiresAt) continue;    // not a media message

                        for (const field of ["fileUrl", "thumbnailUrl"]) {
                            if (msg[field]) {
                                const match = msg[field].match(/o\/(.+?)\?/);
                                if (match) filesToDelete.push(decodeURIComponent(match[1]));
                            }
                        }

                        updates[`${msgId}/mediaExpired`] = true;
                        updates[`${msgId}/fileUrl`] = null;
                        updates[`${msgId}/thumbnailUrl`] = null;
                        totalMessages++;
                    }

                    if (Object.keys(updates).length > 0) {
                        await messagesRef.update(updates);
                    }

                    for (const filePath of filesToDelete) {
                        try {
                            await bucket.file(filePath).delete();
                            totalFiles++;
                        } catch (e) {
                            console.warn(`[cleanupExpiredMediaFiles] Failed to delete ${filePath}:`, e.message);
                        }
                    }
                } catch (convError) {
                    console.warn(`[cleanupExpiredMediaFiles] Error processing conversation ${convId}:`, convError.message);
                }
            }

            console.log(`[cleanupExpiredMediaFiles] Done — ${totalMessages} messages marked, ${totalFiles} files deleted.`);
            return null;
        } catch (error) {
            console.error("[cleanupExpiredMediaFiles] Fatal error:", error);
            throw error;
        }
    });

// ============================================================================
// MULTI-DEVICE NOTIFICATION DISMISS SYNC
// ============================================================================

/**
 * Triggered when a notification is updated.
 * When isRead changes to true, sends a data-only FCM message to other devices
 * of the same user to dismiss the notification locally.
 *
 * This enables WhatsApp-like behavior: reading a message on one device
 * clears the notification on all other devices.
 */
exports.syncNotificationDismiss = functions.firestore
    .document("notifications/{notificationId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        const notificationId = context.params.notificationId;

        // Only trigger when isRead changes from false to true
        if (before.isRead || !after.isRead) {
            return null;
        }

        const userId = after.userId;
        if (!userId) {
            return null;
        }

        try {
            // Get user's FCM tokens
            const userDoc = await admin.firestore().collection("users").doc(userId).get();

            if (!userDoc.exists) {
                return null;
            }

            const userData = userDoc.data();
            const fcmTokens = userData.fcmTokens;

            if (!fcmTokens || !Array.isArray(fcmTokens) || fcmTokens.length <= 1) {
                // Only one or no device - no need to sync
                return null;
            }

            // Get the token that triggered this read (if available from readDeviceToken field)
            // We stored this when marking as read
            const triggerToken = after.readDeviceToken || null;

            // Send to all tokens except the one that triggered this read
            const targetTokens = triggerToken
                ? fcmTokens.filter((token) => token !== triggerToken)
                : fcmTokens;

            if (targetTokens.length === 0) {
                return null;
            }

            // Prepare dismiss data based on notification type
            const dismissData = {
                type: "notification_dismiss",
                notificationId: notificationId,
                notificationType: String(after.type || "general"),
            };

            // Add conversation-specific data for message notifications
            if (after.type === "message" && after.data?.conversationId) {
                dismissData.conversationId = after.data.conversationId;
            }

            // Add targetId for other notification types
            if (after.targetId) {
                dismissData.targetId = String(after.targetId);
            }

            // console.log(`Syncing notification dismiss to ${targetTokens.length} devices for user ${userId}`);

            // Send data-only FCM message (no notification payload, just data)
            const response = await admin.messaging().sendEachForMulticast({
                tokens: targetTokens,
                data: dismissData,
                android: {
                    priority: "high",
                },
                apns: {
                    headers: {
                        "apns-priority": "10",
                    },
                    payload: {
                        aps: {
                            "content-available": 1, // Silent push for iOS
                        },
                    },
                },
            });

            // Clean up invalid tokens
            if (response.failureCount > 0) {
                const invalidTokens = [];
                response.responses.forEach((resp, idx) => {
                    if (!resp.success && (
                        resp.error?.code === "messaging/invalid-registration-token" ||
                        resp.error?.code === "messaging/registration-token-not-registered"
                    )) {
                        invalidTokens.push(targetTokens[idx]);
                    }
                });

                if (invalidTokens.length > 0) {
                    await admin.firestore().collection("users").doc(userId).update({
                        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
                    });
                }
            }

            return { success: true, syncedDevices: response.successCount };
        } catch (error) {
            console.error("Error syncing notification dismiss:", error);
            return null;
        }
    });

/**
 * Callable function to dismiss notifications on all devices.
 * Called by the client when user reads a conversation (marks all messages as read).
 *
 * This is more efficient than triggering multiple onUpdate events.
 */
exports.dismissConversationNotifications = functions.https.onCall(async (data, context) => {
    // Require authentication
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "User must be authenticated"
        );
    }

    const userId = context.auth.uid;
    const { conversationId, currentToken } = data;

    if (!conversationId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "conversationId is required"
        );
    }

    try {
        // Get user's FCM tokens
        const userDoc = await admin.firestore().collection("users").doc(userId).get();

        if (!userDoc.exists) {
            return { success: true, syncedDevices: 0 };
        }

        const userData = userDoc.data();
        const fcmTokens = userData.fcmTokens;

        if (!fcmTokens || !Array.isArray(fcmTokens) || fcmTokens.length <= 1) {
            return { success: true, syncedDevices: 0 };
        }

        // Send to all tokens except the current device
        const targetTokens = currentToken
            ? fcmTokens.filter((token) => token !== currentToken)
            : fcmTokens;

        if (targetTokens.length === 0) {
            return { success: true, syncedDevices: 0 };
        }

        // console.log(`Dismissing conversation ${conversationId} notifications on ${targetTokens.length} devices`);

        // Send data-only FCM message
        const response = await admin.messaging().sendEachForMulticast({
            tokens: targetTokens,
            data: {
                type: "notification_dismiss",
                notificationType: "message",
                conversationId: conversationId,
            },
            android: {
                priority: "high",
            },
            apns: {
                headers: {
                    "apns-priority": "10",
                },
                payload: {
                    aps: {
                        "content-available": 1,
                    },
                },
            },
        });

        // Clean up invalid tokens
        if (response.failureCount > 0) {
            const invalidTokens = [];
            response.responses.forEach((resp, idx) => {
                if (!resp.success && (
                    resp.error?.code === "messaging/invalid-registration-token" ||
                    resp.error?.code === "messaging/registration-token-not-registered"
                )) {
                    invalidTokens.push(targetTokens[idx]);
                }
            });

            if (invalidTokens.length > 0) {
                await admin.firestore().collection("users").doc(userId).update({
                    fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
                });
            }
        }

        return { success: true, syncedDevices: response.successCount };
    } catch (error) {
        console.error("Error dismissing conversation notifications:", error);
        throw new functions.https.HttpsError(
            "internal",
            `Failed to dismiss notifications: ${error.message}`
        );
    }
});

// ============================================================================
// PROFILE SEARCH INDEXING
// ============================================================================

/**
 * Automatically maintains the displayNameLower field for case-insensitive search.
 * Triggers on user profile create/update.
 */
exports.maintainDisplayNameLower = functions.firestore
    .document("users/{userId}")
    .onWrite(async (change, context) => {
        // Skip if document was deleted
        if (!change.after.exists) {
            return null;
        }

        const newData = change.after.data();
        const previousData = change.before.exists ? change.before.data() : null;

        // Only update if displayName changed or displayNameLower is missing
        const displayNameChanged = !previousData ||
            previousData.displayName !== newData.displayName;
        const displayNameLowerMissing = !newData.displayNameLower;

        if (newData.displayName && (displayNameChanged || displayNameLowerMissing)) {
            const newLowerName = newData.displayName.toLowerCase();

            // Avoid infinite loop - only update if value actually differs
            if (newData.displayNameLower !== newLowerName) {
                return change.after.ref.update({
                    displayNameLower: newLowerName,
                });
            }
        }

        return null;
    });

/**
 * One-time migration function to add displayNameLower to all existing profiles.
 * Call this via HTTP once after deployment: https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/migrateDisplayNameLower
 *
 * This is a one-time admin operation - requires admin auth or call from Cloud Console.
 */
exports.migrateDisplayNameLower = functions.https.onRequest(async (req, res) => {
    // Only allow POST requests
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed. Use POST.");
        return;
    }

    try {
        const db = admin.firestore();
        const usersRef = db.collection("users");

        // Get all users without displayNameLower
        const snapshot = await usersRef.get();

        let updated = 0;
        let skipped = 0;
        let batch = db.batch();
        let batchCount = 0;
        const maxBatchSize = 500;

        for (const doc of snapshot.docs) {
            const data = doc.data();

            // Skip if already has displayNameLower or no displayName
            if (!data.displayName) {
                skipped++;
                continue;
            }

            const expectedLower = data.displayName.toLowerCase();
            if (data.displayNameLower === expectedLower) {
                skipped++;
                continue;
            }

            batch.update(doc.ref, { displayNameLower: expectedLower });
            batchCount++;
            updated++;

            // Commit and create a fresh batch (committed batches cannot be reused)
            if (batchCount >= maxBatchSize) {
                await batch.commit();
                batch = db.batch();
                batchCount = 0;
            }
        }

        // Commit remaining updates
        if (batchCount > 0) {
            await batch.commit();
        }

        console.log(`Migration complete: ${updated} updated, ${skipped} skipped`);
        res.status(200).json({
            success: true,
            updated,
            skipped,
            total: snapshot.size,
        });
    } catch (error) {
        console.error("Migration error:", error);
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

// ============================================================================
// CALLS CLEANUP - PREVENT STUCK CALLS
// ============================================================================

/**
 * Scheduled function that runs every minute to clean up stuck calls.
 *
 * This handles calls that get stuck due to:
 * - Network disconnection
 * - App crash
 * - Battery death
 * - User closing app without hanging up
 *
 * Timeouts:
 * - Ringing calls > 45 seconds → marked as 'missed'
 * - Connecting calls > 60 seconds → marked as 'ended' with 'connection_timeout'
 * - Connected calls > 4 hours → marked as 'ended' with 'max_duration_exceeded'
 * - Connected calls with missing heartbeat > 30s → marked as 'ended' with 'heartbeat_timeout'
 */
exports.cleanupStaleCalls = functions.pubsub
    .schedule("every 1 minutes")
    .onRun(async (context) => {
        const db = admin.firestore();
        const rtdb = admin.database();
        const now = Date.now();

        // Timeouts in milliseconds
        const RINGING_TIMEOUT = 45 * 1000;       // 45 seconds
        const CONNECTING_TIMEOUT = 60 * 1000;    // 60 seconds
        const HEARTBEAT_TIMEOUT = 45 * 1000;     // 45 seconds - if no heartbeat, party is dead (more forgiving)
        const MAX_CALL_DURATION = 4 * 60 * 60 * 1000; // 4 hours

        let cleanedCount = 0;
        let errors = [];

        try {
            // Get all non-terminal calls
            const activeStatuses = ['ringing', 'connecting', 'connected', 'reconnecting', 'onHold'];
            const callsSnapshot = await db.collection('calls')
                .where('status', 'in', activeStatuses)
                .get();

            console.log(`Found ${callsSnapshot.size} active calls to check`);

            for (const doc of callsSnapshot.docs) {
                const call = doc.data();
                const callId = doc.id;

                try {
                    // Parse createdAt timestamp
                    let createdAtMs;
                    if (call.createdAt && call.createdAt.toDate) {
                        createdAtMs = call.createdAt.toDate().getTime();
                    } else if (call.createdAt && typeof call.createdAt === 'string') {
                        createdAtMs = new Date(call.createdAt).getTime();
                    } else {
                        console.log(`Call ${callId}: Invalid createdAt, skipping`);
                        continue;
                    }

                    const callAge = now - createdAtMs;
                    let shouldCleanup = false;
                    let newStatus = '';
                    let endReason = '';

                    // Check ringing timeout
                    if (call.status === 'ringing' && callAge > RINGING_TIMEOUT) {
                        shouldCleanup = true;
                        newStatus = 'missed';
                        endReason = 'no_answer_timeout';
                        console.log(`Call ${callId}: Ringing timeout (${Math.round(callAge / 1000)}s)`);
                    }
                    // Check connecting timeout
                    else if (call.status === 'connecting' && callAge > CONNECTING_TIMEOUT) {
                        shouldCleanup = true;
                        newStatus = 'ended';
                        endReason = 'connection_timeout';
                        console.log(`Call ${callId}: Connecting timeout (${Math.round(callAge / 1000)}s)`);
                    }
                    // Check heartbeat for connected calls
                    else if (['connected', 'reconnecting', 'onHold'].includes(call.status)) {
                        // Check heartbeats in RTDB
                        try {
                            const heartbeatSnapshot = await rtdb.ref(`calls/${callId}/heartbeat`).get();
                            const heartbeats = heartbeatSnapshot.val();

                            if (heartbeats) {
                                const callerHeartbeat = heartbeats[call.callerId];
                                const calleeHeartbeat = heartbeats[call.calleeId];

                                // Check if either party has stopped sending heartbeats
                                const callerAlive = callerHeartbeat && (now - callerHeartbeat) < HEARTBEAT_TIMEOUT;
                                const calleeAlive = calleeHeartbeat && (now - calleeHeartbeat) < HEARTBEAT_TIMEOUT;

                                if (!callerAlive || !calleeAlive) {
                                    shouldCleanup = true;
                                    newStatus = 'ended';
                                    endReason = 'heartbeat_timeout';
                                    const deadParty = !callerAlive ? 'caller' : 'callee';
                                    console.log(`Call ${callId}: Heartbeat timeout - ${deadParty} not responding`);
                                }
                            } else {
                                // No heartbeat data at all - give grace period based on call age
                                // If call is connected for more than 2 minutes without heartbeats, clean it
                                if (callAge > 2 * 60 * 1000) {
                                    shouldCleanup = true;
                                    newStatus = 'ended';
                                    endReason = 'no_heartbeat_data';
                                    console.log(`Call ${callId}: No heartbeat data found, call is ${Math.round(callAge / 1000)}s old`);
                                }
                            }
                        } catch (heartbeatError) {
                            console.log(`Call ${callId}: Could not check heartbeat: ${heartbeatError.message}`);
                        }

                        // Also check max duration
                        if (!shouldCleanup && callAge > MAX_CALL_DURATION) {
                            shouldCleanup = true;
                            newStatus = 'ended';
                            endReason = 'max_duration_exceeded';
                            console.log(`Call ${callId}: Max duration exceeded (${Math.round(callAge / 3600000)}h)`);
                        }
                    }

                    if (shouldCleanup) {
                        // Calculate duration if call was answered
                        let durationSeconds = null;
                        if (call.answeredAt) {
                            let answeredAtMs;
                            if (call.answeredAt.toDate) {
                                answeredAtMs = call.answeredAt.toDate().getTime();
                            } else if (typeof call.answeredAt === 'string') {
                                answeredAtMs = new Date(call.answeredAt).getTime();
                            }
                            if (answeredAtMs) {
                                durationSeconds = Math.round((now - answeredAtMs) / 1000);
                            }
                        }

                        // Update Firestore
                        const updateData = {
                            status: newStatus,
                            endedAt: admin.firestore.FieldValue.serverTimestamp(),
                            endReason: endReason,
                        };
                        if (durationSeconds !== null) {
                            updateData.durationSeconds = durationSeconds;
                        }

                        await doc.ref.update(updateData);

                        // Cleanup RTDB signaling data
                        try {
                            await rtdb.ref(`calls/${callId}`).remove();
                        } catch (rtdbError) {
                            console.log(`Call ${callId}: RTDB cleanup failed (may not exist): ${rtdbError.message}`);
                        }

                        cleanedCount++;
                    }
                } catch (callError) {
                    errors.push({ callId, error: callError.message });
                    console.error(`Error processing call ${callId}:`, callError);
                }
            }

            console.log(`Cleanup complete: ${cleanedCount} calls cleaned, ${errors.length} errors`);
            return { success: true, cleaned: cleanedCount, errors };

        } catch (error) {
            console.error('Cleanup job failed:', error);
            return { success: false, error: error.message };
        }
    });

/**
 * Scheduled cleanup for orphaned group calls.
 * Runs every 5 minutes and ends group calls where:
 * - All participants are gone or have stale heartbeats (> 2 min)
 * - Call has exceeded max duration (4h)
 */
exports.cleanupStaleGroupCalls = functions.pubsub
    .schedule("every 5 minutes")
    .onRun(async (context) => {
        const db = admin.firestore();
        const now = Date.now();
        const HEARTBEAT_TIMEOUT = 2 * 60 * 1000;  // 2 min without heartbeat
        const MAX_DURATION = 4 * 60 * 60 * 1000;  // 4h max

        try {
            const snapshot = await db.collection("group_calls")
                .where("status", "==", "active")
                .get();

            let cleaned = 0;

            for (const doc of snapshot.docs) {
                const data = doc.data();
                const createdAt = data.createdAt?.toDate?.()?.getTime() ?? 0;
                const age = now - createdAt;

                // Max duration exceeded
                if (age > MAX_DURATION) {
                    await doc.ref.update({
                        status: "ended",
                        endedAt: admin.firestore.FieldValue.serverTimestamp(),
                        endReason: "max_duration_exceeded",
                    });
                    cleaned++;
                    console.log(`Group call ${doc.id}: max duration exceeded`);
                    continue;
                }

                // Check active participants
                const activeParticipants = await doc.ref.collection("participants")
                    .where("status", "==", "active")
                    .get();

                if (activeParticipants.empty) {
                    await doc.ref.update({
                        status: "ended",
                        endedAt: admin.firestore.FieldValue.serverTimestamp(),
                        endReason: "all_participants_gone",
                    });
                    cleaned++;
                    console.log(`Group call ${doc.id}: no active participants`);
                    continue;
                }

                // Check if all active participants have stale heartbeats
                const staleThreshold = new Date(now - HEARTBEAT_TIMEOUT);
                const allStale = activeParticipants.docs.every(p => {
                    const hb = p.data().lastHeartbeat?.toDate?.();
                    return !hb || hb < staleThreshold;
                });

                if (allStale) {
                    await doc.ref.update({
                        status: "ended",
                        endedAt: admin.firestore.FieldValue.serverTimestamp(),
                        endReason: "heartbeat_timeout",
                    });
                    cleaned++;
                    console.log(`Group call ${doc.id}: all participants heartbeat stale`);
                }
            }

            console.log(`cleanupStaleGroupCalls: ended ${cleaned} orphaned group calls`);
            return { success: true, cleaned };
        } catch (error) {
            console.error("cleanupStaleGroupCalls failed:", error);
            return { success: false, error: error.message };
        }
    });

/**
 * HTTP endpoint to manually trigger call cleanup (for testing/debugging).
 * Only accessible by admins.
 */
exports.manualCallCleanup = functions.https.onCall(async (data, context) => {
    // Require authentication
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Must be authenticated to trigger cleanup"
        );
    }

    // Check if user is admin
    const userDoc = await admin.firestore()
        .collection("users")
        .doc(context.auth.uid)
        .get();

    if (!userDoc.exists || !userDoc.data().adminRole || userDoc.data().adminRole === "none") {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Only admins can trigger manual cleanup"
        );
    }

    const db = admin.firestore();
    const rtdb = admin.database();
    const now = Date.now();

    const RINGING_TIMEOUT = 45 * 1000;
    const CONNECTING_TIMEOUT = 60 * 1000;

    // Option to force cleanup ALL active calls regardless of age
    const forceAll = data && data.forceAll === true;

    let cleanedCount = 0;

    try {
        const activeStatuses = ['ringing', 'connecting', 'connected', 'reconnecting', 'onHold'];
        const callsSnapshot = await db.collection('calls')
            .where('status', 'in', activeStatuses)
            .get();

        console.log(`Manual cleanup: Found ${callsSnapshot.size} active calls, forceAll=${forceAll}`);

        for (const doc of callsSnapshot.docs) {
            const call = doc.data();
            const callId = doc.id;

            let shouldCleanup = forceAll; // If forceAll, always cleanup
            let newStatus = 'ended';
            let endReason = forceAll ? 'admin_force_cleanup' : '';

            if (!forceAll) {
                let createdAtMs;
                if (call.createdAt && call.createdAt.toDate) {
                    createdAtMs = call.createdAt.toDate().getTime();
                } else if (call.createdAt && typeof call.createdAt === 'string') {
                    createdAtMs = new Date(call.createdAt).getTime();
                } else {
                    continue;
                }

                const callAge = now - createdAtMs;

                if (call.status === 'ringing' && callAge > RINGING_TIMEOUT) {
                    shouldCleanup = true;
                    newStatus = 'missed';
                    endReason = 'no_answer_timeout';
                } else if (call.status === 'connecting' && callAge > CONNECTING_TIMEOUT) {
                    shouldCleanup = true;
                    newStatus = 'ended';
                    endReason = 'connection_timeout';
                }
            }

            if (shouldCleanup) {
                console.log(`Manual cleanup: Cleaning call ${callId} (status: ${call.status})`);

                await doc.ref.update({
                    status: newStatus,
                    endedAt: admin.firestore.FieldValue.serverTimestamp(),
                    endReason: endReason,
                });

                try {
                    await rtdb.ref(`calls/${callId}`).remove();
                } catch (e) {
                    // Ignore RTDB errors
                }

                cleanedCount++;
            }
        }

        console.log(`Manual cleanup complete: ${cleanedCount}/${callsSnapshot.size} cleaned`);

        return {
            success: true,
            cleaned: cleanedCount,
            total: callsSnapshot.size,
        };
    } catch (error) {
        throw new functions.https.HttpsError(
            "internal",
            `Cleanup failed: ${error.message}`
        );
    }
});

// ============================================================================
// MARKETPLACE: ESCROW RELEASE, REFUNDS, TIMEOUTS, AND CARD CREDIT STUB
// ============================================================================

/**
 * Resolve a seller's Stripe Connect account id by looking at:
 *  1. creatorProfiles/{sellerId}.stripeAccountId (creators)
 *  2. users/{sellerId}/payment_accounts/* with stripeAccountId set (marketplace sellers)
 *
 * Returns the first match or null if none.
 */
async function resolveSellerStripeAccountId(sellerId) {
    if (!sellerId) return null;
    const db = admin.firestore();

    try {
        const creatorDoc = await db.collection("creatorProfiles").doc(sellerId).get();
        if (creatorDoc.exists) {
            const data = creatorDoc.data();
            if (data.stripeAccountId) return data.stripeAccountId;
        }
    } catch (err) {
        console.warn(`resolveSellerStripeAccountId(creatorProfiles): ${err.message}`);
    }

    try {
        const paSnap = await db.collection("users").doc(sellerId).collection("payment_accounts").get();
        for (const doc of paSnap.docs) {
            const data = doc.data();
            if (data.stripeAccountId) return data.stripeAccountId;
        }
    } catch (err) {
        console.warn(`resolveSellerStripeAccountId(payment_accounts): ${err.message}`);
    }

    return null;
}

/**
 * Process an escrow release request (BUG-04, BIZ-04).
 *
 * Triggered when a document is created in `escrow_release_requests/{id}` by either:
 *  - the buyer (manual confirmation after delivery)
 *  - the `checkEscrowTimeouts` scheduled function (auto-release after 14 days)
 *
 * The function:
 *  1. Validates the requester (buyerId == userId, or system request)
 *  2. Loads the order and verifies state == 'delivered' and escrowStatus == 'holding'
 *  3. Resolves the seller's Stripe Connect account
 *  4. Creates a Stripe Transfer for the seller share
 *  5. Marks the order as completed/released
 *
 * The request document is updated with status `succeeded` or `failed` so the
 * Flutter client can react via a snapshot listener.
 */
exports.processEscrowRelease = functions.firestore
    .document("escrow_release_requests/{requestId}")
    .onCreate(async (snapshot, context) => {
        const data = snapshot.data();
        const requestId = context.params.requestId;
        const db = admin.firestore();

        console.log(`Processing escrow release request: ${requestId}`);

        const failRequest = async (reason) => {
            console.error(`Escrow release ${requestId} failed: ${reason}`);
            await snapshot.ref.update({
                status: "failed",
                error: reason,
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        };

        try {
            const { orderId, userId } = data;
            // System releases (from checkEscrowTimeouts) are written via Admin SDK with no userId field.
            // Client releases always include userId (enforced by Firestore rules).
            // Never trust a client-supplied isSystem flag.
            const isSystem = !userId;
            if (!orderId) {
                return failRequest("Missing orderId");
            }

            const orderRef = db.collection("orders").doc(orderId);

            // Atomically claim the escrow: transition holding → releasing inside a
            // transaction so concurrent retries cannot both proceed to Stripe.
            let order;
            try {
                await db.runTransaction(async (tx) => {
                    const orderSnap = await tx.get(orderRef);
                    if (!orderSnap.exists) {
                        throw Object.assign(new Error(`Order ${orderId} not found`), { bailCode: "not_found" });
                    }
                    const o = orderSnap.data();

                    if (!isSystem && o.buyerId !== userId) {
                        throw Object.assign(new Error("Caller is not the order buyer"), { bailCode: "permission" });
                    }
                    if (o.status !== "delivered") {
                        throw Object.assign(new Error(`Order status is ${o.status}, expected 'delivered'`), { bailCode: "bad_state" });
                    }
                    if (o.escrowStatus && o.escrowStatus !== "holding") {
                        throw Object.assign(new Error(`Escrow status is ${o.escrowStatus}, expected 'holding'`), { bailCode: "bad_state" });
                    }

                    // Lock the escrow so no concurrent request can also proceed
                    tx.update(orderRef, { escrowStatus: "releasing" });
                    order = o;
                });
            } catch (txErr) {
                if (txErr.bailCode) return failRequest(txErr.message);
                throw txErr;
            }

            // Resolve seller Stripe account
            const stripeAccountId = await resolveSellerStripeAccountId(order.sellerId);
            if (!stripeAccountId) {
                // Restore escrow status since we locked it but won't transfer
                await orderRef.update({ escrowStatus: "holding" });
                return failRequest("Seller has no Stripe Connect account configured");
            }

            // Compute seller share — use major units as stored; skip ×100 for zero-decimal currencies
            const sellerAmount = Number(order.sellerAmount);
            if (!sellerAmount || sellerAmount <= 0) {
                await orderRef.update({ escrowStatus: "holding" });
                return failRequest(`Invalid sellerAmount: ${order.sellerAmount}`);
            }
            const currency = (order.currency || "eur").toLowerCase();
            const amountInCents = ZERO_DECIMAL_CURRENCIES.has(currency)
                ? Math.round(sellerAmount)
                : Math.round(sellerAmount * 100);

            // Create Stripe Transfer
            const stripeInstance = getStripe();
            const transferParams = {
                amount: amountInCents,
                currency,
                destination: stripeAccountId,
                metadata: {
                    orderId,
                    sellerId: order.sellerId,
                    requestId,
                },
            };
            // Link to source charge for traceability when available
            if (order.paymentIntentId) {
                transferParams.transfer_group = order.paymentIntentId;
            }

            let transfer;
            try {
                transfer = await stripeInstance.transfers.create(transferParams);
            } catch (stripeErr) {
                // Stripe call failed — restore escrow so the operation can be retried
                await orderRef.update({ escrowStatus: "holding" });
                throw stripeErr;
            }
            console.log(`Stripe Transfer created: ${transfer.id} for order ${orderId}`);

            // Update order
            await orderRef.update({
                status: "completed",
                escrowStatus: "released",
                completedAt: admin.firestore.FieldValue.serverTimestamp(),
                stripeTransferId: transfer.id,
            });

            // Update request
            await snapshot.ref.update({
                status: "succeeded",
                stripeTransferId: transfer.id,
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            return { success: true, transferId: transfer.id };
        } catch (error) {
            return failRequest(error.message);
        }
    });

/**
 * Issue an automatic refund when an order with held escrow is cancelled (BIZ-03, BUG-10).
 *
 * Triggered on order updates: when `status` transitions from a non-cancelled state
 * to `cancelled` AND `escrowStatus` was `holding`, we refund the buyer's PaymentIntent.
 *
 * Disputes (`status: 'disputed'`) freeze the escrow and do NOT auto-refund.
 *
 * NOTE: this is added as a SECOND `onUpdate` trigger so as not to perturb the existing
 * `onOrderUpdated` notification logic.
 */
exports.refundCancelledOrder = functions.firestore
    .document("orders/{orderId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        const orderId = context.params.orderId;

        const becameCancelled = before.status !== "cancelled" && after.status === "cancelled";
        if (!becameCancelled) return null;

        // Only refund when there was actually money in escrow
        if (before.escrowStatus !== "holding") {
            return null;
        }

        // Skip if a refund has already been processed (check server-written field only)
        if (after.stripeRefundId) {
            return null;
        }

        if (!after.paymentIntentId) {
            console.warn(`refundCancelledOrder: order ${orderId} has no paymentIntentId, cannot refund`);
            return null;
        }

        try {
            const stripeInstance = getStripe();
            const refund = await stripeInstance.refunds.create({
                payment_intent: after.paymentIntentId,
                metadata: {
                    orderId,
                    reason: after.cancellationReason || "order_cancelled",
                },
            });

            console.log(`Refund created: ${refund.id} for order ${orderId}`);

            await change.after.ref.update({
                stripeRefundId: refund.id,
                escrowStatus: "refunded",
                refundedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            return { success: true, refundId: refund.id };
        } catch (error) {
            console.error(`refundCancelledOrder error for ${orderId}:`, error);
            // Surface the failure on the order so the buyer/admin can act on it
            await change.after.ref.update({
                refundError: error.message,
                refundFailedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            return { success: false, error: error.message };
        }
    });

/**
 * Scheduled escrow auto-release and reminders (BIZ-01).
 *
 * Runs every 6 hours and:
 *  - Auto-releases escrow on orders that have been `delivered` for more than 14 days
 *    by creating a system `escrow_release_requests` document (which is then handled
 *    by `processEscrowRelease`).
 *  - Sends a reminder notification to buyers whose orders have been `shipped` for
 *    more than 30 days but not yet confirmed delivered.
 *  - Skips orders in `disputed` state (escrow frozen).
 */
exports.checkEscrowTimeouts = functions.pubsub
    .schedule("every 6 hours")
    .onRun(async () => {
        const db = admin.firestore();
        const now = admin.firestore.Timestamp.now();
        const fourteenDaysAgo = admin.firestore.Timestamp.fromMillis(
            now.toMillis() - 14 * 24 * 60 * 60 * 1000
        );
        const thirtyDaysAgo = admin.firestore.Timestamp.fromMillis(
            now.toMillis() - 30 * 24 * 60 * 60 * 1000
        );

        // 1) Auto-release: delivered > 14 days, escrow still holding
        try {
            const deliveredSnap = await db.collection("orders")
                .where("status", "==", "delivered")
                .where("escrowStatus", "==", "holding")
                .where("deliveredAt", "<=", fourteenDaysAgo)
                .limit(100)
                .get();

            for (const doc of deliveredSnap.docs) {
                const orderId = doc.id;
                console.log(`Auto-releasing escrow for order ${orderId} (delivered > 14d)`);
                await db.collection("escrow_release_requests").add({
                    orderId,
                    reason: "auto_release_timeout_14d",
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    status: "pending",
                });
            }
        } catch (err) {
            console.error("checkEscrowTimeouts: auto-release scan failed", err);
        }

        // 2) Shipping reminder: shipped > 30 days, not yet delivered
        try {
            const shippedSnap = await db.collection("orders")
                .where("status", "==", "shipped")
                .where("shippedAt", "<=", thirtyDaysAgo)
                .limit(100)
                .get();

            for (const doc of shippedSnap.docs) {
                const order = doc.data();
                if (order.shippingReminderSentAt) continue;
                await db.collection("notifications").add({
                    userId: order.buyerId,
                    type: "orderShippingReminder",
                    title: "Confirmer la reception",
                    body: `Avez-vous bien recu "${order.productTitle}" ? Merci de confirmer la reception.`,
                    targetId: doc.id,
                    data: { orderId: doc.id },
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                await doc.ref.update({
                    shippingReminderSentAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
        } catch (err) {
            console.error("checkEscrowTimeouts: shipping reminder scan failed", err);
        }

        return null;
    });

/**
 * Process marketplace order payment verification (BUG-05).
 *
 * Flow:
 *  1. Buyer pays via Stripe payment sheet (Stripe SDK on the device).
 *  2. Buyer creates a marketplace order with status='pending' and paymentIntentId set.
 *  3. Buyer creates a document in `order_payment_requests/{id}` with
 *     `{ orderId, paymentIntentId, userId }`.
 *  4. This function retrieves the PaymentIntent from Stripe, verifies it's
 *     `succeeded`, and only then marks the order as `paid` + `escrowStatus: holding`.
 *
 * Firestore rules block clients from transitioning pending → paid, so this
 * server-side verification is the only path to mark an order as paid.
 */
exports.processOrderPayment = functions.firestore
    .document("order_payment_requests/{requestId}")
    .onCreate(async (snapshot, context) => {
        const data = snapshot.data();
        const requestId = context.params.requestId;
        const db = admin.firestore();

        console.log(`Processing order payment request: ${requestId}`);

        const failRequest = async (reason) => {
            console.error(`Order payment ${requestId} failed: ${reason}`);
            await snapshot.ref.update({
                status: "failed",
                error: reason,
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        };

        try {
            const { orderId, paymentIntentId, userId } = data;
            if (!orderId || !paymentIntentId || !userId) {
                return failRequest("Missing orderId, paymentIntentId or userId");
            }

            const orderRef = db.collection("orders").doc(orderId);
            const orderSnap = await orderRef.get();
            if (!orderSnap.exists) {
                return failRequest(`Order ${orderId} not found`);
            }
            const order = orderSnap.data();

            if (order.buyerId !== userId) {
                return failRequest("Caller is not the order buyer");
            }
            if (order.status !== "pending") {
                // Idempotency: already processed (e.g. duplicate request)
                if (order.status === "paid" && order.paymentIntentId === paymentIntentId) {
                    await snapshot.ref.update({
                        status: "succeeded",
                        idempotent: true,
                        processedAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                    return { success: true, idempotent: true };
                }
                return failRequest(`Order status is ${order.status}, expected 'pending'`);
            }

            // Retrieve the payment intent from Stripe — this is the source of truth
            const stripeInstance = getStripe();
            const paymentIntent = await stripeInstance.paymentIntents.retrieve(paymentIntentId);

            if (paymentIntent.status !== "succeeded") {
                return failRequest(`PaymentIntent status is ${paymentIntent.status}, expected 'succeeded'`);
            }

            // Verify amount: order stores in major units, Stripe stores in cents
            const orderCurrency = (order.currency || "eur").toLowerCase();
            const piCurrency = (paymentIntent.currency || "").toLowerCase();
            if (piCurrency !== orderCurrency) {
                return failRequest(`PaymentIntent currency ${piCurrency} does not match order currency ${orderCurrency}`);
            }
            const expectedCents = Math.round(Number(order.totalPrice) * (ZERO_DECIMAL_CURRENCIES.has(orderCurrency) ? 1 : 100));
            if (paymentIntent.amount !== expectedCents) {
                return failRequest(`PaymentIntent amount ${paymentIntent.amount} does not match order totalPrice ${expectedCents}`);
            }

            // Prevent PaymentIntent reuse: ensure this PI hasn't already paid a different order
            const existingOrderSnap = await db.collection("orders")
                .where("paymentIntentId", "==", paymentIntentId)
                .where("status", "in", ["paid", "shipped", "delivered", "completed"])
                .limit(1)
                .get();
            if (!existingOrderSnap.empty && existingOrderSnap.docs[0].id !== orderId) {
                return failRequest(`PaymentIntent ${paymentIntentId} has already been used for a different order`);
            }

            // Verify the buyer matches the metadata if present
            if (paymentIntent.metadata && paymentIntent.metadata.userId && paymentIntent.metadata.userId !== userId) {
                return failRequest("PaymentIntent userId does not match buyer");
            }

            // Mark order as paid (admin SDK bypasses rules)
            await orderRef.update({
                status: "paid",
                escrowStatus: "holding",
                paymentIntentId,
                paidAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            await snapshot.ref.update({
                status: "succeeded",
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Notify the seller
            try {
                await db.collection("notifications").add({
                    userId: order.sellerId,
                    type: "orderPaid",
                    title: "Paiement recu",
                    body: `Votre commande "${order.productTitle}" a ete payee`,
                    targetId: orderId,
                    data: { orderId },
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            } catch (notifErr) {
                console.warn(`processOrderPayment: failed to notify seller: ${notifErr.message}`);
            }

            return { success: true };
        } catch (error) {
            console.error(`processOrderPayment error for ${requestId}:`, error);
            return failRequest(error.message);
        }
    });

/**
 * Process card credit (Visa Direct / Mastercard Send) requests (INT-05).
 *
 * Real Visa Direct / Mastercard Send integration is not implemented yet.
 *  - In partner mock mode (default), simulates a successful credit so the rest
 *    of the transfer flow can be exercised end-to-end.
 *  - In production mode, marks the request as `not_implemented` and lets the
 *    UI surface a "Bientot disponible" message.
 */
exports.processCardCreditRequest = functions.firestore
    .document("card_credit_requests/{requestId}")
    .onCreate(async (snapshot, context) => {
        const data = snapshot.data();
        const requestId = context.params.requestId;
        const db = admin.firestore();

        console.log(`Processing card credit request: ${requestId}`);

        // Same toggle as the partner clients (default ON unless explicitly disabled)
        const mockMode = process.env.PARTNER_MOCK_MODE !== "false";

        try {
            if (mockMode) {
                // Simulate success — generate a fake partner reference
                const fakeRef = `mock_card_${Date.now()}`;
                await snapshot.ref.update({
                    status: "succeeded",
                    partnerTransactionId: fakeRef,
                    mock: true,
                    processedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                if (data.transactionId) {
                    await db.collection("transactions").doc(data.transactionId).update({
                        status: "completed",
                        creditTransactionId: fakeRef,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                }
                return { success: true, mock: true };
            }

            // Production: not yet implemented
            await snapshot.ref.update({
                status: "not_implemented",
                error: "Visa Direct / Mastercard Send integration not yet available",
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            if (data.transactionId) {
                await db.collection("transactions").doc(data.transactionId).update({
                    status: "failed",
                    failureReason: "Card credit not implemented",
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
            return { success: false, error: "not_implemented" };
        } catch (error) {
            console.error(`processCardCreditRequest error for ${requestId}:`, error);
            await snapshot.ref.update({
                status: "failed",
                error: error.message,
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            return { success: false, error: error.message };
        }
    });

// ============================================================================
// FEED SOCIAL — Notifications
// ============================================================================

exports.onPostLiked = functions.firestore
    .document("post_likes/{likeId}")
    .onCreate(async (snapshot) => {
        const data = snapshot.data();
        const { userId: likerId, postId } = data;

        const postSnap = await admin.firestore().collection("posts").doc(postId).get();
        if (!postSnap.exists) return null;

        const authorId = postSnap.data().authorId;
        if (likerId === authorId) return null;

        const likerSnap = await admin.firestore().collection("users").doc(likerId).get();
        const likerName = likerSnap.exists ? (likerSnap.data().displayName || "Quelqu'un") : "Quelqu'un";

        await admin.firestore().collection("notifications").add({
            userId: authorId,
            type: "post_liked",
            title: "Nouveau j'aime",
            body: `${likerName} a aimé votre publication`,
            data: { postId, likerId },
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return null;
    });

exports.onPostCommented = functions.firestore
    .document("post_comments/{commentId}")
    .onCreate(async (snapshot) => {
        const data = snapshot.data();
        const { authorId: commentAuthorId, postId, content } = data;

        const postSnap = await admin.firestore().collection("posts").doc(postId).get();
        if (!postSnap.exists) return null;

        const postAuthorId = postSnap.data().authorId;
        if (commentAuthorId === postAuthorId) return null;

        const commenterSnap = await admin.firestore().collection("users").doc(commentAuthorId).get();
        const commenterName = commenterSnap.exists
            ? (commenterSnap.data().displayName || "Quelqu'un")
            : "Quelqu'un";

        const preview = content && content.length > 50 ? content.substring(0, 50) + "…" : (content || "");

        await admin.firestore().collection("notifications").add({
            userId: postAuthorId,
            type: "post_commented",
            title: "Nouveau commentaire",
            body: `${commenterName} a commenté : ${preview}`,
            data: { postId, commentAuthorId },
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return null;
    });

exports.onNewPostCreated = functions.firestore
    .document("posts/{postId}")
    .onCreate(async (snapshot, context) => {
        const postId = context.params.postId;
        const post = snapshot.data();
        const { authorId, authorName } = post;

        const followsSnap = await admin.firestore()
            .collection("user_follows")
            .where("followingId", "==", authorId)
            .limit(500)
            .get();

        if (followsSnap.empty) return null;

        const batch = admin.firestore().batch();
        const preview = post.content && post.content.length > 60
            ? post.content.substring(0, 60) + "…"
            : (post.content || "Nouvelle publication");

        for (const doc of followsSnap.docs) {
            const followerId = doc.data().followerId;
            if (followerId === authorId) continue;
            const notifRef = admin.firestore().collection("notifications").doc();
            batch.set(notifRef, {
                userId: followerId,
                type: "new_post",
                title: authorName || "Nouvelle publication",
                body: preview,
                data: { postId, authorId },
                isRead: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        await batch.commit();

        // Notify mentioned users
        const mentionedUsers = post.mentionedUsers || [];
        if (mentionedUsers.length > 0) {
            const mentionBatch = admin.firestore().batch();
            for (const mention of mentionedUsers) {
                if (!mention.id || mention.id === authorId) continue;
                const notifRef = admin.firestore().collection("notifications").doc();
                mentionBatch.set(notifRef, {
                    userId: mention.id,
                    type: "mentioned",
                    title: "Vous avez été mentionné(e)",
                    body: `${authorName || "Quelqu'un"} vous a mentionné(e) dans une publication`,
                    data: { postId, authorId },
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
            await mentionBatch.commit();
        }

        // Notify group members when a group is mentioned
        const mentionedGroups = post.mentionedGroups || [];
        if (mentionedGroups.length > 0) {
            const groupBatch = admin.firestore().batch();
            for (const group of mentionedGroups) {
                const memberIds = group.memberIds || [];
                for (const memberId of memberIds) {
                    if (!memberId || memberId === authorId) continue;
                    const notifRef = admin.firestore().collection("notifications").doc();
                    groupBatch.set(notifRef, {
                        userId: memberId,
                        type: "group_mention",
                        title: `${group.name || "Votre groupe"} a été mentionné`,
                        body: `${authorName || "Quelqu'un"} a mentionné ${group.name || "votre groupe"} dans une publication`,
                        data: { postId, authorId, groupId: group.id },
                        isRead: false,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                }
            }
            await groupBatch.commit();
        }

        return null;
    });

// ----------------------------------------------------------------------------
// onCommentMention — SUPPRIMÉ (trigger mort).
//
// C'était un trigger Firestore sur `post_comments/{commentId}`, alors que les
// commentaires ont migré vers Supabase (`post_comments` en Postgres) : il ne
// pouvait plus se déclencher, et les notifications de mention en commentaire
// n'arrivaient donc déjà plus à personne. Il écrivait de surcroît dans la
// collection Firestore `notifications`, elle aussi migrée.
//
// Ne PAS le « réparer » à l'aveugle : les notifications de mention doivent
// passer par la RPC `create_user_notification` (SECURITY DEFINER) côté app,
// ou par un trigger Postgres sur `post_comments`. Le remettre ici ferait
// doublon avec la création côté app.
// ----------------------------------------------------------------------------

// ============================================================================
// LIVEKIT VIDEO — AUDIO ROOMS & LIVE PODCASTS
// ============================================================================

function _getLiveKitCredentials() {
    const apiKey = process.env.LIVEKIT_API_KEY || functions.config().livekit?.api_key;
    const apiSecret = process.env.LIVEKIT_API_SECRET || functions.config().livekit?.api_secret;
    const serverUrl = process.env.LIVEKIT_SERVER_URL || functions.config().livekit?.server_url || "wss://livekit.diasponiger.com";
    if (!apiKey || !apiSecret) {
        throw new functions.https.HttpsError("failed-precondition", "LiveKit credentials not configured");
    }
    return { apiKey, apiSecret, serverUrl };
}

/**
 * Generate a LiveKit token for joining an audio room with video enabled.
 * Accepts audioRooms as the source collection (vs getLiveKitToken which uses group_calls).
 * Called from AudioRoomSessionNotifier when isVideoEnabled == true.
 */
exports.getAudioRoomLiveKitToken = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    const { roomId, participantName, canPublish = true } = data;
    if (!roomId || typeof roomId !== "string") {
        throw new functions.https.HttpsError("invalid-argument", "roomId is required");
    }

    // Verify room exists and user is allowed
    const roomDoc = await admin.firestore().collection("audioRooms").doc(roomId).get();
    if (!roomDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Audio room not found");
    }
    const roomData = roomDoc.data();
    const uid = context.auth.uid;
    const isAllowed =
        roomData.hostId === uid ||
        (roomData.coHostIds || []).includes(uid) ||
        (roomData.speakerIds || []).includes(uid) ||
        (roomData.listenerIds || []).includes(uid) ||
        (!roomData.isPrivate);
    if (!isAllowed) {
        throw new functions.https.HttpsError("permission-denied", "You are not allowed in this room");
    }

    const { apiKey, apiSecret } = _getLiveKitCredentials();
    const livekitRoomName = `audio-room-${roomId}`;

    const at = new AccessToken(apiKey, apiSecret, {
        identity: uid,
        name: participantName || uid,
        ttl: "8h",
    });
    at.addGrant({
        room: livekitRoomName,
        roomJoin: true,
        canPublish,
        canPublishData: true,
        canSubscribe: true,
        canUpdateOwnMetadata: true,
    });

    const token = await at.toJwt();
    console.log(`AudioRoom LiveKit token for ${uid} in room ${roomId}`);
    return { token, livekitRoomName, identity: uid };
});

/**
 * Start a LiveKit Egress recording for an audio room.
 * Only the room host can call this.
 * Requires LiveKit Egress service to be running alongside the server.
 */
exports.startEgressRecording = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    const { roomId } = data;
    if (!roomId) throw new functions.https.HttpsError("invalid-argument", "roomId required");

    const roomDoc = await admin.firestore().collection("audioRooms").doc(roomId).get();
    if (!roomDoc.exists) throw new functions.https.HttpsError("not-found", "Room not found");
    if (roomDoc.data().hostId !== context.auth.uid) {
        throw new functions.https.HttpsError("permission-denied", "Only the host can start recording");
    }

    const { apiKey, apiSecret, serverUrl } = _getLiveKitCredentials();
    const livekitRoomName = `audio-room-${roomId}`;
    const egressClient = new EgressClient(serverUrl, apiKey, apiSecret);

    const storagePath = `audio-rooms/${roomId}/replay/recording_${Date.now()}.mp4`;
    try {
        const egress = await egressClient.startRoomCompositeEgress(livekitRoomName, {
            fileOutputs: [{
                filepath: storagePath,
                s3: {
                    bucket: process.env.FIREBASE_STORAGE_BUCKET || functions.config().storage?.bucket,
                    region: "auto",
                    forcePathStyle: true,
                },
            }],
        });
        await admin.firestore().collection("audioRooms").doc(roomId).update({
            egressId: egress.egressId,
            egressStoragePath: storagePath,
            egressStartedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`Egress started for room ${roomId}: ${egress.egressId}`);
        return { success: true, egressId: egress.egressId };
    } catch (e) {
        console.error("startEgressRecording error:", e);
        throw new functions.https.HttpsError("internal", `Failed to start recording: ${e.message}`);
    }
});

/**
 * Stop a LiveKit Egress recording and save the resulting video URL to Firestore.
 * Called when the room ends and isVideoEnabled && isRecordingEnabled.
 */
exports.stopEgressRecording = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    const { roomId, replayId } = data;
    if (!roomId) throw new functions.https.HttpsError("invalid-argument", "roomId required");

    const roomDoc = await admin.firestore().collection("audioRooms").doc(roomId).get();
    if (!roomDoc.exists) throw new functions.https.HttpsError("not-found", "Room not found");
    if (roomDoc.data().hostId !== context.auth.uid) {
        throw new functions.https.HttpsError("permission-denied", "Only the host can stop recording");
    }

    const { egressId, egressStoragePath } = roomDoc.data();
    if (!egressId) throw new functions.https.HttpsError("not-found", "No active recording found");

    const { apiKey, apiSecret, serverUrl } = _getLiveKitCredentials();
    const egressClient = new EgressClient(serverUrl, apiKey, apiSecret);

    try {
        await egressClient.stopEgress(egressId);
        const bucket = process.env.FIREBASE_STORAGE_BUCKET || functions.config().storage?.bucket;
        const videoUrl = `https://storage.googleapis.com/${bucket}/${egressStoragePath}`;

        const updates = {
            egressId: admin.firestore.FieldValue.delete(),
            egressStoragePath: admin.firestore.FieldValue.delete(),
        };
        await admin.firestore().collection("audioRooms").doc(roomId).update(updates);

        if (replayId) {
            await admin.firestore().collection("roomReplays").doc(replayId).update({
                videoUrl,
                mediaType: "video",
                status: "available",
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        console.log(`Egress stopped for room ${roomId}, videoUrl: ${videoUrl}`);
        return { success: true, videoUrl };
    } catch (e) {
        console.error("stopEgressRecording error:", e);
        throw new functions.https.HttpsError("internal", `Failed to stop recording: ${e.message}`);
    }
});

/**
 * Start a live video podcast session.
 * Creates a LiveKit room, a Firestore episode doc with mediaType='live_video', and notifies subscribers.
 */
exports.startLivePodcast = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    const { podcastId, episodeTitle, episodeNumber } = data;
    if (!podcastId) throw new functions.https.HttpsError("invalid-argument", "podcastId required");

    const podcastDoc = await admin.firestore().collection("podcasts").doc(podcastId).get();
    if (!podcastDoc.exists) throw new functions.https.HttpsError("not-found", "Podcast not found");
    if (podcastDoc.data().hostId !== context.auth.uid) {
        throw new functions.https.HttpsError("permission-denied", "Only the podcast host can go live");
    }

    const livekitRoomName = `live-podcast-${podcastId}-${Date.now()}`;
    const { apiKey, apiSecret } = _getLiveKitCredentials();

    // Generate host token
    const at = new AccessToken(apiKey, apiSecret, {
        identity: context.auth.uid,
        name: podcastDoc.data().hostName || context.auth.uid,
        ttl: "12h",
    });
    at.addGrant({ room: livekitRoomName, roomJoin: true, canPublish: true, canSubscribe: true, roomAdmin: true });
    const hostToken = await at.toJwt();

    // Create live episode document
    const episodeRef = admin.firestore().collection("podcastEpisodes").doc();
    await episodeRef.set({
        podcastId,
        episodeNumber: episodeNumber || 1,
        title: episodeTitle || "Live",
        audioUrl: "",
        mediaType: "live_video",
        isLive: true,
        livekitRoomName,
        liveViewerCount: 0,
        status: "published",
        durationSeconds: 0,
        playCount: 0,
        likeCount: 0,
        shareCount: 0,
        downloadCount: 0,
        isPremium: false,
        chapters: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        liveStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify subscribers
    const subscriptions = await admin.firestore()
        .collection("podcastUserData")
        .where("podcastId", "==", podcastId)
        .where("notificationsEnabled", "==", true)
        .get();

    if (!subscriptions.empty) {
        const batch = admin.firestore().batch();
        for (const sub of subscriptions.docs) {
            const notifRef = admin.firestore().collection("notifications").doc();
            batch.set(notifRef, {
                userId: sub.data().userId,
                type: "podcastLiveNow",
                title: `${podcastDoc.data().title || "Podcast"} est en direct`,
                body: episodeTitle || "Regardez maintenant",
                data: { podcastId, episodeId: episodeRef.id },
                isRead: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        await batch.commit();
    }

    console.log(`Live podcast started: ${episodeRef.id} in LiveKit room ${livekitRoomName}`);
    return { episodeId: episodeRef.id, livekitRoomName, hostToken };
});

/**
 * End a live video podcast session.
 * Sets isLive=false on the episode, closes the LiveKit room.
 */
exports.endLivePodcast = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    const { episodeId, durationSeconds } = data;
    if (!episodeId) throw new functions.https.HttpsError("invalid-argument", "episodeId required");

    const episodeDoc = await admin.firestore().collection("podcastEpisodes").doc(episodeId).get();
    if (!episodeDoc.exists) throw new functions.https.HttpsError("not-found", "Episode not found");

    const podcastId = episodeDoc.data().podcastId;
    const podcastDoc = await admin.firestore().collection("podcasts").doc(podcastId).get();
    if (podcastDoc.data()?.hostId !== context.auth.uid) {
        throw new functions.https.HttpsError("permission-denied", "Only the host can end the live");
    }

    const livekitRoomName = episodeDoc.data().livekitRoomName;
    const { apiKey, apiSecret, serverUrl } = _getLiveKitCredentials();

    // Delete the LiveKit room (disconnect all participants)
    try {
        const roomClient = new RoomServiceClient(serverUrl, apiKey, apiSecret);
        await roomClient.deleteRoom(livekitRoomName);
    } catch (e) {
        console.warn(`Could not delete LiveKit room ${livekitRoomName}:`, e.message);
    }

    await admin.firestore().collection("podcastEpisodes").doc(episodeId).update({
        isLive: false,
        liveViewerCount: 0,
        durationSeconds: durationSeconds || 0,
        liveEndedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Live podcast ended: ${episodeId}`);
    return { success: true };
});

// ============================================================================
// REVENUECAT WEBHOOK — App Store / Play Store subscription events
// ============================================================================

/**
 * Handles RevenueCat webhook events for native in-app subscription management.
 * RevenueCat covers: App Store (iOS) and Google Play (Android) subscriptions.
 * Stripe covers: one-time payments (tips, room tickets) and web card payments.
 *
 * Setup in RevenueCat dashboard:
 *   Project → Integrations → Webhooks → Add endpoint:
 *   https://us-central1-[PROJECT].cloudfunctions.net/revenueCatWebhook
 *   Authorization: set REVENUECAT_WEBHOOK_AUTH in functions/.env
 *
 * Key events handled:
 *   INITIAL_PURCHASE  — new subscription
 *   RENEWAL           — successful renewal
 *   CANCELLATION      — user cancelled (access until period end)
 *   EXPIRATION        — subscription fully expired
 *   UNCANCELLATION    — user re-enabled a cancelled subscription
 */
exports.revenueCatWebhook = functions.https.onRequest(async (req, res) => {
    if (req.method !== "POST") {
        return res.status(405).send("Method Not Allowed");
    }

    // Verify authorization header.
    //
    // Ce garde echouait OUVERT : `if (authHeader)` sautait toute la
    // verification quand la variable etait absente — et elle l'est en
    // production (`REVENUECAT_WEBHOOK_AUTH` n'est que dans .env.example).
    // N'importe qui pouvant atteindre l'URL pouvait donc poster un evenement
    // forge, et le corps ci-dessous ecrit `subscriptionStatus: "active"` avec
    // les entitlements de son choix sur le compte de son choix
    // (`app_user_id` vient de la requete). Abonnement premium gratuit, sur
    // demande.
    //
    // Meme classe que le placeholder Stripe corrige par ec07de4, mais dans
    // l'autre sens : celui-ci laissait passer au lieu de tout refuser. On
    // refuse desormais tant que le secret n'est pas configure.
    const authHeader = process.env.REVENUECAT_WEBHOOK_AUTH;
    if (!authHeader || isPlaceholderSecret(authHeader)) {
        console.error(
            "REVENUECAT_WEBHOOK_AUTH absent ou laisse au placeholder — " +
            "voir docs/ops/secrets_production.md"
        );
        return res.status(500).send("Webhook secret not configured");
    }

    const provided = req.headers["authorization"] || "";
    const attendu = Buffer.from(authHeader);
    const recu = Buffer.from(provided);
    if (recu.length !== attendu.length || !crypto.timingSafeEqual(recu, attendu)) {
        console.warn("revenueCatWebhook: unauthorized request");
        return res.status(401).send("Unauthorized");
    }

    const event = req.body;
    const eventType = event?.event?.type;
    const appUserId = event?.event?.app_user_id;
    const entitlements = event?.event?.entitlement_ids || [];
    const expiresAt = event?.event?.expiration_at_ms
        ? new Date(event.event.expiration_at_ms).toISOString()
        : null;

    if (!appUserId || !eventType) {
        console.warn("revenueCatWebhook: missing app_user_id or event type");
        return res.status(400).send("Bad Request");
    }

    console.log(`revenueCatWebhook: ${eventType} for user ${appUserId}, entitlements: ${entitlements}`);

    const db = admin.firestore();
    const userRef = db.collection("users").doc(appUserId);

    try {
        switch (eventType) {
            case "INITIAL_PURCHASE":
            case "RENEWAL":
            case "UNCANCELLATION": {
                // Grant entitlements
                await userRef.set({
                    revenueCat: {
                        entitlements: entitlements,
                        subscriptionStatus: "active",
                        expiresAt: expiresAt,
                        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
                    },
                }, { merge: true });

                // If podcast_premium entitlement, mark creator profile accordingly
                if (entitlements.includes("podcast_premium")) {
                    await db.collection("creatorProfiles").doc(appUserId).set({
                        hasRevenueCatPodcastPremium: true,
                        revenueCatExpiresAt: expiresAt,
                    }, { merge: true });
                }

                console.log(`revenueCatWebhook: granted entitlements to ${appUserId}`);
                break;
            }

            case "CANCELLATION": {
                // Access continues until expiry — just update status
                await userRef.set({
                    revenueCat: {
                        subscriptionStatus: "cancelled",
                        expiresAt: expiresAt,
                        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
                    },
                }, { merge: true });
                break;
            }

            case "EXPIRATION": {
                // Access fully expired — revoke entitlements
                await userRef.set({
                    revenueCat: {
                        entitlements: [],
                        subscriptionStatus: "expired",
                        expiresAt: null,
                        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
                    },
                }, { merge: true });

                if (entitlements.includes("podcast_premium")) {
                    await db.collection("creatorProfiles").doc(appUserId).set({
                        hasRevenueCatPodcastPremium: false,
                        revenueCatExpiresAt: null,
                    }, { merge: true });
                }

                console.log(`revenueCatWebhook: revoked entitlements from ${appUserId}`);
                break;
            }

            default:
                console.log(`revenueCatWebhook: unhandled event type ${eventType}`);
        }

        return res.json({ received: true });
    } catch (error) {
        console.error("revenueCatWebhook: error processing event:", error);
        return res.status(500).send("Internal Server Error");
    }
});
