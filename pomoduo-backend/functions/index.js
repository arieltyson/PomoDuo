/**
 * PomoDuo Cloud Functions
 *
 * This is the server-side half of the push notification pipeline.
 * It watches the `pushNotifications` Firestore collection for new
 * documents written by PushNotificationSender.swift and delivers
 * them to the target user's device via FCM.
 *
 * Setup:
 *   cd pomoduo-backend
 *   firebase init functions   (if not already done)
 *   npm install firebase-admin firebase-functions
 *   firebase deploy --only functions
 *
 * Cost note: Requires the Blaze (pay-as-you-go) plan for Cloud Functions
 * that make outbound network calls (FCM delivery). If still on the Spark
 * plan, the Firestore real-time listener handles the in-app sync path
 * and push documents accumulate harmlessly until the function is deployed.
 */

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {logger} = require("firebase-functions");

initializeApp();

/**
 * Triggered when a new document is created in `pushNotifications/{docId}`.
 *
 * Document schema (written by PushNotificationSender.swift):
 *   - targetUserID: string   - the recipient's Firestore UID
 *   - title: string          - notification title
 *   - body: string           - notification body
 *   - category: string       - e.g. "SESSION_REQUEST", "SESSION_PAUSED"
 *   - data: map<string,string> - additional payload
 *   - createdAt: timestamp
 *   - processed: boolean     - false on creation
 *
 * The function:
 *   1. Reads the target user's FCM token from `users/{targetUserID}`
 *   2. Sends a push notification via FCM
 *   3. Deletes the processed document to prevent re-delivery
 */
exports.deliverPushNotification = onDocumentCreated(
    "pushNotifications/{docId}",
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) {
        logger.warn("No data in push notification document.");
        return;
      }

      const pushData = snapshot.data();
      const {targetUserID, title, body, category, data: payload} = pushData;

      if (!targetUserID || !title || !body) {
        logger.error("Push document missing required fields.", {pushData});
        await snapshot.ref.delete();
        return;
      }

      // Look up the target user's FCM token.
      const db = getFirestore();
      const userDoc = await db.collection("users").doc(targetUserID).get();

      if (!userDoc.exists) {
        logger.warn(`No user document found for ${targetUserID}.`);
        await snapshot.ref.delete();
        return;
      }

      const fcmToken = userDoc.data().fcmToken;
      if (!fcmToken) {
        logger.warn(`No FCM token for user ${targetUserID}.`);
        await snapshot.ref.delete();
        return;
      }

      // Build and send the FCM message.
      const message = {
        token: fcmToken,
        notification: {
          title,
          body,
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              "interruption-level": "time-sensitive",
              "sound": "default",
              "category": category || "DEFAULT",
              "content-available": 1,
            },
            ...Object.fromEntries(
                Object.entries(payload || {}).map(([k, v]) => [k, String(v)]),
            ),
          },
        },
        data: {
          category: category || "DEFAULT",
          ...(payload || {}),
        },
      };

      try {
        await getMessaging().send(message);
        logger.info(
            `Push delivered to ${targetUserID} (category: ${category}).`,
        );
      } catch (error) {
      // If the token is invalid or unregistered, clean it up.
        if (
          error.code === "messaging/registration-token-not-registered" ||
        error.code === "messaging/invalid-registration-token"
        ) {
          logger.warn(
              `Stale FCM token for ${targetUserID} - removing from user doc.`,
          );
          await db.collection("users").doc(targetUserID).update({
            fcmToken: null,
            tokenUpdatedAt: null,
          });
        } else {
          logger.error("FCM send failed.", {error: error.message});
        }
      }

      // Always delete the processed document to avoid re-delivery.
      await snapshot.ref.delete();
    },
);

/**
 * Optional: Cleanup stale pairing codes older than 10 minutes.
 *
 * Runs on a schedule (every hour) to keep the pairingCodes collection
 * clean. Can be enabled by uncommenting below.
 */
// const { onSchedule } = require("firebase-functions/v2/scheduler");
//
// exports.cleanupPairingCodes = onSchedule("every 60 minutes", async () => {
//   const db = getFirestore();
//   const cutoff = new Date(Date.now() - 10 * 60 * 1000);
//   const stale = await db
//     .collection("pairingCodes")
//     .where("createdAt", "<", cutoff)
//     .get();
//
//   const batch = db.batch();
//   stale.docs.forEach((doc) => batch.delete(doc.ref));
//   await batch.commit();
//
//   logger.info(`Cleaned up ${stale.size} stale pairing codes.`);
// });
