import SwiftUI

struct AnalyticsSettingsSection: View {
    @AppStorage("analyticsEnabled") private var analyticsEnabled = true

    var body: some View {
        Section(header: Text("Usage Analytics")) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Community Usage Statistics")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("When enabled, Poly Chat collects anonymous usage statistics to understand which models are most popular across the community. This helps prioritize development.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("What IS collected:")
                        .font(.caption).fontWeight(.semibold)
                        .padding(.top, 4)
                    Group {
                        Text("\u{2022} Which model and provider you use per message")
                        Text("\u{2022} Message role (user, assistant, or tool)")
                        Text("\u{2022} Which tool was used (e.g. web search)")
                        Text("\u{2022} Attachment type (e.g. PDF, image) — not content")
                        Text("\u{2022} Error types and counts (not details)")
                        Text("\u{2022} A random device ID (not linked to you)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("What is NEVER collected:")
                        .font(.caption).fontWeight(.semibold)
                        .padding(.top, 4)
                    Group {
                        Text("\u{2022} Message content or conversation text")
                        Text("\u{2022} API keys or passwords")
                        Text("\u{2022} Your name, email, or any personal info")
                        Text("\u{2022} IP address or location")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Link(destination: URL(string: "https://github.com/georgehunn/poly_chat_project")!) {
                    Label("No personal data is ever collected. Review the analytics code on GitHub.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 4)

            Toggle("Enable anonymous analytics", isOn: $analyticsEnabled)
        }
    }
}
