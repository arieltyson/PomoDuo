import SwiftUI

/// First-launch onboarding flow introducing core app capabilities.
///
/// Inspired by Apple's own onboarding patterns (Fitness, Weather, Health):
/// - Full-screen immersive pages with per-step gradient theming
/// - Large animated hero symbols with SF Symbol effects
/// - Staggered entrance animations for content hierarchy
/// - Haptic feedback on every navigation event
/// - Full accessibility support with reduce-motion fallbacks
struct OnboardingView: View {
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = OnboardingViewModel()
    @State private var isRequestingNotificationPermission = false

    let onComplete: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack {
            // Animated gradient background keyed to current step.
            OnboardingGradientBackground(step: viewModel.currentStep)

            VStack(spacing: 0) {
                OnboardingProgressBar(viewModel: viewModel)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                Spacer()

                OnboardingPageContent(
                    step: viewModel.currentStep,
                    direction: viewModel.navigationDirection,
                    isNotificationAuthorized: notificationManager.isAuthorized
                )
                .padding(.horizontal, 32)

                Spacer()

                OnboardingControls(
                    viewModel: viewModel,
                    primaryTitle: primaryButtonTitle,
                    isPrimaryDisabled: isRequestingNotificationPermission,
                    onPrimary: handlePrimaryAction,
                    onBack: viewModel.goBack,
                    onSkip: viewModel.jumpToFinalStep
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .sensoryFeedback(viewModel.haptic.feedback, trigger: viewModel.haptic)
        .interactiveDismissDisabled()
    }

    // MARK: - Actions

    private var primaryButtonTitle: String {
        switch viewModel.currentStep {
        case .notifications where notificationManager.isAuthorized:
            "Continue"
        case .appBlocking:
            "Open Settings"
        default:
            viewModel.currentStep.ctaTitle
        }
    }

    private func handlePrimaryAction() {
        switch viewModel.currentStep {
        case .notifications:
            if notificationManager.isAuthorized {
                if viewModel.advance() { onComplete() }
            } else {
                requestNotificationPermissionAndAdvance()
            }
        case .appBlocking:
            onOpenSettings()
            onComplete()
        default:
            if viewModel.advance() { onComplete() }
        }
    }

    private func requestNotificationPermissionAndAdvance() {
        guard !isRequestingNotificationPermission else { return }

        isRequestingNotificationPermission = true
        Task {
            await notificationManager.requestPermission()
            isRequestingNotificationPermission = false
            if viewModel.advance() { onComplete() }
        }
    }
}

// MARK: - Gradient Background

/// Full-screen gradient that cross-fades between step-specific palettes.
private struct OnboardingGradientBackground: View {
    let step: OnboardingStep

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            LinearGradient(
                colors: step.gradientColors + [.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(
                reduceMotion ? .none : .easeInOut(duration: 0.5),
                value: step
            )

            // Subtle floating orb for depth.
            Circle()
                .fill(step.heroTint.opacity(0.08))
                .frame(width: 340, height: 340)
                .blur(radius: 80)
                .offset(y: -60)
                .animation(
                    reduceMotion ? .none : .easeInOut(duration: 0.6),
                    value: step
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Progress Bar

/// Segmented progress indicator with animated fill.
private struct OnboardingProgressBar: View {
    let viewModel: OnboardingViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Getting Started")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(viewModel.currentIndex + 1) of \(viewModel.steps.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 4) {
                ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) { index, _ in
                    Capsule()
                        .fill(index <= viewModel.currentIndex
                              ? AppColors.lavender
                              : AppColors.lavender.opacity(0.15))
                        .frame(height: 4)
                        .animation(
                            reduceMotion
                                ? .none
                                : .spring(duration: 0.4, bounce: 0.2),
                            value: viewModel.currentIndex
                        )
                }
            }
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

// MARK: - Page Content

/// The hero area: animated symbols, title, and description with staggered entrance.
private struct OnboardingPageContent: View {
    let step: OnboardingStep
    let direction: OnboardingViewModel.NavigationDirection
    let isNotificationAuthorized: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 24) {
            // Hero symbol pair
            OnboardingHeroSymbols(step: step)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : (reduceMotion ? 0 : 16))

            // Title
            Text(step.title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : (reduceMotion ? 0 : 12))
                .accessibilityAddTraits(.isHeader)

            // Description
            Text(step.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : (reduceMotion ? 0 : 8))

            // Status badges
            OnboardingStepStatus(
                step: step,
                isNotificationAuthorized: isNotificationAuthorized
            )
            .opacity(isVisible ? 1 : 0)
        }
        .animation(
            reduceMotion ? .none : .spring(duration: 0.5, bounce: 0.15),
            value: isVisible
        )
        .onChange(of: step) { _, _ in
            // Re-trigger entrance animation on step change.
            isVisible = false
            Task {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 50 : 120))
                isVisible = true
            }
        }
        .task {
            // Initial entrance with slight delay for polish.
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 50 : 200))
            isVisible = true
        }
    }
}

// MARK: - Hero Symbols

/// Large animated SF Symbol pair — primary in a filled circle, accent beside it.
private struct OnboardingHeroSymbols: View {
    let step: OnboardingStep

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 14) {
            // Primary hero symbol
            Image(systemName: step.heroSymbol)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(step.heroTint.gradient, in: .circle)
                .shadow(color: step.heroTint.opacity(0.3), radius: 12, y: 6)
                .symbolEffect(
                    .pulse.wholeSymbol,
                    options: reduceMotion ? .nonRepeating : .repeating.speed(0.5),
                    value: step
                )

            // Accent companion symbol
            Image(systemName: step.accentSymbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(step.heroTint)
                .frame(width: 52, height: 52)
                .background(step.heroTint.opacity(0.12), in: .circle)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Step Status

private struct OnboardingStepStatus: View {
    let step: OnboardingStep
    let isNotificationAuthorized: Bool

    var body: some View {
        switch step {
        case .notifications:
            OnboardingBadge(
                title: isNotificationAuthorized
                    ? "Notifications Enabled"
                    : "Notifications Not Enabled Yet",
                systemImage: isNotificationAuthorized
                    ? "checkmark.circle.fill"
                    : "bell.slash.fill",
                tint: isNotificationAuthorized
                    ? AppColors.success
                    : AppColors.pauseTint
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

// MARK: - Badge

private struct OnboardingBadge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(tint.opacity(0.1), in: .capsule)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Controls

/// Bottom action area with primary CTA, back, and skip buttons.
private struct OnboardingControls: View {
    let viewModel: OnboardingViewModel
    let primaryTitle: String
    let isPrimaryDisabled: Bool
    let onPrimary: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
            // Primary CTA — large rounded button with gradient fill.
            Button(action: onPrimary) {
                HStack(spacing: 8) {
                    Text(primaryTitle)
                        .fontWeight(.semibold)

                    Image(systemName: viewModel.isLastStep
                          ? "checkmark.circle.fill"
                          : "arrow.right")
                        .font(.body.weight(.semibold))
                        .symbolEffect(
                            .bounce,
                            options: .nonRepeating,
                            value: viewModel.currentIndex
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .foregroundStyle(.white)
            .background(AppColors.lavender.gradient, in: .capsule)
            .shadow(
                color: AppColors.lavender.opacity(0.25),
                radius: 16,
                y: 8
            )
            .disabled(isPrimaryDisabled)
            .opacity(isPrimaryDisabled ? 0.6 : 1)
            .animation(
                reduceMotion ? .none : .easeOut(duration: 0.2),
                value: isPrimaryDisabled
            )
            .accessibilityHint("Moves to the next onboarding step.")

            // Secondary navigation
            HStack {
                if !viewModel.isFirstStep {
                    Button(action: onBack) {
                        Label("Back", systemImage: "chevron.left")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityHint("Returns to the previous onboarding step.")
                }

                Spacer()

                if !viewModel.isLastStep {
                    Button(action: onSkip) {
                        HStack(spacing: 4) {
                            Text("Skip")
                            Image(systemName: "forward.end.alt")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                    }
                    .foregroundStyle(.tertiary)
                    .accessibilityHint("Skips to the final onboarding step.")
                }
            }
            .animation(
                reduceMotion ? .none : .easeInOut(duration: 0.25),
                value: viewModel.currentIndex
            )
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {}, onOpenSettings: {})
        .environment(NotificationManager())
}
