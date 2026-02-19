import SwiftUI

/// A structural skeleton that mirrors the real tab layout.
///
/// Shown briefly after the launch animation dissolves and before
/// auth resolves. The skeleton matches the timer tab's visual weight
/// so the transition to real content feels seamless rather than jarring.
struct SkeletonTabView: View {
    var body: some View {
        TabView {
            Tab("Focus", systemImage: "timer") {
                NavigationStack {
                    SkeletonTimerContent()
                        .navigationTitle("Focus")
                }
            }

            Tab("Partner", systemImage: "heart.fill") {
                NavigationStack {
                    SkeletonPlaceholderContent()
                        .navigationTitle("Partner")
                }
            }

            Tab("History", systemImage: "clock.arrow.circlepath") {
                NavigationStack {
                    SkeletonPlaceholderContent()
                        .navigationTitle("History")
                }
            }

            Tab("Settings", systemImage: "gearshape") {
                NavigationStack {
                    SkeletonPlaceholderContent()
                        .navigationTitle("Settings")
                }
            }
        }
        .tint(AppColors.lavender)
    }
}

// MARK: - Timer Skeleton

/// Mirrors the timer tab's layout with placeholder shapes.
private struct SkeletonTimerContent: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Progress ring placeholder.
            Circle()
                .stroke(AppColors.lavender.opacity(0.12), lineWidth: 8)
                .frame(width: 220, height: 220)
                .overlay {
                    VStack(spacing: 8) {
                        SkeletonPill(width: 100, height: 28)
                        SkeletonPill(width: 60, height: 14)
                    }
                }

            // Round indicator placeholder.
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    Circle()
                        .fill(AppColors.lavender.opacity(0.10))
                        .frame(width: 10, height: 10)
                }
            }

            Spacer()

            // Button placeholder.
            SkeletonPill(width: 140, height: 44)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Generic Skeleton

/// Simple centered placeholder for non-timer tabs.
private struct SkeletonPlaceholderContent: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            SkeletonPill(width: 180, height: 20)
            SkeletonPill(width: 120, height: 14)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shimmer Pill

/// A rounded rectangle with a subtle shimmer animation.
private struct SkeletonPill: View {
    let width: CGFloat
    let height: CGFloat

    @State private var isShimmering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(AppColors.lavender.opacity(0.10))
            .frame(width: width, height: height)
            .overlay {
                if !reduceMotion {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    AppColors.lavender.opacity(0.08),
                                    .clear,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: isShimmering ? width : -width)
                }
            }
            .clipShape(.rect(cornerRadius: height / 2))
            .task {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    isShimmering = true
                }
            }
    }
}
