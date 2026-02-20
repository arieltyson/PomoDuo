import Foundation
import UIKit

/// Supplies diagnostic context for feedback payloads.
protocol FeedbackDiagnosticsProviding: Sendable {
    func diagnosticsSummary() -> String
}

/// Default diagnostics source for real devices.
struct DefaultFeedbackDiagnosticsProvider: FeedbackDiagnosticsProviding {
    func diagnosticsSummary() -> String {
        let device = UIDevice.current
        let appVersion =
            Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "?"
        let buildNumber =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "?"

        return """
            Device: \(device.model)
            iOS: \(device.systemVersion)
            App: \(appVersion) (\(buildNumber))
            """
    }
}
