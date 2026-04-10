import SwiftUI

struct PairedSessionControls: View {
    let session: StudySession
    let viewModel: PartnerSessionViewModel
    let hasReachedPhaseEnd: Bool
    @Binding var isShowingEndConfirmation: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            Group {
                switch session.state {
                case .requesting:
                    Button(
                        "Cancel",
                        systemImage: "xmark.circle",
                        role: .destructive
                    ) {
                        Task {
                            await viewModel.endSession()
                        }
                    }
                    .buttonStyle(
                        PairedControlButtonStyle(tint: AppColors.stopTint)
                    )

                case .focus where session.isPaused:
                    HStack(spacing: 12) {
                        Button("End Session", systemImage: "stop.fill") {
                            isShowingEndConfirmation = true
                        }
                        .buttonStyle(
                            PairedControlButtonStyle(tint: AppColors.stopTint)
                        )
                        .accessibilityHint("Ends the session for both partners.")
                        .accessibilityInputLabels(["End Session", "End", "Stop"])

                        Button("Resume", systemImage: "play.fill") {
                            Task {
                                await viewModel.resumeSession()
                            }
                        }
                        .buttonStyle(
                            PairedControlButtonStyle(tint: AppColors.lavender)
                        )
                        .accessibilityHint("Continues the paused timer.")
                        .accessibilityInputLabels(["Resume", "Play", "Continue"])
                    }
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.92).combined(with: .opacity)
                    )

                case .focus:
                    VStack(spacing: 10) {
                        if hasReachedPhaseEnd {
                            Button(
                                "Continue to Break",
                                systemImage: "arrow.right"
                            ) {
                                Task {
                                    await viewModel.beginBreak()
                                }
                            }
                            .buttonStyle(
                                PairedControlButtonStyle(tint: AppColors.success)
                            )
                            .accessibilityInputLabels([
                                "Continue to Break",
                                "Continue",
                                "Break",
                            ])
                        } else {
                            HStack(spacing: 12) {
                                Button("Pause", systemImage: "pause.fill") {
                                    Task {
                                        await viewModel.pauseSession()
                                    }
                                }
                                .buttonStyle(
                                    PairedControlButtonStyle(tint: AppColors.pauseTint)
                                )
                                .accessibilityHint("Pauses the timer for both partners.")

                                Button("Skip to Break", systemImage: "forward.fill") {
                                    Task {
                                        await viewModel.beginBreak()
                                    }
                                }
                                .buttonStyle(
                                    PairedControlButtonStyle(tint: AppColors.lavender)
                                )
                                .accessibilityInputLabels([
                                    "Skip to Break",
                                    "Skip",
                                    "Break",
                                ])
                            }
                        }

                        Button("End Session", systemImage: "stop.fill") {
                            isShowingEndConfirmation = true
                        }
                        .buttonStyle(
                            PairedControlButtonStyle(tint: AppColors.stopTint)
                        )
                        .accessibilityHint("Ends the session for both partners.")
                        .accessibilityInputLabels(["End Session", "End", "Stop"])
                    }
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.92).combined(with: .opacity)
                    )

                case .shortBreak, .longBreak:
                    VStack(spacing: 10) {
                        Button(
                            hasReachedPhaseEnd
                                ? "Continue to Focus"
                                : "Next Round",
                            systemImage: hasReachedPhaseEnd
                                ? "arrow.right"
                                : "play.fill"
                        ) {
                            Task {
                                await viewModel.beginFocus()
                            }
                        }
                        .buttonStyle(
                            PairedControlButtonStyle(tint: AppColors.lavender)
                        )
                        .accessibilityInputLabels([
                            hasReachedPhaseEnd ? "Continue to Focus" : "Next Round",
                            "Next",
                            "Continue",
                        ])

                        Button("End Session", systemImage: "stop.fill") {
                            isShowingEndConfirmation = true
                        }
                        .buttonStyle(
                            PairedControlButtonStyle(tint: AppColors.stopTint)
                        )
                        .accessibilityHint("Ends the session for both partners.")
                        .accessibilityInputLabels(["End Session", "End", "Stop"])
                    }

                case .completed:
                    Button("Done", systemImage: "checkmark") {
                        Task {
                            await viewModel.endSession()
                        }
                    }
                    .buttonStyle(
                        PairedControlButtonStyle(tint: AppColors.success)
                    )
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.85).combined(with: .opacity)
                    )

                case .idle:
                    EmptyView()
                }
            }
            .animation(
                reduceMotion ? .none : .spring(duration: 0.35, bounce: 0.2),
                value: session.state
            )
            .animation(
                reduceMotion ? .none : .spring(duration: 0.35, bounce: 0.2),
                value: session.isPaused
            )
        }
    }
}

/// Glass-material button style matching the solo session's ``SecondaryControlButtonStyle``.
private struct PairedControlButtonStyle: ButtonStyle {
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
