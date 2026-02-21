import OSLog
import SwiftUI
import UIKit

/// In-app sheet for bug reports and feature suggestions.
struct FeedbackView: View {
    private static let supportEmailAddress = "arieltyson30190@gmail.com"
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "Feedback"
    )

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var viewModel: FeedbackViewModel

    init(category: FeedbackCategory) {
        _viewModel = State(initialValue: FeedbackViewModel(category: category))
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        NavigationStack {
            Form {
                Section {
                    FeedbackHeaderView(category: viewModel.category)
                }

                Section("Description") {
                    TextField(
                        viewModel.category.placeholder,
                        text: $bindableViewModel.message,
                        axis: .vertical
                    )
                    .lineLimit(4...10)
                    .accessibilityLabel(viewModel.category.accessibilityFieldLabel)
                }

                Section {
                    Toggle(
                        "Include device info",
                        isOn: $bindableViewModel.includesDiagnostics
                    )
                } footer: {
                    Text(
                        "Adds device model, iOS version, and app version to help diagnose issues."
                    )
                }

                if viewModel.didCopyFeedback {
                    Section {
                        Label(
                            "Feedback copied. Thanks for sharing it.",
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.green)
                        .accessibilityLabel("Feedback copied")
                    }
                }
            }
            .navigationTitle(viewModel.category.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Menu("Submit", systemImage: "paperplane") {
                        Button("Send via Email", systemImage: "envelope") {
                            submitViaEmailOrCopy()
                        }

                        Button("Copy to Clipboard", systemImage: "doc.on.doc") {
                            copyToClipboardAndDismiss()
                        }
                    }
                    .disabled(!viewModel.isSubmissionEnabled)
                }
            }
        }
    }

    private func submitViaEmailOrCopy() {
        guard
            let emailURL = viewModel.makeMailtoURL(
                emailAddress: Self.supportEmailAddress
            )
        else {
            copyToClipboardAndDismiss()
            return
        }

        openURL(emailURL) { accepted in
            if accepted {
                dismiss()
            } else {
                copyToClipboardAndDismiss()
            }
        }
    }

    private func copyToClipboardAndDismiss() {
        UIPasteboard.general.string = viewModel.composedBody
        viewModel.markFeedbackCopied()

        Self.logger.info(
            "Feedback copied to clipboard for category: \(viewModel.category.rawValue, privacy: .public)"
        )

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        }
    }
}
