import SwiftUI

struct UsernameSection: View {
    let username: String?
    let isFetching: Bool
    let onSetup: () -> Void

    var body: some View {
        Section {
            if isFetching {
                AccountSettingsCard {
                    HStack(spacing: 14) {
                        UsernameSectionGlyph()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Loading username")
                                .font(.headline)

                            Text("Checking how friends can find you.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        ProgressView()
                            .controlSize(.small)
                    }
                }
            } else if let username {
                AccountSettingsCard {
                    HStack(spacing: 14) {
                        UsernameSectionGlyph()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("@\(username)")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppColors.lavender)

                            Text("Friends can find and add you with this username.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "@\(username). Friends can find and add you with this username."
                    )
                }
            } else {
                Button(action: onSetup) {
                    AccountSettingsCard {
                        HStack(spacing: 14) {
                            UsernameSectionGlyph()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Choose a username")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text("Required for finding and adding friends on PomoDuo.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens username setup.")
            }
        } header: {
            Text("Username")
        } footer: {
            if username != nil {
                Text("Friends find you by this username. It cannot be changed.")
            } else {
                Text("A username lets friends discover and add you on PomoDuo.")
            }
        }
    }
}
