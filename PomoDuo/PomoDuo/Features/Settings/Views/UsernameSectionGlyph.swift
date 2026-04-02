import SwiftUI

struct UsernameSectionGlyph: View {
    var body: some View {
        Image(systemName: "at")
            .font(.title3.weight(.semibold))
            .foregroundStyle(AppColors.lavender)
            .frame(width: 44, height: 44)
            .background(
                AppColors.paleViolet.opacity(0.22),
                in: .circle
            )
            .accessibilityHidden(true)
    }
}
