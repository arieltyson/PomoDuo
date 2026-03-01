import SwiftUI

/// First-launch onboarding flow introducing core app capabilities.
struct OnboardingView: View {
    @Environment(NotificationManager.self) private var notificationManager

    @State private var viewModel = OnboardingViewModel()
    @State private var isRequestingNotificationPermission = false

    let onComplete: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack {
                OnboardingProgressHeader(viewModel: viewModel)

                Spacer()

                OnboardingStepCard(
                    step: viewModel.currentStep,
                    isNotificationAuthorized: notificationManager.isAuthorized
                )

                Spacer()

                OnboardingActionBar(
                    primaryTitle: primaryButtonTitle(
                        for: viewModel.currentStep
                    ),
                    isPrimaryDisabled: isRequestingNotificationPermission,
                    shouldShowBack: !viewModel.isFirstStep,
                    shouldShowSkip: !viewModel.isLastStep,
                    onPrimary: handlePrimaryAction,
                    onBack: viewModel.goBack,
                    onSkip: viewModel.jumpToFinalStep
                )
            }
            .padding()
        }
        .interactiveDismissDisabled()
    }

    private func primaryButtonTitle(for step: OnboardingStep) -> String {
        switch step {
        case .notifications where notificationManager.isAuthorized:
            "Continue"
        case .appBlocking:
            "Open Settings"
        default:
            step.ctaTitle
        }
    }

    private func handlePrimaryAction() {
        switch viewModel.currentStep {
        case .notifications:
            if notificationManager.isAuthorized {
                if viewModel.advance() {
                    onComplete()
                }
            } else {
                requestNotificationPermissionAndAdvance()
            }
        case .appBlocking:
            onOpenSettings()
            onComplete()
        default:
            if viewModel.advance() {
                onComplete()
            }
        }
    }

    private func requestNotificationPermissionAndAdvance() {
        guard !isRequestingNotificationPermission else { return }

        isRequestingNotificationPermission = true
        Task {
            await notificationManager.requestPermission()
            isRequestingNotificationPermission = false

            if viewModel.advance() {
                onComplete()
            }
        }
    }
}

private struct OnboardingBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                AppColors.lilac.opacity(0.32),
                AppColors.paleViolet.opacity(0.2),
                .clear,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            RoundedRectangle(cornerRadius: 40)
                .fill(.thinMaterial)
                .padding()
                .blur(radius: 48)
                .opacity(0.6)
                .ignoresSafeArea()
        }
    }
}

private struct OnboardingProgressHeader: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Getting Started")
                    .font(.title3)
                    .bold()

                Spacer()

                Text(
                    "\(viewModel.currentIndex + 1) of \(viewModel.steps.count)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ProgressView(value: viewModel.progressValue)
                .tint(AppColors.lavender)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Getting Started, step \(viewModel.currentIndex + 1) of \(viewModel.steps.count)"
        )
        .accessibilityValue(
            "\(Int(viewModel.progressValue * 100)) percent complete"
        )
    }
}

private struct OnboardingStepCard: View {
    let step: OnboardingStep
    let isNotificationAuthorized: Bool

    var body: some View {
        VStack {
            OnboardingIconPair(step: step)

            Text(step.title)
                .font(.system(.title, design: .rounded))
                .bold()
                .multilineTextAlignment(.center)
                .padding(.top)
                .accessibilityAddTraits(.isHeader)

            Text(step.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            OnboardingStepStatus(
                step: step,
                isNotificationAuthorized: isNotificationAuthorized
            )
            .padding(.top)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(AppColors.lavender.opacity(0.2), lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: 28))
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingIconPair: View {
    let step: OnboardingStep

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: step.symbolName)
                .font(.title)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(AppColors.lavender, in: .circle)

            Image(systemName: step.accentSymbolName)
                .font(.title2)
                .foregroundStyle(AppColors.lavender)
                .frame(width: 44, height: 44)
                .background(AppColors.lavender.opacity(0.15), in: .circle)
        }
        .accessibilityHidden(true)
    }
}

private struct OnboardingStepStatus: View {
    let step: OnboardingStep
    let isNotificationAuthorized: Bool

    var body: some View {
        switch step {
        case .notifications:
            OnboardingBadge(
                title: isNotificationAuthorized
                    ? "Notifications Enabled" : "Notifications Not Enabled Yet",
                systemImage: isNotificationAuthorized
                    ? "checkmark.circle.fill" : "bell.slash.fill",
                tint: isNotificationAuthorized
                    ? AppColors.success : AppColors.pauseTint
            )
        case .appBlocking:
            OnboardingBadge(
                title: "You can configure this in Settings > App Blocking",
                systemImage: "shield.fill",
                tint: AppColors.lavender
            )
        default:
            EmptyView()
        }
    }
}

private struct OnboardingBadge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.12), in: .capsule)
            .multilineTextAlignment(.center)
    }
}

private struct OnboardingActionBar: View {
    let primaryTitle: String
    let isPrimaryDisabled: Bool
    let shouldShowBack: Bool
    let shouldShowSkip: Bool
    let onPrimary: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack {
            Button(
                primaryTitle,
                systemImage: "arrow.right.circle.fill",
                action: onPrimary
            )
            .buttonStyle(.borderedProminent)
            .tint(AppColors.lavender)
            .controlSize(.large)
            .disabled(isPrimaryDisabled)
            .accessibilityHint("Moves to the next onboarding step.")

            HStack {
                if shouldShowBack {
                    Button("Back", systemImage: "chevron.left", action: onBack)
                        .buttonStyle(.bordered)
                        .accessibilityHint("Returns to the previous onboarding step.")
                }

                Spacer()

                if shouldShowSkip {
                    Button(
                        "Skip",
                        systemImage: "forward.end.alt",
                        action: onSkip
                    )
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityHint("Skips to the final onboarding step.")
                }
            }
            .padding(.top, 10)
        }
    }
}

#Preview {
    OnboardingView(onComplete: {}, onOpenSettings: {})
        .environment(NotificationManager())
}
