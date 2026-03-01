import SwiftUI

/// A brief branded moment shown while the app initializes.
///
/// Displays the PomoDuo logo mark and name with a subtle ring animation,
/// then dissolves to reveal the content underneath. The entire sequence
/// completes in under one second — long enough to feel intentional,
/// short enough to respect the user's time.
///
/// Apple HIG: "Design a launch experience that gets people into your
/// app quickly… avoid showing an explicit splash screen."
/// This isn't a splash screen — it's a transition that masks the
/// real initialization work (Firebase, anonymous auth).
struct LaunchAnimationView: View {
    @State private var ringScale: CGFloat = 0.7
    @State private var ringOpacity: Double = 0
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Called when the animation completes and the view is ready to dismiss.
    var onFinished: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    // Animated progress ring.
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    AppColors.lavender,
                                    AppColors.lilac,
                                    AppColors.lavender,
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // App icon.
                    Image(systemName: "brain.head.profile")
                        .font(.largeTitle)
                        .foregroundStyle(AppColors.lavender)
                        .opacity(iconOpacity)
                }

                Text("PomoDuo")
                    .font(.system(.title3, design: .rounded))
                    .bold()
                    .foregroundStyle(AppColors.lavender)
                    .opacity(textOpacity)
            }
        }
        .task {
            if reduceMotion {
                // Skip animation; show brand briefly then dismiss.
                ringScale = 1.0
                ringOpacity = 1.0
                iconOpacity = 1.0
                textOpacity = 1.0
                try? await Task.sleep(for: .milliseconds(400))
                onFinished()
                return
            }

            // Staggered entrance — each element fades in quickly.
            withAnimation(.easeOut(duration: 0.3)) {
                ringScale = 1.0
                ringOpacity = 1.0
            }

            try? await Task.sleep(for: .milliseconds(100))

            withAnimation(.easeOut(duration: 0.25)) {
                iconOpacity = 1.0
            }

            try? await Task.sleep(for: .milliseconds(100))

            withAnimation(.easeOut(duration: 0.25)) {
                textOpacity = 1.0
            }

            // Hold for a beat so the brand registers.
            try? await Task.sleep(for: .milliseconds(350))

            onFinished()
        }
        .accessibilityHidden(true)
    }
}
