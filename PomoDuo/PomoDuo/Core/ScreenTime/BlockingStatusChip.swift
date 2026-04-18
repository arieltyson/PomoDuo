import SwiftUI

/// Unified "blocking active" chip used by solo Focus and paired sessions.
///
/// ### Why a single chip for both healthy and degraded
/// ``ScreenTimeRuntimeHealth`` still tracks ``.healthy`` vs ``.degraded``
/// internally so the focus-session entry and foreground hooks can decide
/// whether a full-pipeline reconcile is worth running. The end-user chip,
/// however, collapses both into one presentation: "Blocking Active".
///
/// Engineer-facing diagnostics (including the "Repairing" wording that
/// used to surface to users) now live behind the `#if DEBUG` App Blocking
/// Diagnostics screen. Showing "Repairing" on the Focus screen leaked an
/// internal reconcile state to end users without giving them anything
/// actionable — the app self-heals, and a transient degraded classification
/// is not something the user needs to read during a focus session.
///
/// ### Visibility contract
/// * ``ScreenTimeRuntimeHealth/healthy`` — renders the chip.
/// * ``ScreenTimeRuntimeHealth/degraded`` — renders the same chip; the
///   app's reconcile pipeline continues to run underneath.
/// * ``ScreenTimeRuntimeHealth/unavailable`` — renders nothing. Claiming
///   "Blocking Active" when the runtime classifies as unavailable would
///   overclaim a state the app cannot honor.
///
/// Call sites should additionally gate on their own "is shielding
/// requested right now?" signal (for example
/// `RestrictionCoordinator.isRestricting`) before handing a health value
/// in, so the chip is never rendered outside an active focus intent.
struct BlockingStatusChip: View {
    let health: ScreenTimeRuntimeHealth

    var body: some View {
        if health.isRequestable {
            Label(Self.title, systemImage: Self.symbol)
                .font(.caption2)
                .foregroundStyle(AppColors.lavender)
                .padding(.horizontal, Self.horizontalPadding)
                .padding(.vertical, Self.verticalPadding)
                .background(
                    AppColors.lavender.opacity(Self.backgroundOpacity),
                    in: .capsule
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.accessibilityLabel)
                .transition(.opacity)
        }
    }

    // MARK: - Chip content

    /// Honest, calm copy — describes what the app *has requested*, not
    /// what the OS is guaranteed to be enforcing (Apple does not expose
    /// an "is shielding effective right now?" signal).
    private static let title: LocalizedStringResource = "Blocking Active"
    private static let symbol = "shield.fill"
    private static let accessibilityLabel: LocalizedStringResource =
        "App blocking active for this focus session."

    // MARK: - Chip metrics
    //
    // Named so the visual identity lives in one spot; both the solo
    // Focus screen and the paired-session view read these constants
    // through this component, so tuning the chip no longer means
    // touching two files.

    private static let horizontalPadding: CGFloat = 10
    private static let verticalPadding: CGFloat = 4
    private static let backgroundOpacity: Double = 0.14
}
