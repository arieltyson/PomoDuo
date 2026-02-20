import Foundation
import Observation

/// View model for composing and validating user feedback.
@MainActor
@Observable
final class FeedbackViewModel {
    let category: FeedbackCategory

    var message = ""
    var includesDiagnostics = true
    private(set) var didCopyFeedback = false

    private let diagnosticsProvider: any FeedbackDiagnosticsProviding

    init(
        category: FeedbackCategory,
        diagnosticsProvider: any FeedbackDiagnosticsProviding =
            DefaultFeedbackDiagnosticsProvider()
    ) {
        self.category = category
        self.diagnosticsProvider = diagnosticsProvider
    }

    var isSubmissionEnabled: Bool {
        !trimmedMessage.isEmpty
    }

    var composedBody: String {
        var body = """
            [\(category.title)]

            \(trimmedMessage)
            """

        if includesDiagnostics {
            body += "\n\n---\n\(diagnosticsProvider.diagnosticsSummary())"
        }

        return body
    }

    func makeMailtoURL(emailAddress: String) -> URL? {
        guard !emailAddress.isEmpty, isSubmissionEnabled else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = emailAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: category.emailSubject),
            URLQueryItem(name: "body", value: composedBody),
        ]

        return components.url
    }

    func markFeedbackCopied() {
        didCopyFeedback = true
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
