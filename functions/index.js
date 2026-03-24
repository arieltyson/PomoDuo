/**
 * Firebase Cloud Function: Push Notification Delivery for PomoDuo.
 *
 * Watches the `pushNotifications` Firestore collection for new documents
 * written by the iOS client, resolves the target user's FCM token, sends
 * the push notification via FCM v1, and deletes the processed document.
 *
 * Document schema (written by PushNotificationSender.swift):
 * {
 *   targetUserID: string,
 *   title: string,
 *   body: string,
 *   category: string,        // e.g. "FRIEND_REQUEST", "SESSION_REQUEST"
 *   data: { [key]: string }, // additional payload (e.g. friendRequestID)
 *   createdAt: timestamp,
 *   processed: boolean
 * }
 */

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions/v2";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/**
 * Triggered when a new document is created in `pushNotifications`.
 * Resolves the recipient's FCM token and delivers the notification.
 */
export const deliverPushNotification = onDocumentCreated(
  "pushNotifications/{docId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("No data in push notification document.");
      return;
    }

    const data = snapshot.data();
    const { targetUserID, title, body, category } = data;
    const payload = data.data ?? {};

    if (!targetUserID || !title || !body) {
      logger.error("Missing required fields in push notification document.", {
        targetUserID,
        title,
        body,
      });
      await snapshot.ref.delete();
      return;
    }

    // Resolve the target user's FCM token.
    const userDoc = await db.collection("users").doc(targetUserID).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) {
      logger.info(
        `No FCM token found for user ${targetUserID}. Deleting document.`
      );
      await snapshot.ref.delete();
      return;
    }

    // Build the FCM message with APNs configuration for iOS.
    const message = {
      token: fcmToken,
      notification: {
        title,
        body,
      },
      data: {
        ...payload,
        category: category ?? "",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            alert: {
              title,
              body,
            },
            sound: "default",
            category: category ?? "",
            "mutable-content": 1,
          },
          // Include custom data at the APNs payload root so iOS
          // can read it from userInfo without nesting.
          ...payload,
          category: category ?? "",
        },
      },
    };

    try {
      await messaging.send(message);
      logger.info(
        `Push notification delivered to ${targetUserID} (category: ${category}).`
      );
    } catch (error) {
      // Handle expired or invalid tokens by cleaning up.
      if (
        error.code === "messaging/registration-token-not-registered" ||
        error.code === "messaging/invalid-registration-token"
      ) {
        logger.warn(
          `Stale FCM token for user ${targetUserID}. Removing token.`
        );
        await db
          .collection("users")
          .doc(targetUserID)
          .update({ fcmToken: null });
      } else {
        logger.error("FCM send failed:", error);
      }
    }

    // Always clean up the processed document.
    await snapshot.ref.delete();
  }
);
