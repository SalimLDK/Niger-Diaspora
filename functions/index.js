const functions = require("firebase-functions");
const admin = require("firebase-admin");

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

            // Determine notification title and body
            let title;
            let body;

            if (conversationType === "group") {
                title = after.name || "Groupe";
                body = `${senderName}: ${lastMessage}`;
            } else {
                title = senderName;
                body = lastMessage;
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

            if (allTokens.length === 0) {
                console.log("No tokens found for recipients");
                return null;
            }

            // Prepare the message payload
            const payload = {
                notification: {
                    title: title,
                    body: body.length > 100 ? body.substring(0, 100) + "..." : body,
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

            console.log(`Successfully sent ${response.successCount} notifications`);

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
