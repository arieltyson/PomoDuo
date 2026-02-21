# PomoDuo Privacy Policy

**Last updated:** February 2026

PomoDuo is a collaborative Pomodoro timer that helps you and a study partner hold each other accountable during focus sessions. We take your privacy seriously and have designed the app to collect the absolute minimum data needed to function.

## What We Collect

| Data | Purpose | Stored Where | Retention |
|---|---|---|---|
| **Anonymous user ID** | Identifies your device for pairing and session sync. Generated automatically by Firebase Authentication - no email, name, or password required. | Firebase Auth | Until you delete the app and reinstall. |
| **FCM push token** | Delivers notifications when your partner starts, pauses, or resumes a session while your app is in the background. | Firestore (`users/{id}`) | Refreshed automatically; deleted on sign-out or token expiry. |
| **Session state** | Syncs timer state (focus, break, paused) between paired devices in real time. | Firestore (`sessions/{id}`) | Deleted when the session ends. No historical sessions are stored server-side. |
| **Heartbeat timestamp** | Once-per-minute timestamp confirming your device is active during a session. Used to detect if a partner's app crashes or their phone dies, so the other partner isn't left waiting indefinitely. | Firestore (inside session document) | Deleted with the session document when the session ends. |
| **Pairing code** | A temporary 6-character code used to link two devices. | Firestore (`pairingCodes/{code}`) | Auto-expires after 10 minutes. |
| **Session history** | Completed focus rounds (start time, duration, round number). | On-device only (SwiftData) | Stored locally. Never uploaded to any server. |
| **App selection tokens** | Opaque tokens representing the apps you choose to block during focus sessions. These are managed by Apple's Screen Time API. | On-device only (managed by iOS) | Cleared when you remove the selection. |

## What We Do NOT Collect

- **No browsing history.** We never see which apps you use or how often.
- **No app names or bundle IDs.** Apple's Screen Time API uses opaque tokens - we literally cannot see which apps you selected.
- **No location data.**
- **No contacts or address book access.**
- **No health data.**
- **No analytics or tracking.** Google Analytics is disabled in our Firebase project.
- **No advertising identifiers.**
- **No third-party SDKs** beyond Firebase (Authentication, Firestore, Cloud Messaging).

## Screen Time API

PomoDuo uses Apple's Family Controls and Managed Settings frameworks to block distracting apps during focus sessions. This works through opaque tokens - your specific app choices are never visible to us, our servers, or your study partner. Both partners must explicitly opt in to each session. Either partner can pause or end the session at any time, immediately removing all restrictions.

## Data Sharing

We do not sell, share, or transfer your data to any third party. Your study partner can see:

- Your display name (which you set yourself)
- Your current session state (focusing, on break, paused)
- Whether your device is active during a session (via heartbeat)

Your partner **cannot** see which apps you have blocked, your session history, or any other data on your device.

## Data Deletion

- **Session data** is automatically deleted from Firestore when each session ends.
- **Pairing codes** expire and are cleaned up automatically.
- **Local history** can be deleted by uninstalling the app.
- **Your account** can be deleted from Settings -> Account -> Delete Account, which removes all server-side data associated with your anonymous ID.

## Children's Privacy

PomoDuo does not knowingly collect data from children under 13. The app requires Apple's Screen Time authorization (for: .individual), which is designed for personal use by the device owner.

## Contact

If you have questions about this privacy policy, please contact us at arieltyson30190@gmail.com.
