import Foundation
import Testing

@testable import PomoDuo

@MainActor
struct FeedbackViewModelTests {
    @Test func submissionDisabledForWhitespaceOnlyMessage() {
        let viewModel = FeedbackViewModel(
            category: .bug,
            diagnosticsProvider: StubDiagnosticsProvider(summary: "stub")
        )

        viewModel.message = "   \n"

        #expect(viewModel.isSubmissionEnabled == false)
    }

    @Test func composedBodyIncludesDiagnosticsWhenEnabled() {
        let viewModel = FeedbackViewModel(
            category: .feature,
            diagnosticsProvider: StubDiagnosticsProvider(summary: "Device: Test")
        )

        viewModel.message = "Please add session templates."
        viewModel.includesDiagnostics = true

        #expect(
            viewModel.composedBody.localizedStandardContains(
                "Please add session templates"
            )
        )
        #expect(viewModel.composedBody.localizedStandardContains("Device: Test"))
    }

    @Test func composedBodyOmitsDiagnosticsWhenDisabled() {
        let viewModel = FeedbackViewModel(
            category: .feature,
            diagnosticsProvider: StubDiagnosticsProvider(summary: "Device: Test")
        )

        viewModel.message = "Please add shared presets."
        viewModel.includesDiagnostics = false

        #expect(
            viewModel.composedBody.localizedStandardContains("Device: Test")
                == false
        )
    }

    @Test func mailtoURLContainsSubjectAndBody() {
        let viewModel = FeedbackViewModel(
            category: .bug,
            diagnosticsProvider: StubDiagnosticsProvider(summary: "Device: Test")
        )

        viewModel.message = "Timer froze after pause."

        guard
            let url = viewModel.makeMailtoURL(
                emailAddress: "feedback@example.com"
            ),
            let components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )
        else {
            Issue.record("Expected valid mailto URL.")
            return
        }

        #expect(components.scheme == "mailto")
        #expect(components.path == "feedback@example.com")

        let queryItems = components.queryItems ?? []
        let subject = queryItems.first(where: { $0.name == "subject" })?.value
        let body = queryItems.first(where: { $0.name == "body" })?.value

        #expect(subject == "PomoDuo Bug Report")
        #expect((body ?? "").localizedStandardContains("Timer froze after pause"))
    }
}

private struct StubDiagnosticsProvider: FeedbackDiagnosticsProviding {
    let summary: String

    func diagnosticsSummary() -> String {
        summary
    }
}
