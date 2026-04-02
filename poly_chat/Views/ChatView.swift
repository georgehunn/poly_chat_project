import SwiftUI
import Foundation
import PDFKit
import UniformTypeIdentifiers
import UIKit
import WebKit

struct ChatView: View {
    let conversationId: UUID
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var showingConfigAlert = false
    @State private var showingUnauthorizedAlert = false
    @State private var showingUnsupportedURLAlert = false
    @State private var showingSettings = false
    @State private var lastMessageToSend = ""
    @State private var showingDocumentPicker = false
    @State private var showingDocumentPreview: (URL, String)? = nil
    @State private var showingDocumentErrorAlert = false
    @State private var documentErrorMessage = ""
    @State private var editingMessage: Message? = nil
    @FocusState private var inputFocused: Bool
    @EnvironmentObject private var chatManager: ChatManager

    @AppStorage("darkMode") private var darkMode: Bool = false

    var conversation: Conversation? {
        chatManager.conversations.first { $0.id == conversationId }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let conversation = conversation {
                HStack {
                    Text("Model: \(conversation.model.displayName) (\(conversation.model.provider))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)

                ScrollView {
                    LazyVStack {
                        ForEach(conversation.messages) { message in
                            if message.role != .system {
                                MessageView(message: message, conversation: conversation) { msg, displayText in
                                    editingMessage = msg
                                    messageText = displayText
                                    inputFocused = true
                                }
                            }
                        }

                        if isLoading || chatManager.isLoading {
                            HStack {
                                Spacer()
                                HStack(spacing: 8) {
                                    if let toolName = chatManager.activeToolName {
                                        Image(systemName: toolIcon(for: toolName))
                                            .foregroundColor(.blue)
                                    } else {
                                        ProgressView()
                                    }
                                    Text(loadingLabel)
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(20)
                                Spacer()
                            }
                            .animation(.easeInOut(duration: 0.2), value: chatManager.activeToolName)
                        }
                    }
                }

                if let errorMessage = chatManager.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                VStack(spacing: 0) {
                    if editingMessage != nil {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("Editing message")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                editingMessage = nil
                                messageText = ""
                            }) {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }

                    HStack {
                        Button(action: { showingDocumentPicker = true }) {
                            Image(systemName: "paperclip")
                                .foregroundColor(.blue)
                        }
                        .disabled(isLoading)
                        .padding(.trailing, 4)

                        TextField("Message", text: $messageText, axis: .vertical)
                            .focused($inputFocused)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .disabled(isLoading)

                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled((messageText.isEmpty && showingDocumentPreview == nil) || isLoading)
                        .padding(.trailing, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .background(Color(.systemGroupedBackground))

                if let (fileURL, fileName) = showingDocumentPreview {
                    DocumentPreviewView(
                        fileURL: fileURL,
                        fileName: fileName,
                        onRemove: {
                            if let (fileURL, _) = showingDocumentPreview {
                                try? FileManager.default.removeItem(at: fileURL)
                            }
                            showingDocumentPreview = nil
                        }
                    )
                }
            } else {
                Text("Conversation not found")
                    .foregroundColor(.red)
            }
        }
        .navigationTitle(conversation?.title ?? "Chat")
        .alert("Configuration Required", isPresented: $showingConfigAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                showingSettings = true
            }
        } message: {
            Text(getConfigAlertMessage())
        }
        .alert("Unauthorized - 401", isPresented: $showingUnauthorizedAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Check Settings") {
                showingSettings = true
            }
            Button("Retry") {
                retrySend()
            }
        } message: {
            Text("The server returned 401 Unauthorized. This usually means the API key is invalid or the endpoint URL is incorrect.")
        }
        .alert("Unsupported URL - 404", isPresented: $showingUnsupportedURLAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Check Settings") {
                showingSettings = true
            }
            Button("Retry") {
                retrySend()
            }
        } message: {
            Text("The URL is not supported. Please check if the endpoint URL is correct.")
        }
        .alert("Document Processing Error", isPresented: $showingDocumentErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(documentErrorMessage)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(
                onDocumentSelected: handleDocumentSelected,
                fileTypes: [.pdf]
            )
        }
    }

    private var loadingLabel: String {
        switch chatManager.activeToolName {
        case "get_current_date": return "Checking the date…"
        case "web_search": return "Searching the web…"
        case let name? where !name.isEmpty: return "Using \(name)…"
        default: return "Thinking…"
        }
    }

    private func toolIcon(for name: String) -> String {
        switch name {
        case "get_current_date": return "calendar"
        case "web_search": return "globe"
        default: return "wrench.and.screwdriver"
        }
    }

    private func retrySend() {
        guard let conversation = conversation else { return }
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                _ = try await chatManager.sendMessage(lastMessageToSend, in: conversation)
            } catch {
                print("Retry error: \(error)")
            }
        }
    }

    private func handleDocumentSelected(_ fileURL: URL) {
        Task {
            isLoading = true
            defer { isLoading = false }

            guard fileURL.startAccessingSecurityScopedResource() else { return }
            defer { fileURL.stopAccessingSecurityScopedResource() }

            do {
                let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let docsURL = documentsDir.appendingPathComponent(fileURL.lastPathComponent)

                if FileManager.default.fileExists(atPath: docsURL.path) {
                    try? FileManager.default.removeItem(at: docsURL)
                }

                try FileManager.default.copyItem(at: fileURL, to: docsURL)

                let attachment = try await PDFDocumentService.shared.processPDF(from: docsURL)
                showingDocumentPreview = (docsURL, attachment.filename)
            } catch {
                documentErrorMessage = error.localizedDescription
                showingDocumentErrorAlert = true
            }
        }
    }

    private func getConfigAlertMessage() -> String {
        OllamaService.getConfigStatusMessage()
    }

    private func checkAndShowConfigPopup() {
        let secureStorage = SecureStorageService()
        if let endpoint = secureStorage.getEndpoint(), !endpoint.isEmpty {
            showingConfigAlert = false
        } else {
            showingConfigAlert = false
        }
    }

    private func sendMessage() {
        if !OllamaService.isConfigured() {
            showingConfigAlert = true
            return
        }

        guard let conversation = conversation else { return }

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        if let msgToEdit = editingMessage {
            let content = messageText
            messageText = ""
            editingMessage = nil
            Task {
                isLoading = true
                defer { isLoading = false }
                do {
                    try await chatManager.updateMessage(msgToEdit.id, to: content, in: conversation)
                } catch {
                    documentErrorMessage = error.localizedDescription
                    showingDocumentErrorAlert = true
                }
            }
            return
        }

        lastMessageToSend = messageText
        messageText = ""

        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                if let (fileURL, _) = showingDocumentPreview {
                    _ = try await chatManager.sendMessage(lastMessageToSend, in: conversation, withPDFAt: fileURL)
                    try? FileManager.default.removeItem(at: fileURL)
                    showingDocumentPreview = nil
                } else {
                    _ = try await chatManager.sendMessage(lastMessageToSend, in: conversation)
                }
            } catch {
                documentErrorMessage = error.localizedDescription
                showingDocumentErrorAlert = true
            }
        }
    }
}

struct MessageView: View {
    let message: Message
    let conversation: Conversation
    let onEdit: (Message, String) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var chatManager: ChatManager
    @State private var messageHeight: CGFloat = 1

    private func bubbleWidth() -> CGFloat {
        let screen = UIScreen.main.bounds.width

        if message.role == .user {
            return screen * 0.62
        } else {
            return screen * 0.92
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Message content area
            HStack(alignment: .bottom, spacing: 0) {
                if message.role == .user {
                    Spacer(minLength: 32)
                }

                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if let attachment = message.documentAttachment {
                    DocumentAttachmentView(attachment: attachment)
                        .padding(.bottom, 4)
                }

                if message.role == .assistant || hasContentToShow(message.content) {
                    if shouldUseNativeText(getDisplayContent(message.content)) {
                        Text(getDisplayContent(message.content))
                            .font(.system(size: 17))
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(12)
                            .background(message.role == .user ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                            .cornerRadius(10)
                            .contextMenu {
                                Button(action: copyMessage) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                if message.role == .user {
                                    Button(action: startEditing) {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                }
                            } preview: {
                                Text(getDisplayContent(message.content))
                                    .font(.system(size: 17))
                                    .lineSpacing(4)
                                    .foregroundColor(.primary)
                                    .padding(12)
                                    .background(message.role == .user ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .frame(maxWidth: bubbleWidth(), alignment: message.role == .user ? .trailing : .leading)
                    } else {
                        MarkdownWebView(
                            markdown: getDisplayContent(message.content),
                            isDarkMode: colorScheme == .dark,
                            calculatedHeight: $messageHeight
                        )
                        .frame(maxWidth: bubbleWidth(), alignment: .leading)
                        .frame(height: max(messageHeight, 20))
                        .padding(12)
                        .background(message.role == .user ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .contextMenu {
                            Button(action: copyMessage) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            if message.role == .user {
                                Button(action: startEditing) {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }
                        } preview: {
                            Text(getDisplayContent(message.content))
                                .font(.system(size: 17))
                                .foregroundColor(.primary)
                                .padding(12)
                                .background(message.role == .user ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .frame(maxWidth: bubbleWidth(), alignment: message.role == .user ? .trailing : .leading)
                    }
                }

                Text(formatDate(message.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: bubbleWidth(), alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer(minLength: 32)
            }
        }
        .padding(.horizontal)
    }
    }

    private func shouldUseNativeText(_ content: String) -> Bool {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.isEmpty { return true }

        let richMarkdownPatterns = [
            "```",          // code fences
            "|---",         // tables
            "\n|",          // tables
            "$$",           // block math
            "\\[",          // latex block
            "\\(",          // latex inline
            "# ",           // headings
            "## ",
            "### ",
            "- ",           // lists
            "* ",
            "1. ",
            "> ",           // blockquote
            "---",          // horizontal rule
            "`"             // inline code
        ]

        return !richMarkdownPatterns.contains { text.contains($0) }
    }

    private func copyMessage() {
        UIPasteboard.general.string = message.content
    }

    private func hasContentToShow(_ content: String) -> Bool {
        let markerStart = "--- Attached Document:"

        guard content.contains(markerStart) else {
            return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if let markerRange = content.range(of: markerStart) {
            let textBeforeMarker = String(content[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            return !textBeforeMarker.isEmpty
        }

        return false
    }

    private func getDisplayContent(_ content: String) -> String {
        guard content.contains("--- Attached Document:") else {
            return content
        }

        if let markerRange = content.range(of: "--- Attached Document:") {
            let textBeforeMarker = String(content[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            return textBeforeMarker
        }

        return content
    }

    private func startEditing() {
        guard message.role == .user else { return }
        onEdit(message, getDisplayContent(message.content))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DocumentAttachmentView: View {
    let attachment: DocumentAttachment

    var body: some View {
        HStack {
            Image(systemName: "doc.text.fill")
                .foregroundColor(.blue)
            Text(attachment.filename)
                .font(.footnote)
                .foregroundColor(.blue)
            Spacer()
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct DocumentPreviewView: View {
    let fileURL: URL
    let fileName: String
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "doc.text.fill")
                Text(fileName)
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            Divider()
        }
        .padding()
    }
}
