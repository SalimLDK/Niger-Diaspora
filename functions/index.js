const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { decryptText } = require("./encryption");

admin.initializeApp();

/**
 * Triggered when a new document is created in the 'notifications' collection.
 * Sends a push notification to the user's devices.
 */
exports.sendNotificationOnCreate = functions.firestore
    .document("notifications/{notificationId}")
    .onCreate(async (snapshot, context) => {
        const notificationData = snapshot.data();
        const userId = notificationData.userId;

        if (!userId) {
            console.log("No userId in notification document");
            return null;
        }

        try {
            // Get the user's FCM tokens
            const userDoc = await admin.firestore().collection("users").doc(userId).get();

            if (!userDoc.exists) {
                console.log(`User ${userId} does not exist`);
                return null;
            }

            const userData = userDoc.data();
            const fcmTokens = userData.fcmTokens;

            if (!fcmTokens || !Array.isArray(fcmTokens) || fcmTokens.length === 0) {
                console.log(`No FCM tokens for user ${userId}`);
                return null;
            }

            // Prepare the message payload
            const payload = {
                notification: {
                    title: notificationData.title || "Nouvelle notification",
                    body: notificationData.body || "Vous avez une nouvelle notification",
                },
                data: {
                    // Ensure all data values are strings
                    type: String(notificationData.type || "general"),
                    targetId: String(notificationData.targetId || ""),
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                    ...Object.keys(notificationData.data || {}).reduce((acc, key) => {
                        acc[key] = String(notificationData.data[key]);
                        return acc;
                    }, {}),
                },
            };

            console.log(`Sending notification to ${fcmTokens.length} tokens for user ${userId}`);

            // Send multicast message
            const response = await admin.messaging().sendMulticast({
                tokens: fcmTokens,
                ...payload,
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
                    console.log(`Removing ${failedTokens.length} invalid tokens`);
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
 */
exports.onMessageCreated = functions.database
    .ref("/messages/{conversationId}/{messageId}")
    .onCreate(async (snapshot, context) => {
        const message = snapshot.val();
        const conversationId = context.params.conversationId;
        const messageId = context.params.messageId;

        console.log(`New message created in conversation ${conversationId}`);

        const messageType = message.type || "text";

        try {
            // Get conversation details from Firestore
            const conversationDoc = await admin.firestore()
                .collection("conversations")
                .doc(conversationId)
                .get();

            if (!conversationDoc.exists) {
                console.log(`Conversation ${conversationId} not found in Firestore`);
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
                console.log("No recipients to notify");
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
                    console.log(`User ${recipientId} has muted this conversation`);
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
                            console.log(`User ${recipientId} has disabled system message notifications`);
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
                console.log("No valid tokens to send notification");
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
            console.log(`Stored ${notificationPromises.length} notifications in Firestore`);

            // Send push notification
            const response = await admin.messaging().sendMulticast({
                tokens: allTokens,
                notification: { title, body },
                data: {
                    type: "message",
                    conversationId,
                    messageId,
                    senderId,
                    userId: "", // Will be set per-user in the Firestore notification doc
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

            console.log(`Successfully sent ${response.successCount}/${allTokens.length} push notifications`);

            // Clean up invalid tokens
            if (response.failureCount > 0) {
                const invalidTokens = [];
                response.responses.forEach((resp, idx) => {
                    if (!resp.success && (resp.error.code === "messaging/invalid-registration-token" || resp.error.code === "messaging/registration-token-not-registered")) {
                        invalidTokens.push({ token: allTokens[idx], userId: tokenOwners[idx] });
                    }
                });

                if (invalidTokens.length > 0) {
                    console.log(`Removing ${invalidTokens.length} invalid tokens`);
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
 * Sends push notifications to all participants except the sender.
 */
exports.sendChatNotification = functions.firestore
    .document("conversations/{conversationId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();

        // Check if lastMessage changed (new message sent)
        if (!after.lastMessage || before.lastMessage === after.lastMessage) {
            console.log("No new message detected");
            return null;
        }

        const conversationId = context.params.conversationId;
        const senderId = after.lastMessageSenderId;
        const participantIds = after.participantIds || [];
        const conversationType = after.type; // 'individual' or 'group'
        const lastMessage = after.lastMessage;

        if (!senderId || participantIds.length === 0) {
            console.log("Missing sender or participants");
            return null;
        }

        try {
            // Get all participants' tokens (except sender)
            const recipients = participantIds.filter((id) => id !== senderId);

            if (recipients.length === 0) {
                console.log("No recipients to notify");
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
            console.log(`Stored ${notificationPromises.length} notifications in Firestore`);

            if (allTokens.length === 0) {
                console.log("No tokens found for recipients, but notifications stored");
                return { success: true, sentCount: 0, storedCount: notificationPromises.length };
            }

            // Prepare the message payload
            const payload = {
                notification: {
                    title: title,
                    body: truncatedBody,
                },
                data: {
                    type: "message",
                    conversationId: conversationId,
                    senderId: senderId,
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
            };

            console.log(`Sending chat notification to ${allTokens.length} tokens`);

            // Send multicast message
            const response = await admin.messaging().sendMulticast({
                tokens: allTokens,
                ...payload,
            });

            console.log(`Successfully sent ${response.successCount} push notifications`);

            return { success: true, sentCount: response.successCount };
        } catch (error) {
            console.error("Error sending chat notification:", error);
            return null;
        }
    });

/**
 * Scheduled function that runs every hour to check for events starting in 24 hours
 * and sends reminder notifications to attendees.
 */
exports.sendEventReminders = functions.pubsub
    .schedule("every 1 hours")
    .onRun(async (context) => {
        console.log("Running event reminders check...");

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

            console.log(`Found ${eventsSnapshot.size} events starting in 24 hours`);

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
            console.log(`Created ${promises.length} event reminder notifications`);

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
 * Stripe Payment Intent Handler
 * 
 * This function watches for new documents in the 'payment_intents' collection
 * and creates a Stripe payment intent on the server side.
 * 
 * IMPORTANT: Before deploying, set your Stripe secret key:
 * firebase functions:config:set stripe.secret_key="sk_test_YOUR_SECRET_KEY"
 * 
 * For production, use your live secret key:
 * firebase functions:config:set stripe.secret_key="sk_live_YOUR_SECRET_KEY"
 */

// Lazy load Stripe to avoid initialization errors if config is not set
let stripe = null;

function getStripe() {
    if (!stripe) {
        const stripeSecretKey = functions.config().stripe?.secret_key;

        if (!stripeSecretKey) {
            throw new Error(
                "Stripe secret key not configured. " +
                "Run: firebase functions:config:set stripe.secret_key=\"sk_test_...\""
            );
        }

        // NOTE: You need to install stripe package first:
        // cd functions && npm install stripe
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

        console.log(`Creating Stripe payment intent for: ${intentId}`);

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

            console.log(`Payment intent created: ${paymentIntent.id}`);

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
            console.error("Error creating payment intent:", error);

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
 * 4. Copy the webhook secret and set it:
 *    firebase functions:config:set stripe.webhook_secret="whsec_..."
 */
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
    const sig = req.headers["stripe-signature"];
    const webhookSecret = functions.config().stripe?.webhook_secret;

    if (!webhookSecret) {
        console.error("Webhook secret not configured");
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
        console.error("Webhook signature verification failed:", err.message);
        return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    console.log(`Received webhook event: ${event.type}`);

    try {
        switch (event.type) {
            case "payment_intent.succeeded":
                await handlePaymentSuccess(event.data.object);
                break;

            case "payment_intent.payment_failed":
                await handlePaymentFailure(event.data.object);
                break;

            default:
                console.log(`Unhandled event type: ${event.type}`);
        }

        res.json({ received: true });
    } catch (error) {
        console.error("Error processing webhook:", error);
        res.status(500).send("Webhook processing error");
    }
});

/**
 * Handle successful payment
 */
async function handlePaymentSuccess(paymentIntent) {
    console.log(`Payment succeeded: ${paymentIntent.id}`);

    const transactionId = paymentIntent.metadata.transactionId;

    if (!transactionId) {
        console.log("No transaction ID in metadata");
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

        console.log(`Transaction ${transactionId} marked as processing`);
    } catch (error) {
        console.error("Error updating transaction:", error);
    }
}

/**
 * Handle failed payment
 */
async function handlePaymentFailure(paymentIntent) {
    console.log(`Payment failed: ${paymentIntent.id}`);

    const transactionId = paymentIntent.metadata.transactionId;

    if (!transactionId) {
        console.log("No transaction ID in metadata");
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

        console.log(`Transaction ${transactionId} marked as failed`);
    } catch (error) {
        console.error("Error updating transaction:", error);
    }
}

/**
 * Triggered when a new event is created.
 * Sends push notifications to users in the same city/country who have enabled local events notifications.
 */
exports.notifyLocalEventCreated = functions.firestore
    .document("events/{eventId}")
    .onCreate(async (snapshot, context) => {
        const eventData = snapshot.data();
        const eventId = context.params.eventId;

        console.log(`New event created: ${eventId} - ${eventData.title}`);

        const eventCity = eventData.city || eventData.location?.city;
        const eventCountry = eventData.country || eventData.location?.country;
        const organizerId = eventData.organizerId;

        if (!eventCity && !eventCountry) {
            console.log("Event has no location info, skipping local notifications");
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

            console.log(`Found ${usersSnapshot.size} users in the same location`);

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
            console.log(`Created ${notificationCount} local event notifications`);

            return { success: true, count: notificationCount };
        } catch (error) {
            console.error("Error sending local event notifications:", error);
            return null;
        }
    });
