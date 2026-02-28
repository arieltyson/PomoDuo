import Foundation
import MetricKit
import OSLog

/// Receives daily production performance payloads from MetricKit.
@preconcurrency
final class MetricKitSubscriber: NSObject {
    static let shared = MetricKitSubscriber()

    nonisolated private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "MetricKit"
    )

    private var isRegistered = false

    private override init() {
        super.init()
    }

    func start() {
        guard !isRegistered else { return }
        MXMetricManager.shared.add(self)
        isRegistered = true
        Self.logger.notice("MetricKit subscriber registered.")
    }

    deinit {
        guard isRegistered else { return }
        MXMetricManager.shared.remove(self)
    }
}

extension MetricKitSubscriber: MXMetricManagerSubscriber {
    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            log(metricPayload: payload)
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            log(diagnosticPayload: payload)
        }
    }
}

extension MetricKitSubscriber {
    nonisolated fileprivate func log(metricPayload: MXMetricPayload) {
        if let cpuTime = metricPayload.cpuMetrics?.cumulativeCPUTime {
            let seconds = cpuTime.converted(to: .seconds).value
            Self.logger.notice("CPU time (s): \(seconds, privacy: .public)")
        }

        if let peakMemory = metricPayload.memoryMetrics?.peakMemoryUsage {
            let megabytes = peakMemory.converted(to: .megabytes).value
            Self.logger.notice(
                "Peak memory (MB): \(megabytes, privacy: .public)"
            )
        }

        if let foreground = metricPayload.applicationTimeMetrics?
            .cumulativeForegroundTime
        {
            let seconds = foreground.converted(to: .seconds).value
            Self.logger.notice(
                "Foreground runtime (s): \(seconds, privacy: .public)"
            )
        }

        if let background = metricPayload.applicationTimeMetrics?
            .cumulativeBackgroundTime
        {
            let seconds = background.converted(to: .seconds).value
            Self.logger.notice(
                "Background runtime (s): \(seconds, privacy: .public)"
            )
        }

        if let diskWrites = metricPayload.diskIOMetrics?.cumulativeLogicalWrites
        {
            let megabytes = diskWrites.converted(to: .megabytes).value
            Self.logger.notice(
                "Logical disk writes (MB): \(megabytes, privacy: .public)"
            )
        }

        if let hitchRatio = metricPayload.animationMetrics?.hitchTimeRatio {
            Self.logger.notice(
                "Animation hitch ratio: \(hitchRatio.value, privacy: .public)"
            )
        } else if let scrollHitchRatio = metricPayload.animationMetrics?
            .scrollHitchTimeRatio
        {
            Self.logger.notice(
                "Scroll hitch ratio: \(scrollHitchRatio.value, privacy: .public)"
            )
        }
    }

    nonisolated fileprivate func log(diagnosticPayload: MXDiagnosticPayload) {
        let hangCount = diagnosticPayload.hangDiagnostics?.count ?? 0
        let crashCount = diagnosticPayload.crashDiagnostics?.count ?? 0
        let cpuExceptionCount =
            diagnosticPayload.cpuExceptionDiagnostics?.count
            ?? 0
        let diskWriteExceptionCount =
            diagnosticPayload
            .diskWriteExceptionDiagnostics?.count ?? 0

        if hangCount > 0 || crashCount > 0 || cpuExceptionCount > 0
            || diskWriteExceptionCount > 0
        {
            Self.logger.fault(
                """
                Diagnostics - hangs: \(hangCount, privacy: .public), \
                crashes: \(crashCount, privacy: .public), \
                cpu exceptions: \(cpuExceptionCount, privacy: .public), \
                disk write exceptions: \(diskWriteExceptionCount, privacy: .public)
                """
            )
        } else {
            Self.logger.notice(
                "Diagnostic payload received with no critical events."
            )
        }
    }
}
