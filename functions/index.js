const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { GoogleAuth } = require("google-auth-library");
const { decryptText } = require("./encryption");

admin.initializeApp();

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
                    payload: {
                        aps: {
                            sound: "default",
                            badge: 1,
                        },
                    },
                },
            });

            // Cleanup invalid tokens
            if (response.failureCount > 0) {
                const failedTokens = [];
                response.responses.forEach((resp, idx) => {
                    if (!resp.success) {
                        failedTokens.push(fcmTokens[idx]);
                    }
                });

                if (failedTokens.length > 0) {
                    // console.log(`Removing ${failedTokens.length} invalid tokens`);
                    await admin.firestore().collection("users").doc(userId).update({
                        fcmTokens: admin.firestore.FieldValue.arrayRemove(...failedTokens),
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
exports.onMessageCreated = functions
    .region("europe-west1")
    .database.instance("diaspo-niger-default-rtdb")
    .ref("/messages/{conversationId}/{messageId}")
    .onCreate(async (snapshot, context) => {
        const message = snapshot.val();
        const conversationId = context.params.conversationId;
        const messageId = context.params.messageId;

        // console.log(`New message created in conversation ${conversationId}`);

        try {
            // Get conversation details from Firestore
            const conversationDoc = await admin.firestore()
                .collection("conversations")
                .doc(conversationId)
                .get();

            if (!conversationDoc.exists) {
                // console.log(`Conversation ${conversationId} not found in Firestore`);
                return null;
            }

            const conversation = conversationDoc.data();
            const senderId = message.senderId;
            const participantIds = conversation.participantIds || [];
            const mutedBy = conversation.mutedBy || [];
            const conversationType = conversation.type;

            // Get recipients (exclude sender)
            const recipients = participantIds.filter((id) => id !== senderId);

            if (recipients.length === 0) {
                // console.log("No recipients to notify");
                return null;
            }

            // Get sender's name
            const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
            const senderName = senderDoc.exists ? (senderDoc.data().displayName || "Un utilisateur") : "Un utilisateur";

            // Prepare notification content based on message type
            let messagePreview = message.content || "";
            const messageType = message.type || "text";

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
                default:
                    // Decrypt text messages before displaying in notification
                    messagePreview = decryptText(messagePreview);
                    if (messagePreview.length > 100) {
                        messagePreview = messagePreview.substring(0, 100) + "...";
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

            // Collect tokens from recipients
            const allTokens = [];
            const tokenOwners = [];

            for (const recipientId of recipients) {
                if (mutedBy.includes(recipientId)) {
                    // console.log(`User ${recipientId} has muted this conversation`);
                    continue;
                }

                const recipientDoc = await admin.firestore().collection("users").doc(recipientId).get();
                if (recipientDoc.exists) {
                    const userData = recipientDoc.data();
                    const tokens = userData.fcmTokens || [];
                    const notificationsEnabled = userData.notificationsEnabled !== false;

                    // For system messages, check if user wants these notifications
                    if (messageType === "system") {
                        const systemMessagesEnabled = userData.notifySystemMessages === true;
                        if (!systemMessagesEnabled) {
                            // console.log(`User ${recipientId} has disabled system message notifications`);
                            continue;
                        }
                    }

                    if (notificationsEnabled && tokens.length > 0) {
                        allTokens.push(...tokens);
                        tokens.forEach(() => tokenOwners.push(recipientId));
                    }
                }
            }

            if (allTokens.length === 0) {
                // console.log("No valid tokens to send notification");
                return null;
            }

            // Store notification in Firestore for each recipient (for notification history)
            const notificationPromises = [];
            for (const recipientId of recipients) {
                if (mutedBy.includes(recipientId)) continue;

                notificationPromises.push(
                    admin.firestore().collection("notifications").add({
                        userId: recipientId,
                        title: title,
                        body: body,
                        type: "message",
                        targetId: conversationId,
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

            // Send push notification using sendEachForMulticast (sendMulticast is deprecated)
            const response = await admin.messaging().sendEachForMulticast({
                tokens: allTokens,
                notification: { title, body },
                data: {
                    type: "message",
                    title: title,
                    body: body,
                    conversationId,
                    messageId,
                    senderId,
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
                android: {
                    priority: "high",
                    notification: { channelId: "messages", sound: "default" },
                },
                apns: {
                    payload: { aps: { sound: "default", badge: 1 } },
                },
            });

            // console.log(`Successfully sent ${response.successCount}/${allTokens.length} push notifications`);

            // Clean up invalid tokens
            if (response.failureCount > 0) {
                const invalidTokens = [];
                response.responses.forEach((resp, idx) => {
                    if (!resp.success && (resp.error.code === "messaging/invalid-registration-token" || resp.error.code === "messaging/registration-token-not-registered")) {
                        invalidTokens.push({ token: allTokens[idx], userId: tokenOwners[idx] });
                    }
                });

                if (invalidTokens.length > 0) {
                    // console.log(`Removing ${invalidTokens.length} invalid tokens`);
                    const updates = {};
                    invalidTokens.forEach(({ token, userId }) => {
                        if (!updates[userId]) updates[userId] = [];
                        updates[userId].push(token);
                    });

                    await Promise.all(
                        Object.entries(updates).map(([userId, tokens]) =>
                            admin.firestore().collection("users").doc(userId).update({
                                fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokens),
                            })
                        )
                    );
                }
            }

            return { success: true, sentCount: response.successCount };
        } catch (error) {
            console.error("Error sending message notification:", error);
            return null;
        }
    });

/**
 * Triggered when a conversation is updated (new message).
 *
 * DISABLED: This function is no longer needed because onMessageCreated
 * already handles message notifications directly from Realtime Database.
 * Keeping this code commented for reference.
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
 * Scheduled function that runs every hour to check for events starting in 24 hours
 * and sends reminder notifications to attendees.
 */
exports.sendEventReminders = functions.pubsub
    .schedule("every 1 hours")
    .onRun(async (context) => {
        // console.log("Running event reminders check...");

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

            // console.log(`Found ${eventsSnapshot.size} events starting in 24 hours`);

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

                // Create notification for each attendee
                for (const attendeeId of attendeeIds) {
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

                    // Create notification document (will trigger sendNotificationOnCreate)
                    promises.push(
                        admin.firestore().collection("notifications").add(notificationData)
                    );
                }
            }

            await Promise.all(promises);
            // console.log(`Created ${promises.length} event reminder notifications`);

            return { success: true, count: promises.length };
        } catch (error) {
            // console.error("Error sending event reminders:", error);
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

        // console.log(`Creating Stripe payment intent for: ${intentId}`);

        try {
            // Validate required fields
            if (!data.amount || !data.currency || !data.userId) {
                throw new Error("Missing required fields: amount, currency, or userId");
            }

            // Get Stripe instance
            const stripeInstance = getStripe();

            // Create payment intent
            const paymentIntent = await stripeInstance.paymentIntents.create({
                amount: Math.round(data.amount * 100), // Convert to cents
                currency: data.currency.toLowerCase(),
                metadata: {
                    userId: data.userId,
                    transactionId: data.transactionId || "",
                    ...data.metadata,
                },
                automatic_payment_methods: {
                    enabled: true,
                },
            });

            // console.log(`Payment intent created: ${paymentIntent.id}`);

            // Update the document with the payment intent details
            await snapshot.ref.update({
                status: "created",
                paymentIntentId: paymentIntent.id,
                clientSecret: paymentIntent.client_secret,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            return {
                success: true,
                paymentIntentId: paymentIntent.id,
            };
        } catch (error) {
            // console.error("Error creating payment intent:", error);

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

    if (!webhookSecret) {
        // console.error("Webhook secret not configured");
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
 */
async function handlePaymentSuccess(paymentIntent) {
    // console.log(`Payment succeeded: ${paymentIntent.id}`);

    const transactionId = paymentIntent.metadata.transactionId;

    if (!transactionId) {
        // console.log("No transaction ID in metadata");
        return;
    }

    try {
        // Update transaction status
        await admin.firestore().collection("transactions").doc(transactionId).update({
            status: "processing",
            paymentIntentId: paymentIntent.id,
            stripeChargeId: paymentIntent.charges?.data[0]?.id,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // console.log(`Transaction ${transactionId} marked as processing`);
    } catch (error) {
        // console.error("Error updating transaction:", error);
    }
}

/**
 * Handle failed payment
 */
async function handlePaymentFailure(paymentIntent) {
    // console.log(`Payment failed: ${paymentIntent.id}`);

    const transactionId = paymentIntent.metadata.transactionId;

    if (!transactionId) {
        // console.log("No transaction ID in metadata");
        return;
    }

    try {
        // Update transaction status
        await admin.firestore().collection("transactions").doc(transactionId).update({
            status: "failed",
            paymentIntentId: paymentIntent.id,
            failureReason: paymentIntent.last_payment_error?.message || "Payment failed",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // console.log(`Transaction ${transactionId} marked as failed`);
    } catch (error) {
        // console.error("Error updating transaction:", error);
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
                // Restore product quantity
                await admin.firestore().collection("products").doc(productId).update({
                    quantity: admin.firestore.FieldValue.increment(quantity),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                // console.log(`Restored product ${productId} quantity by ${quantity}`);

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

            // 2.2 Delete typing indicators (in all conversations)
            // Note: These are transient and will be cleaned up naturally
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
