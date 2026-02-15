<div align="center">

# PomoDuo ♥️📚

## App Store  : Coming Soon

<kbd>
    <img src="https://github.com/user-attachments/assets/58b51430-3e01-4f65-8ebe-42073c89d4ff" alt="PomoDuo Hero" width="800" height="500">
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

### Production Hardening & Accessibility 🦾
- **Accessibility-first design** ensures full support for VoiceOver and Dynamic Type, making the focus tools usable for everyone.
- **App Store hardening** includes rigorous edge-case handling and performance optimization, ensuring a stable, production-ready experience.

</div>


## Demo:

Coming soon


## Screenshots:

<div style="display: flex; justify-content: center; align-items: center;">
    <kbd>
        <img src="https://github.com/user-attachments/assets/58b51430-3e01-4f65-8ebe-42073c89d4ff" alt="Dashboard" width="200">
    </kbd>
    <kbd>
        <img src="https://github.com/user-attachments/assets/58b51430-3e01-4f65-8ebe-42073c89d4ff" alt="Pairing Flow" width="200">
    </kbd>
    <kbd>
        <img src="https://github.com/user-attachments/assets/58b51430-3e01-4f65-8ebe-42073c89d4ff" alt="Active Session" width="200">
    </kbd>
</div>

<div style="display: flex; justify-content: center; align-items: center;">
    <kbd>
        <img src="https://github.com/user-attachments/assets/58b51430-3e01-4f65-8ebe-42073c89d4ff" alt="App Selection" width="200">
    </kbd>
    <kbd>
        <img src="https://github.com/user-attachments/assets/58b51430-3e01-4f65-8ebe-42073c89d4ff" alt="Live Activity" width="200">
    </kbd>
    <kbd>
        <img src="https://github.com/user-attachments/assets/58b51430-3e01-4f65-8ebe-42073c89d4ff" alt="History View" width="200">
    </kbd>
</div>

## Technologies Used 💻

This project leverages modern Swift, SwiftUI, and Apple platform APIs for a native, privacy-first collaboration experience.

- [x] Swift 6
- [x] SwiftUI
- [x] Observation framework
- [x] Swift Concurrency (`async/await`, actors)
- [x] Swift Testing + XCTest UI Testing
- [ ] FamilyControls
- [ ] ManagedSettings
- [ ] DeviceActivity
- [ ] ActivityKit + WidgetKit (Live Activities)
- [ ] FirebaseAuth
- [ ] Firestore
- [ ] FirebaseMessaging (FCM)
- [ ] SwiftData
- [ ] UserNotifications
- [ ] AppIntents + Shortcuts
- [ ] Charts

## Skills Demonstrated 🥋

This project is designed to showcase high-quality iOS engineering practices:

- [x] **SYSTEM DESIGN**: Local-first architecture with real-time synchronization for a shared state machine.
- [x] **STATE MANAGEMENT**: Explicit session events and deterministic transitions across two devices.
- [x] **PLATFORM INTEGRATION**: Deep integration with Screen Time APIs and Live Activities.
- [x] **PERFORMANCE/COST AWARENESS**: Transition-based Firestore sync (not per-second timer writes).
- [x] **PRIVACY & CONSENT**: Collaborative control model aligned with Apple policy constraints.
- [x] **TESTABILITY**: Protocol-oriented abstractions and pure domain logic for unit testing.

## Contributing ⚙️

Contributions are welcome. If you have ideas for features, architecture improvements, or bug fixes, open an issue or submit a pull request. Please keep changes aligned with the project's local-first and consent-first design principles.

## License 🪪

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

</div>
