<div align="center">

# PomoDuo ♥️📚

## App Store  : Coming Soon

<kbd>
    <img src="https://github.com/user-attachments/assets/e94e341a-ea7d-402f-89f1-60b77ba6abe1" width="800" height="500">
</kbd>

## Project Description 🎨

"PomoDuo" is an iOS app built with SwiftUI that turns Pomodoro focus sessions into a shared commitment between two people. Instead of running two independent timers, PomoDuo uses a synchronized session state machine ("The Tethered Timer") so both users experience the same focus, break, pause, and completion states in real time.

The app combines Apple's Screen Time API stack (`FamilyControls`, `ManagedSettings`, `DeviceActivity`) with a real-time sync layer (Firebase Auth + Firestore + FCM) to support collaborative focus sessions, optional partner-triggered lock flows, and social accountability while preserving user consent and privacy.


## Highlights 💫
<div align="left">

### Session Architecture (Protocol-Driven) 🏗️
- **Pure State Machine** manages session logic, ensuring predictable state transitions and robust error handling.
- **Protocol-oriented design** decouples the domain layer from the UI, maximizing testability and modularity.

### Focus Engine & Shielding 🛡️
- **Local-first Pomodoro timer** built with **Swift Concurrency** for high-precision, background-safe timing without network dependency.
- **Screen Time integration** (via `FamilyControls` and `ManagedSettings`) provides system-level app shielding to enforce deep focus periods.

### Real-Time Synchronization 🔄
- **Firebase** backend enables seamless **two-device synchronization**, keeping session data and timer states consistent across multiple devices instantly.

### Live Activities & Dynamic Island 🏝️
- **ActivityKit** support brings live timer updates and session status directly to the **Dynamic Island** and Lock Screen.
- Provides immediate glanceability and quick controls without requiring the user to unlock their device or open the app.

### Accessibility 🦾
- **Full [Accessibility Nutrition Label](https://arieltyson.github.io/pomoduo-accessibility/) coverage** across all nine App Store categories — VoiceOver, Voice Control, Dynamic Type, Dark Mode, Increase Contrast (WCAG 2.1 AA), Differentiate Without Color, and Reduce Motion.
- **Trait-adaptive color system** shifts brand colors to higher-contrast variants automatically based on user settings.
- **Voice Control input labels** provide short spoken alternatives for every high-traffic control.

### Production Hardening 🔩
- **MetricKit** diagnostics capture hang rates, launch times, and crash reports in production.
- **Network path monitoring** gracefully handles offline and constrained connectivity states.
- **Low Power Mode awareness** suppresses cosmetic animations to conserve battery.

</div>

## Screenshots:

<div style="display: flex; justify-content: center; align-items: center;">
    <kbd>
        <img src="https://github.com/user-attachments/assets/fb0db5ff-5407-4b2f-a89a-fb50052b9403" alt="Dashboard" width="200">
    </kbd>
    <kbd>
        <img src="https://github.com/user-attachments/assets/7e0c9d67-fa4f-44ad-8a3a-31bc8c48b741" alt="Pairing Flow" width="200">
    </kbd>
    <kbd>
        <img src="https://github.com/user-attachments/assets/6b97e32c-12e9-4c21-9d7b-e6810374fec3" alt="Active Session" width="200">
    </kbd>
</div>

<div style="display: flex; justify-content: center; align-items: center;">
    <kbd>
        <img src="https://github.com/user-attachments/assets/8eef357b-ee5c-4368-b435-874475d99d2c" alt="App Selection" width="200">
    </kbd>
    <kbd>
        <img src="https://github.com/user-attachments/assets/ba0c6124-2d94-413c-9759-d0ed2fa47509" alt="Live Activity" width="200">
    </kbd>
    <kbd>
        <img src="https://github.com/user-attachments/assets/4d45b4bb-f794-4189-882c-159522325e1b" alt="History View" width="200">
    </kbd>
</div>

## Technologies Used 💻

This project leverages modern Swift, SwiftUI, and Apple platform APIs for a native, privacy-first collaboration experience.

**Language & Frameworks**
- [x] Swift 6
- [x] SwiftUI
- [x] UIKit (App Delegate, Quick Actions, Trait-Adaptive Colors)
- [x] Observation framework
- [x] Swift Concurrency (`async/await`, actors)

**Screen Time**
- [x] FamilyControls
- [x] ManagedSettings
- [x] ManagedSettingsUI (Shield Customization)
- [x] DeviceActivity

**Live Activities & Widgets**
- [x] ActivityKit + WidgetKit (Dynamic Island & Lock Screen)
- [x] AppIntents + Shortcuts

**Data & Networking**
- [x] SwiftData (Local Persistence)
- [x] FirebaseAuth
- [x] Firestore (Real-Time Sync)
- [x] FirebaseMessaging (FCM)
- [x] Network framework (Connectivity Monitoring)
- [x] CryptoKit (Secure Pairing)

**Notifications & Auth**
- [x] UserNotifications
- [x] AuthenticationServices (Sign in with Apple)

**Accessibility**
- [x] UIAccessibility (Labels, Hints, Traits, Input Labels, Announcements)
- [x] Dynamic Type & Scalable Fonts
- [x] Trait-Adaptive Colors (`UITraitCollection` — Dark Mode, Increase Contrast)
- [x] Reduce Motion & Differentiate Without Color Environment Support

**Performance & Diagnostics**
- [x] MetricKit (Hang Rate, Launch Time, Crash Reports)
- [x] OSLog (Structured Logging)
- [x] ProcessInfo (Low Power Mode Monitoring)

**UI & Data Visualization**
- [x] Charts (Weekly Focus Streak)
- [x] StoreKit (App Rating)

**Testing**
- [x] Swift Testing + XCTest UI Testing
- [x] WCAG 2.1 AA Contrast Ratio Tests

## Skills Demonstrated 🥋

This project is designed to showcase high-quality iOS engineering practices:

- [x] **SYSTEM DESIGN**: Local-first architecture with real-time synchronization for a shared state machine.
- [x] **STATE MANAGEMENT**: Explicit session events and deterministic transitions across two devices.
- [x] **PLATFORM INTEGRATION**: Deep integration with Screen Time APIs and Live Activities.
- [x] **PERFORMANCE/COST AWARENESS**: Transition-based Firestore sync (not per-second timer writes). MetricKit diagnostics and Low Power Mode awareness.
- [x] **ACCESSIBILITY**: Full App Store Nutrition Label coverage — VoiceOver, Voice Control, Dynamic Type, Dark Mode, Increase Contrast (WCAG AA), Differentiate Without Color, and Reduce Motion.
- [x] **PRIVACY & CONSENT**: Collaborative control model aligned with Apple policy constraints.
- [x] **TESTABILITY**: Protocol-oriented abstractions, pure domain logic, and automated WCAG contrast verification.

## Contributing ⚙️

Contributions are welcome. If you have ideas for features, architecture improvements, or bug fixes, open an issue or submit a pull request. Please keep changes aligned with the project's local-first and consent-first design principles.

## License 🪪

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

</div>
