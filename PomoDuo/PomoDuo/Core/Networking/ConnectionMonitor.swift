import Foundation
import Network
import OSLog
import Observation

/// Monitors network connectivity and exposes it as observable state.
///
/// The Partner tab and paired session UI use this to show an offline
/// banner so users understand when real-time sync is unavailable.
///
/// Internally wraps `NWPathMonitor` on a dedicated dispatch queue.
/// Path updates are forwarded to the main actor for SwiftUI binding.
@MainActor
@Observable
final class ConnectionMonitor {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "ConnectionMonitor"
    )

    /// Whether the device currently has a network path that is satisfied.
    private(set) var isConnected = true

    /// The interface type of the current path (wifi, cellular, etc.).
    private(set) var connectionType: NWInterface.InterfaceType?

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(
        label: "com.arieljtyson.PomoDuo.ConnectionMonitor",
        qos: .utility
    )

    init() {
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let interfaceType = path.availableInterfaces.first?.type

            Task { @MainActor [weak self] in
                guard let self else { return }

                let wasConnected = self.isConnected
                self.isConnected = connected
                self.connectionType = interfaceType

                if wasConnected && !connected {
                    Self.logger.notice("Network connection lost.")
                } else if !wasConnected && connected {
                    Self.logger.notice("Network connection restored.")
                }
            }
        }

        monitor.start(queue: monitorQueue)
    }
}
