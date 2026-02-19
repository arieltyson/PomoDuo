import SwiftUI

// MARK: - Pause Breathing

/// Gentle pulsing treatment used while a timer is paused.
///
/// The pulse communicates "waiting" without reading as an error state.
struct PauseBreathingEffect: ViewModifier {
    let isActive: Bool

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive && isExpanded ? 1.03 : 1)
            .opacity(isActive ? (isExpanded ? 0.72 : 0.9) : 1)
            .onAppear {
                refreshAnimationState()
            }
            .onChange(of: isActive) { _, _ in
                refreshAnimationState()
            }
            .onChange(of: reduceMotion) { _, _ in
                refreshAnimationState()
            }
    }

    private func refreshAnimationState() {
        guard isActive, !reduceMotion else {
            withAnimation(.easeOut(duration: 0.2)) {
                isExpanded = false
            }
            return
        }

        withAnimation(
            .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
        ) {
            isExpanded = true
        }
    }
}

extension View {
    /// Applies a calm breathing pulse while paused.
    func pauseBreathing(isPaused: Bool) -> some View {
        modifier(PauseBreathingEffect(isActive: isPaused))
    }
}

// MARK: - Resume Glow

/// Expanding glow that fires on pause -> resume transitions.
struct ResumeGlowOverlay: View {
    let color: Color
    let trigger: Bool

    @State private var glowScale: CGFloat = 0.88
    @State private var glowOpacity = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(color.opacity(0.24))
            .scaleEffect(glowScale)
            .opacity(glowOpacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: trigger) { wasPaused, isPaused in
                guard wasPaused, !isPaused, !reduceMotion else { return }
                flash()
            }
    }

    private func flash() {
        withAnimation(.none) {
            glowScale = 0.88
            glowOpacity = 0.66
        }

        withAnimation(.easeOut(duration: 0.42)) {
            glowScale = 1.34
            glowOpacity = 0
        }
    }
}

// MARK: - Celebration Particles

/// Small particle burst used for round/session completion moments.
struct CelebrationParticlesView: View {
    let isActive: Bool
    let color: Color

    @State private var particles: [CelebrationParticle] = []
    @State private var cleanupTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(
                        x: cos(particle.angle) * particle.distance,
                        y: sin(particle.angle) * particle.distance
                    )
                    .opacity(particle.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: isActive) { wasActive, isNowActive in
            guard isNowActive, !wasActive, !reduceMotion else { return }
            emitBurst()
        }
        .onDisappear {
            cleanupTask?.cancel()
            cleanupTask = nil
        }
    }

    private func emitBurst() {
        cleanupTask?.cancel()

        let palette: [Color] = [
            color,
            color.opacity(0.75),
            .orange.opacity(0.75),
            .yellow.opacity(0.65),
        ]

        particles = (0..<12).map { index in
            let baseAngle = Double(index) * (.pi * 2 / 12)
            let jitter = Double.random(in: -0.28...0.28)

            return CelebrationParticle(
                id: UUID(),
                color: palette[index % palette.count],
                size: .random(in: 4...8),
                angle: baseAngle + jitter,
                distance: 0,
                opacity: 1
            )
        }

        for index in particles.indices {
            let travel = CGFloat.random(in: 64...122)
            let delay = Double.random(in: 0...0.12)

            withAnimation(
                .timingCurve(0.2, 0.9, 0.2, 1, duration: 0.65)
                    .delay(delay)
            ) {
                particles[index].distance = travel
                particles[index].opacity = 0
            }
        }

        cleanupTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            particles.removeAll()
        }
    }
}

private struct CelebrationParticle: Identifiable {
    let id: UUID
    let color: Color
    let size: CGFloat
    let angle: Double
    var distance: CGFloat
    var opacity: Double
}

// MARK: - Phase Transition

/// Animated replacement transition keyed by a phase label.
struct PhaseTransitionModifier: ViewModifier {
    let phase: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ZStack {
            content
                .id(phase)
                .transition(transition)
        }
        .animation(animation, value: phase)
    }

    private var transition: AnyTransition {
        if reduceMotion {
            return .opacity
        }

        return .asymmetric(
            insertion: .move(edge: .bottom)
                .combined(with: .scale(scale: 0.92))
                .combined(with: .opacity),
            removal: .opacity
        )
    }

    private var animation: Animation? {
        reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.3)
    }
}

extension View {
    /// Applies a spring phase transition keyed by `phase`.
    func phaseTransition(phase: String) -> some View {
        modifier(PhaseTransitionModifier(phase: phase))
    }
}

// MARK: - Round Completion Pop

/// Bounce + expanding ring used when a round transitions to completed.
struct RoundCompletionPop: ViewModifier {
    let isCompleted: Bool

    @State private var scale: CGFloat = 1
    @State private var ringProgress: CGFloat = 1
    @State private var resetTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .overlay {
                Circle()
                    .stroke(AppColors.lavender.opacity(0.35), lineWidth: 2)
                    .scaleEffect(1 + (ringProgress * 0.9))
                    .opacity(1 - ringProgress)
                    .allowsHitTesting(false)
            }
            .onAppear {
                if !isCompleted {
                    scale = 1
                    ringProgress = 1
                }
            }
            .onChange(of: isCompleted) { wasCompleted, isNowCompleted in
                guard isNowCompleted, !wasCompleted else { return }
                guard !reduceMotion else {
                    scale = 1
                    ringProgress = 1
                    return
                }
                pop()
            }
            .onDisappear {
                resetTask?.cancel()
                resetTask = nil
            }
    }

    private func pop() {
        resetTask?.cancel()

        withAnimation(.none) {
            scale = 1
            ringProgress = 0
        }

        withAnimation(.spring(duration: 0.24, bounce: 0.62)) {
            scale = 1.2
        }

        withAnimation(.easeOut(duration: 0.45)) {
            ringProgress = 1
        }

        resetTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(duration: 0.28, bounce: 0.28)) {
                scale = 1
            }
        }
    }
}

extension View {
    /// Applies a completion pop effect whenever `isCompleted` flips true.
    func roundCompletionPop(isCompleted: Bool) -> some View {
        modifier(RoundCompletionPop(isCompleted: isCompleted))
    }
}
