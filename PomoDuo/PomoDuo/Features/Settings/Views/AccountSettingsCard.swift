import SwiftUI

/// Shared elevated surface used for editable and read-only account details.
struct AccountSettingsCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AppColors.lavender.opacity(0.14), lineWidth: 1)
        }
        .listRowInsets(
            EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
        )
        .listRowBackground(Color.clear)
    }
}
