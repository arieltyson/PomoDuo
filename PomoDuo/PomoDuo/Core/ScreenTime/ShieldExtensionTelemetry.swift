import Foundation

/// App Group-backed telemetry capturing invocations of the two Screen Time
/// extensions so the main app can verify — after the fact — whether iOS
/// actually called them.
///
/// **What this answers.** iOS does not expose a direct "is this app
/// currently being shielded" signal (``ManagedSettingsStore.shield`` is
/// write-only policy input; `DeviceActivityCenter` only lists monitored
/// schedules). The closest app-visible proxy for real enforcement is
/// whether the `DeviceActivityMonitor` and `ShieldConfigurationDataSource`
/// extensions were actually invoked by the system, with what context, and
/// how recently. This file provides that observability surface.
///
/// **What this does not answer.** It cannot guarantee that every blocked
/// app will definitely present the shield on tap. Apple's docs explicitly
/// do not document whether
/// `ShieldConfigurationDataSource.configuration(shielding:)` is cached or
/// called on every presentation, so shield-extension counts are a **lower
/// bound** on the number of unique shield presentations — "at least this
/// many shield compute calls occurred" — not an exact count.
///
/// **Target membership.** This file must have target membership on the
/// main app, `PomoDuoShieldExtension`, and `PomoDuoMonitorExtension`.
/// `UserDefaults(suiteName:)` with the shared App Group is the
/// cross-process medium; reads and writes from the two extensions stay
/// in-process and sandbox-legal per Apple's extension guidance.
///
/// **Safety.** All writes are single `UserDefaults.set(_:forKey:)` calls
/// — no encoding, no collection mutation under a lock, no Foundation
/// object allocation beyond the date itself. The shield extension is
/// latency-critical ("return a configuration as quickly as possible"
/// per Apple's docs); a flush of three scalar defaults writes is the
/// cheapest observability we can emit without risking the shield's
/// presentation.
enum ShieldExtensionTelemetry {

    /// Invocation categories captured by telemetry. Each category gets
    /// its own `last` timestamp and monotonically increasing count.
    enum Event: String, CaseIterable, Sendable {
        case monitorIntervalDidStart = "monitor.intervalDidStart"
        case monitorIntervalDidEnd = "monitor.intervalDidEnd"
        case shieldForApplication = "shield.application"
        case shieldForWebDomain = "shield.webDomain"
    }

    /// Structured snapshot passed back into `ScreenTimeDiagnostics`.
    ///
    /// `Equatable` + `Sendable` so the snapshot can round-trip across
    /// actor hops without surprises and can be diffed in tests.
    struct Snapshot: Equatable, Sendable {
        let monitorIntervalDidStart: EventSnapshot
        let monitorIntervalDidEnd: EventSnapshot
        let shieldForApplication: EventSnapshot
        let shieldForWebDomain: EventSnapshot
        /// The last ``ShieldSessionContext`` state any extension observed
        /// at invocation time. Lets the diagnostics view distinguish
        /// "extension ran but context was stale" from "extension never
        /// ran". `nil` means no extension has recorded a sample yet.
        let lastObservedContext: ObservedContext?

        var allEvents: [EventSnapshot] {
            [
                monitorIntervalDidStart,
                monitorIntervalDidEnd,
                shieldForApplication,
                shieldForWebDomain,
            ]
        }

        /// The most recent invocation across every tracked event, so the
        /// UI can show a single "last extension callback" summary line.
        var mostRecentInvocation: Date? {
            allEvents.compactMap(\.lastFiredAt).max()
        }
    }

    struct EventSnapshot: Equatable, Sendable {
        let event: Event
        let count: Int
        let lastFiredAt: Date?
    }

    struct ObservedContext: Equatable, Sendable {
        /// The event that observed the context. Lets us say
        /// "monitor saw session active" vs "shield saw it missing".
        let byEvent: Event
        let observedAt: Date
        let isSessionActive: Bool
        let phase: String?
        let targetEndDate: Date?
        let focusActivityRegistered: Bool
    }

    // MARK: - Keys

    private enum Keys {
        static func count(for event: Event) -> String {
            "shield.telemetry.\(event.rawValue).count"
        }
        static func lastFiredAt(for event: Event) -> String {
            "shield.telemetry.\(event.rawValue).lastFiredAt"
        }
        // Last-observed-context keys. One row, overwritten by whichever
        // extension fired most recently.
        static let lastObservedEvent = "shield.telemetry.lastObserved.event"
        static let lastObservedAt = "shield.telemetry.lastObserved.at"
        static let lastObservedActive = "shield.telemetry.lastObserved.isActive"
        static let lastObservedPhase = "shield.telemetry.lastObserved.phase"
        static let lastObservedTargetEnd = "shield.telemetry.lastObserved.targetEnd"
        static let lastObservedActivityRegistered =
            "shield.telemetry.lastObserved.activityRegistered"
    }

    // MARK: - Persistence Access

    /// Caller-supplied defaults are used in tests; production callers
    /// use the shared App Group suite.
    static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: ShieldSessionContext.appGroupID)
    }

    // MARK: - Write (Extensions)

    /// Records an extension invocation. Writes four scalar values to the
    /// App Group `UserDefaults` — count increment, timestamp, plus a
    /// rolling observed-context snapshot so the main app can tell whether
    /// the extension saw a healthy session at callback time.
    ///
    /// - Parameters:
    ///   - event: The extension callback category that fired.
    ///   - at: Timestamp of the invocation. Injectable for tests.
    ///   - isSessionActive: `ShieldSessionContext.isSessionActive` at
    ///     the moment of the callback, as seen by the extension.
    ///   - phase: `ShieldSessionContext.sessionPhase` as seen by the
    ///     extension.
    ///   - targetEndDate: `ShieldSessionContext.targetEndDate` as seen by
    ///     the extension.
    ///   - focusActivityRegistered: Whether the DeviceActivity focus
    ///     activity was registered from the extension's point of view.
    ///     Monitor extensions can inspect this; shield extensions pass
    ///     `nil` since querying `DeviceActivityCenter` from the shield
    ///     sandbox isn't supported and would bloat a latency-critical
    ///     callback.
    ///   - defaults: Override for tests. Production callers pass `nil`.
    static func record(
        _ event: Event,
        at date: Date = .now,
        isSessionActive: Bool,
        phase: String?,
        targetEndDate: Date?,
        focusActivityRegistered: Bool? = nil,
        defaults: UserDefaults? = nil
    ) {
        let store = defaults ?? sharedDefaults()
        guard let store else { return }

        let countKey = Keys.count(for: event)
        let lastKey = Keys.lastFiredAt(for: event)
        let nextCount = store.integer(forKey: countKey) &+ 1
        store.set(nextCount, forKey: countKey)
        store.set(date.timeIntervalSince1970, forKey: lastKey)

        store.set(event.rawValue, forKey: Keys.lastObservedEvent)
        store.set(date.timeIntervalSince1970, forKey: Keys.lastObservedAt)
        store.set(isSessionActive, forKey: Keys.lastObservedActive)
        if let phase {
            store.set(phase, forKey: Keys.lastObservedPhase)
        } else {
            store.removeObject(forKey: Keys.lastObservedPhase)
        }
        if let targetEndDate {
            store.set(
                targetEndDate.timeIntervalSince1970,
                forKey: Keys.lastObservedTargetEnd
            )
        } else {
            store.removeObject(forKey: Keys.lastObservedTargetEnd)
        }
        if let focusActivityRegistered {
            store.set(
                focusActivityRegistered,
                forKey: Keys.lastObservedActivityRegistered
            )
        } else {
            store.removeObject(forKey: Keys.lastObservedActivityRegistered)
        }
    }

    // MARK: - Read (Main App)

    /// Captures the current telemetry state into a snapshot for display
    /// and diffing. Reads each event's count and timestamp plus the
    /// rolling observed-context row.
    ///
    /// - Parameter defaults: Override for tests. Production callers pass
    ///   `nil` to use the App Group suite.
    static func snapshot(defaults: UserDefaults? = nil) -> Snapshot {
        let store = defaults ?? sharedDefaults()
        let events = Event.allCases.map { event -> EventSnapshot in
            EventSnapshot(
                event: event,
                count: store?.integer(forKey: Keys.count(for: event)) ?? 0,
                lastFiredAt: Self.date(
                    forKey: Keys.lastFiredAt(for: event),
                    in: store
                )
            )
        }

        let byEventRaw = store?.string(forKey: Keys.lastObservedEvent)
        let byEvent = byEventRaw.flatMap(Event.init(rawValue:))
        let observedAt = Self.date(forKey: Keys.lastObservedAt, in: store)

        let lastObservedContext: ObservedContext? = {
            guard let byEvent, let observedAt else { return nil }
            return ObservedContext(
                byEvent: byEvent,
                observedAt: observedAt,
                isSessionActive: store?.bool(
                    forKey: Keys.lastObservedActive
                ) ?? false,
                phase: store?.string(forKey: Keys.lastObservedPhase),
                targetEndDate: Self.date(
                    forKey: Keys.lastObservedTargetEnd,
                    in: store
                ),
                focusActivityRegistered: store?.object(
                    forKey: Keys.lastObservedActivityRegistered
                ) as? Bool ?? false
            )
        }()

        func lookup(_ event: Event) -> EventSnapshot {
            events.first(where: { $0.event == event })
                ?? EventSnapshot(event: event, count: 0, lastFiredAt: nil)
        }

        return Snapshot(
            monitorIntervalDidStart: lookup(.monitorIntervalDidStart),
            monitorIntervalDidEnd: lookup(.monitorIntervalDidEnd),
            shieldForApplication: lookup(.shieldForApplication),
            shieldForWebDomain: lookup(.shieldForWebDomain),
            lastObservedContext: lastObservedContext
        )
    }

    /// Removes every telemetry key. Called from
    /// ``ScreenTimeManager/resetAllScreenTimeState()`` so users can
    /// begin a fresh diagnosis run.
    static func reset(defaults: UserDefaults? = nil) {
        guard let store = defaults ?? sharedDefaults() else { return }
        for event in Event.allCases {
            store.removeObject(forKey: Keys.count(for: event))
            store.removeObject(forKey: Keys.lastFiredAt(for: event))
        }
        store.removeObject(forKey: Keys.lastObservedEvent)
        store.removeObject(forKey: Keys.lastObservedAt)
        store.removeObject(forKey: Keys.lastObservedActive)
        store.removeObject(forKey: Keys.lastObservedPhase)
        store.removeObject(forKey: Keys.lastObservedTargetEnd)
        store.removeObject(forKey: Keys.lastObservedActivityRegistered)
    }

    // MARK: - Helpers

    private static func date(
        forKey key: String,
        in store: UserDefaults?
    ) -> Date? {
        guard let store else { return nil }
        let interval = store.double(forKey: key)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }
}
