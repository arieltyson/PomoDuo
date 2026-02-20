import SwiftUI

/// Category-specific guidance shown at the top of feedback forms.
struct FeedbackHeaderView: View {
    let category: FeedbackCategory

    var body: some View {
        HStack {
            Image(systemName: category.systemImageName)
                .font(.title2)
                .foregroundStyle(category.tintColor)
                .frame(width: 40, height: 40)
                .background(category.tintColor.opacity(0.15), in: .circle)
                .accessibilityHidden(true)

            Text(category.prompt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
