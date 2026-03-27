import LinkPresentation
import SwiftUI

/// Screen displayed while waiting for a partner to join a generated code.
struct WaitingForPartnerView: View {
    let code: PairCode
    let onCancel: () -> Void

    var body: some View {
        VStack {
            Spacer()

            WaitingHeader()

            PairingCodeCard(code: code)
                .padding(.top, 32)

            Text("They can enter it in PomoDuo to connect with you.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            Button("Cancel", systemImage: "xmark.circle", role: .cancel, action: onCancel)
                .buttonStyle(WaitingCancelButtonStyle())
                .padding(.bottom)
        }
    }
}

// MARK: - Subviews

private struct WaitingHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(AppColors.lavender)

            Text("Waiting for Partner")
                .font(.title2)
                .bold()

            Text("Share this code with your partner")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PairingCodeCard: View {
    let code: PairCode
    @State private var isShowingShareSheet = false

    var body: some View {
        VStack(spacing: 16) {
            Text(code.displayValue)
                .font(.system(.largeTitle, design: .monospaced))
                .bold()
                .foregroundStyle(AppColors.lavender)

            Button {
                isShowingShareSheet = true
            } label: {
                Label("Share Code", systemImage: "square.and.arrow.up")
                    .font(.subheadline)
            }
            .tint(AppColors.lilac)
            .sheet(isPresented: $isShowingShareSheet) {
                PairCodeShareSheet(code: code)
                    .presentationDetents([.medium, .large])
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(AppColors.paleViolet.opacity(0.15))
        .clipShape(.rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Pairing code \(code.value.map(String.init).joined(separator: " "))"
        )
    }
}

// MARK: - Rich Pair Code Share

private struct PairCodeShareSheet: UIViewControllerRepresentable {
    let code: PairCode

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let itemSource = PairCodeActivityItemSource(
            code: code,
            iconImage: renderShareIcon()
        )
        return UIActivityViewController(
            activityItems: [itemSource],
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}

    @MainActor
    private func renderShareIcon() -> UIImage {
        let renderer = ImageRenderer(content: PairCodeShareIconView())
        renderer.scale = 3
        return renderer.uiImage ?? UIImage(systemName: "link.badge.plus")!
    }
}

private final class PairCodeActivityItemSource: NSObject, UIActivityItemSource {
    let code: PairCode
    let iconImage: UIImage

    private var pairDeepLink: URL {
        URL(string: "pomoduo://pair/\(code.value)")!
    }

    private var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/pomo-duo/id6759349583")!
    }

    init(code: PairCode, iconImage: UIImage) {
        self.code = code
        self.iconImage = iconImage
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        ""
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        """
        Lock in with me on PomoDuo! Use code \(code.displayValue) to connect.

        \(appStoreURL.absoluteString)
        """
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        "Lock In With Me on PomoDuo"
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = appStoreURL
        metadata.url = appStoreURL
        metadata.title = "Lock In With Me — Code: \(code.displayValue)"
        metadata.iconProvider = NSItemProvider(object: iconImage)
        return metadata
    }
}

private struct PairCodeShareIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [AppColors.lavender, AppColors.lilac],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)

            Image(systemName: "link.badge.plus")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

/// Glass-material capsule button matching the app's design system.
private struct WaitingCancelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .fontWeight(.semibold)
            .foregroundStyle(AppColors.stopTint)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(.thinMaterial, in: .capsule)
            .overlay {
                Capsule()
                    .stroke(AppColors.stopTint.opacity(0.36), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
