import SwiftUI

/// Compact banner shown at the top of views when the device is offline.
///
/// Animates in/out based on ``ConnectionMonitor/isConnected`` and
/// provides a clear signal that real-time partner sync is unavailable.
struct ConnectionStatusBanner: View {
    @Environment(ConnectionMonitor.self) private var connectionMonitor

    var body: some View {
        if !connectionMonitor.isConnected {
            Label("Offline — partner sync paused", systemImage: "wifi.slash")
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(.orange.gradient, in: .rect(cornerRadius: 8))
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}
