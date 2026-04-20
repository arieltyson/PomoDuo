import SwiftUI

/// Bottom-safe timer control container with a stable, animated blocking state.
struct TimerControlDock<Controls: View>: View {
    let isBlockingActive: Bool
    @ViewBuilder let controls: () -> Controls

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isStatusPresented = false

    private var statusHeight: CGFloat {
        isStatusPresented ? TimerBlockingStatusChip.metrics.height : 0
    }

    private var statusSpacing: CGFloat {
        isStatusPresented ? TimerBlockingStatusChip.metrics.spacing : 0
    }

    private var statusAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.34)
    }

    var body: some View {
        VStack(spacing: statusSpacing) {
            controls()

            TimerBlockingStatusChip(isPresented: isStatusPresented)
                .frame(height: statusHeight, alignment: .top)
                .clipped()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .animation(statusAnimation, value: isStatusPresented)
        .onAppear {
            isStatusPresented = isBlockingActive
        }
        .onChange(of: isBlockingActive) { _, isActive in
            let animation = statusAnimation?.delay(isActive ? 0.08 : 0)

            withAnimation(animation) {
                isStatusPresented = isActive
            }
        }
    }
}
