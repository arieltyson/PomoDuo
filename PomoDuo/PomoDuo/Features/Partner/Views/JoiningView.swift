import SwiftUI

/// Loading state while validating and joining a partner code.
struct JoiningView: View {
    var body: some View {
        VStack {
            Spacer()

            ProgressView {
                Text("Connecting to Partner…")
                    .font(.headline)
            }
            .controlSize(.large)
            .tint(AppColors.lavender)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
