import SwiftUI

/// Adaptive timer controls for idle, active, and completed states.
struct TimerControlsView: View {
    let isRunning: Bool
    let isPaused: Bool
    let isComplete: Bool

    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if isComplete {
                CompletedControls(onSkip: onSkip)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .scale(scale: 0.85)
                                    .combined(with: .opacity),
                                removal: .opacity
                            )
                    )
            } else if isRunning {
                ActiveControls(
                    isPaused: isPaused,
                    onPause: onPause,
                    onResume: onResume,
                    onStop: onStop,
                    onSkip: onSkip
                )
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .move(edge: .bottom)
                                .combined(with: .opacity),
                            removal: .opacity
                        )
                )
            } else {
                IdleControls(onStart: onStart)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .scale(scale: 0.9)
                                    .combined(with: .opacity),
                                removal: .scale(scale: 0.8)
                                    .combined(with: .opacity)
                            )
                    )
            }
        }
        .animation(
            reduceMotion ? .none : .spring(duration: 0.35, bounce: 0.2),
            value: isRunning
        )
        .animation(
            reduceMotion ? .none : .spring(duration: 0.35, bounce: 0.2),
            value: isPaused
        )
        .animation(
            reduceMotion ? .none : .spring(duration: 0.35, bounce: 0.2),
            value: isComplete
        )
    }
}

private struct IdleControls: View {
    let onStart: () -> Void

    var body: some View {
        Button("Start Focus", systemImage: "play.fill", action: onStart)
            .buttonStyle(.borderedProminent)
            .tint(AppColors.lavender)
            .controlSize(.large)
            .accessibilityHint("Begins a new focus session.")
            .accessibilityInputLabels(["Start Focus", "Start", "Begin", "Go"])
    }
}

private struct ActiveControls: View {
    let isPaused: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            Button("Stop", systemImage: "stop.fill", action: onStop)
                .buttonStyle(
                    SecondaryControlButtonStyle(tint: AppColors.stopTint)
                )
                .accessibilityHint("Ends the session and resets the timer.")
                .accessibilityInputLabels(["Stop", "End"])

            if isPaused {
                Button("Resume", systemImage: "play.fill", action: onResume)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.lavender)
                    .controlSize(.large)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.92).combined(with: .opacity)
                    )
                    .accessibilityHint("Continues the paused timer.")
                    .accessibilityInputLabels(["Resume", "Play", "Continue"])
            } else {
                Button("Pause", systemImage: "pause.fill", action: onPause)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.pauseTint)
                    .controlSize(.large)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.92).combined(with: .opacity)
                    )
                    .accessibilityHint("Pauses the running timer.")
            }

            Button("Skip", systemImage: "forward.fill", action: onSkip)
                .buttonStyle(
                    SecondaryControlButtonStyle(tint: AppColors.lavender)
                )
                .accessibilityHint("Skips to the next phase.")
                .accessibilityInputLabels(["Skip", "Next"])
        }
    }
}

private struct CompletedControls: View {
    let onSkip: () -> Void

    var body: some View {
        Button("Continue", systemImage: "arrow.right", action: onSkip)
            .buttonStyle(.borderedProminent)
            .tint(AppColors.success)
            .controlSize(.large)
            .accessibilityHint("Moves to the next phase.")
            .accessibilityInputLabels(["Continue", "Next", "Done"])
    }
}

private struct SecondaryControlButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint)
            .padding(.horizontal)
            .padding(.vertical)
            .background(.thinMaterial, in: .capsule)
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.36), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
