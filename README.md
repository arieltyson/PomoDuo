<div align="center">

# PomoDuo ♥️📚

## App Store  : Coming Soon

<kbd>
    <img src="https://placehold.co/1200x650/png?text=PomoDuo+%E2%99%A5%EF%B8%8F%F0%9F%93%9A" alt="PomoDuo Hero" width="800" height="500">
</kbd>

## Project Description 🎨

"PomoDuo" is an iOS app built with SwiftUI that turns Pomodoro focus sessions into a shared commitment between two people. Instead of running two independent timers, PomoDuo uses a synchronized session state machine ("The Tethered Timer") so both users experience the same focus, break, pause, and completion states in real time.

The app combines Apple's Screen Time API stack (`FamilyControls`, `ManagedSettings`, `DeviceActivity`) with a real-time sync layer (Firebase Auth + Firestore + FCM) to support collaborative focus sessions, optional partner-triggered lock flows, and social accountability while preserving user consent and privacy.

## Current Status 🚧

This repository is currently in foundation stage with the initial SwiftUI app shell and test targets. The implementation roadmap includes:

- A protocol-driven session domain and pure state machine
- Local-first Pomodoro timer engine using Swift Concurrency
- Screen Time integration for focus-time app shielding
- Real-time two-device synchronization with Firebase
- Live Activities / Dynamic Island support via ActivityKit
- Accessibility and App Store production hardening

## Demo:

Coming soon

## Screenshots:

<div style="display: flex; justify-content: center; align-items: center;">
    <kbd>
        <img src="https://placehold.co/400x870/png?text=Dashboard" alt="Dashboard" width="200">
    </kbd>
    <kbd>
        <img src="https://placehold.co/400x870/png?text=Pairing+Flow" alt="Pairing Flow" width="200">
    </kbd>
    <kbd>
        <img src="https://placehold.co/400x870/png?text=Active+Session" alt="Active Session" width="200">
    </kbd>
</div>

<div style="display: flex; justify-content: center; align-items: center;">
    <kbd>
        <img src="https://placehold.co/400x870/png?text=App+Selection" alt="App Selection" width="200">
    </kbd>
    <kbd>
        <img src="https://placehold.co/400x870/png?text=Live+Activity" alt="Live Activity" width="200">
    </kbd>
    <kbd>
        <img src="https://placehold.co/400x870/png?text=History+View" alt="History View" width="200">
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
