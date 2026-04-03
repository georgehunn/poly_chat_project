import SwiftUI
import UIKit

struct ExportConversationsView: View {
    let conversations: [Conversation]
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Group {
                if conversations.isEmpty {
                    Text("No conversations to export.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(conversations) { conversation in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(conversation.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text("\(conversation.model.displayName) · \(userMessageCount(conversation)) messages")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(conversation.updatedAt, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                exportConversation(conversation)
                            } label: {
                                Image(systemName: "arrow.down.circle")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Export Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }

    private func userMessageCount(_ conversation: Conversation) -> Int {
        conversation.messages.filter { $0.role != .system }.count
    }

    private func exportConversation(_ conversation: Conversation) {
        let text = formatConversation(conversation)
        let filename = sanitizeFilename(conversation.title) + ".txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            presentShareSheet(for: url)
        } catch {
            print("Export error: \(error)")
        }
    }

    private func presentShareSheet(for url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first,
            let rootVC = window.rootViewController
        else { return }

        // Walk to the topmost presented view controller to avoid nested-sheet issues
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        // Required for iPad: set source so the popover has an anchor
        activityVC.popoverPresentationController?.sourceView = topVC.view
        activityVC.popoverPresentationController?.sourceRect = CGRect(
            x: topVC.view.bounds.midX,
            y: topVC.view.bounds.midY,
            width: 0, height: 0
        )
        activityVC.popoverPresentationController?.permittedArrowDirections = []

        topVC.present(activityVC, animated: true)
    }

    private func formatConversation(_ conversation: Conversation) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short

        var lines: [String] = []
        lines.append("=== \(conversation.title) ===")
        lines.append("Model: \(conversation.model.displayName) (\(conversation.model.provider))")
        lines.append("Created: \(fmt.string(from: conversation.createdAt))")
        lines.append("Updated: \(fmt.string(from: conversation.updatedAt))")
        lines.append(String(repeating: "─", count: 40))
        lines.append("")

        for message in conversation.messages where message.role != .system {
            let label = message.role == .user ? "You" : "Assistant"
            lines.append("[\(label)]  \(fmt.string(from: message.timestamp))")
            lines.append(message.content)
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func sanitizeFilename(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitized = title.components(separatedBy: invalid).joined(separator: "_")
        return sanitized.isEmpty ? "conversation" : sanitized
    }
}
