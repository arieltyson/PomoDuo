import SwiftUI

/// Compact status capsule shown when the device is offline.
///
/// Animates in/out based on ``ConnectionMonitor/isConnected`` and
/// provides a clear, non-alarming signal that real-time partner sync
/// is unavailable. Styled as a material capsule to integrate with the
/// app's glass/material design language rather than a flat alert bar.
struct ConnectionStatusBanner: View {
    @Environment(ConnectionMonitor.self) private var connectionMonitor

    var body: some View {
        if !connectionMonitor.isConnected {
            HStack(spacing: 6) {
                Image(systemName: "wifi.slash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.pauseTint)

                Text("Offline — partner sync paused")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial, in: .capsule)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityLabel("Offline, partner sync paused")
        }
    }
}
