# PomoDuo Backend

The backend lives in a separate repository at `../pomoduo-backend` (relative to this repo's root). It is a Firebase project (`pomoduo-61e38`) on the Blaze plan.

## Firebase Services

| Service | Purpose |
|---|---|
| **Firestore** | Primary database for users, friendships, sessions, pairing codes, and push notification queue |
| **Cloud Functions (v2)** | Push notification delivery, account deletion cascade, stale pairing code cleanup |
| **Firebase Cloud Messaging** | Push notifications to iOS devices via APNs |
| **Firebase Hosting** | Serves the `apple-app-site-association` file and deep-link landing pages |
| **Firebase Auth** | Anonymous and Apple Sign-In authentication |

## Project Details

- **Firebase Project ID**: `pomoduo-61e38`
- **Hosting Domain**: `pomoduo-61e38.web.app`
- **Team ID**: `2MPMKAF986`
- **Bundle ID**: `com.arieljtyson.PomoDuo`
- **App Store ID**: `6759349583`
- **App Group**: `group.com.arieljtyson.pomoduo`

## Firestore Collections

| Collection | Purpose | Key Fields |
|---|---|---|
| `users` | User profiles and FCM tokens | `displayName`, `username`, `usernameNormalized`, `fcmToken` |
| `usernames` | Case-insensitive unique username claims (doc ID = normalized username) | `uid`, `createdAt` |
| `friendRequests` | Pending/accepted/declined friend requests | `fromUID`, `toUID`, `status`, `fromDisplayName`, `fromUsername` |
| `friendships` | Established friend connections (doc ID = sorted UID pair) | `members[]`, `memberDisplayNames`, `memberUsernames` |
| `pairingCodes` | Short-lived 6-digit codes for one-time pairing | `ownerID`, `ownerDisplayName`, `createdAt` |
| `partnerships` | Created when a pairing code is consumed | `members[]`, `memberDisplayNames`, `sourceCode` |
| `sessions` | Real-time paired study sessions | `partnerA`, `partnerB`, `members[]`, `state`, `duration`, `currentRound` |
| `pushNotifications` | Write-only queue consumed by Cloud Function | `targetUserID`, `title`, `body`, `category`, `data` |

## Cloud Functions

| Function | Trigger | Purpose |
|---|---|---|
| `deliverPushNotification` | Firestore `onCreate` on `pushNotifications/{docId}` | Reads FCM token, sends push via APNs, deletes processed doc |
| `onUserDeleted` | Auth `onDelete` | Cascade-deletes all Firestore data for the deleted user |
| `cleanupStalePairingCodes` | Scheduled every 60 minutes | Deletes pairing codes older than 10 minutes |

## Firebase Hosting

Hosting serves two purposes:

1. **Apple App Site Association (AASA)** at `/.well-known/apple-app-site-association` — enables Universal Links so `https://pomoduo-61e38.web.app/add-friend/{username}` opens the app directly on iOS when installed.

2. **Landing page fallbacks** — when the app is not installed, `/add-friend/{username}` and `/pair/{code}` serve branded HTML pages with the sender's info and an App Store download link.

### Hosted Files

```
public/
  .well-known/
    apple-app-site-association   # Links domain to app ID 2MPMKAF986.com.arieljtyson.PomoDuo
  add-friend.html                # Fallback landing page for friend links
  pair.html                      # Fallback landing page for pair code links
```

### URL Rewrites

| URL Pattern | Destination | App Behavior |
|---|---|---|
| `/add-friend/{username}` | `add-friend.html` (if app not installed) | Opens Add Friend sheet via Universal Link |
| `/pair/{code}` | `pair.html` (if app not installed) | Opens pair code entry via Universal Link |

## Deep Linking

The iOS app handles deep links from two sources:

1. **Universal Links** (HTTPS) — `https://pomoduo-61e38.web.app/add-friend/{username}`
2. **Custom URL scheme** (legacy) — `pomoduo://add-friend/{username}`

Both are routed through `DeepLinkRouter` in the iOS app (`Core/Networking/DeepLinkRouter.swift`). The Universal Link format is preferred for sharing because custom URL schemes are not clickable in messaging apps like WhatsApp and iMessage.

### Associated Domains

The iOS app's entitlements include `applinks:pomoduo-61e38.web.app`. This must match the domain serving the AASA file.

## Deployment

```bash
cd ../pomoduo-backend

# Deploy everything
firebase deploy

# Deploy only specific services
firebase deploy --only hosting
firebase deploy --only functions
firebase deploy --only firestore:rules
```

## Relationship to iOS App

| iOS Component | Backend Dependency |
|---|---|
| `FirebaseAuthService` | Firebase Auth (anonymous + Apple Sign-In) |
| `FirebaseFriendService` | Firestore (`users`, `usernames`, `friendRequests`, `friendships`) |
| `FirebasePairingService` | Firestore (`pairingCodes`, `partnerships`) |
| `FirebaseSessionSyncService` | Firestore (`sessions`) |
| `PushNotificationSender` | Firestore (`pushNotifications` queue) -> Cloud Function -> FCM |
| `FCMTokenManager` | Firestore (`users.fcmToken`) |
| `DeepLinkRouter` | Firebase Hosting (AASA + landing pages) |
| Screen Time extensions | App Group `group.com.arieljtyson.pomoduo` (local only, no backend) |
