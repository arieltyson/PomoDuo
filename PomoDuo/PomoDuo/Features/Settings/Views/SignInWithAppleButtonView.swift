import AuthenticationServices
import SwiftUI

enum AppleButtonLabel: Sendable {
    case signIn
    case `continue`
    case signUp
}

/// Sign in with Apple button styled to match the system treatment.
///
/// The authorization flow itself is handled by ``AppleSignInCoordinator``
/// through ``AuthManager``, which keeps nonce and credential handling
/// centralized in the auth layer.
struct SignInWithAppleButtonView: View {
    let label: AppleButtonLabel
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    init(
        label: AppleButtonLabel = .signIn,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "apple.logo")
                Text(labelText)
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(labelText)
    }

    private var labelText: String {
        switch label {
        case .signIn:
            "Sign in with Apple"
        case .continue:
            "Continue with Apple"
        case .signUp:
            "Sign up with Apple"
        @unknown default:
            "Sign in with Apple"
        }
    }

    private var foregroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? .white : .black
    }
}

/// Contextual prompt that encourages anonymous users to link Apple ID.
struct AppleIDUpgradePromptView: View {
    let onLinkApple: () -> Void

    var body: some View {
        VStack {
            Image(systemName: "person.badge.shield.checkmark.fill")
                .font(.largeTitle)
                .foregroundStyle(AppColors.lavender)
                .accessibilityHidden(true)

            Text("Secure Your Account")
                .font(.headline)

            Text(
                "Link your Apple ID to keep your partnerships, stats, and history safe even if you reinstall the app."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            SignInWithAppleButtonView(label: .continue, action: onLinkApple)
        }
    }
}
