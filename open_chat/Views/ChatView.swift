import SwiftUI
import Foundation
import PDFKit
import UniformTypeIdentifiers
import UIKit

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
    @EnvironmentObject private var chatManager: ChatManager

    var conversation: Conversation? {
        chatManager.conversations.first { $0.id == conversationId }
    }

    var body: some View {
        VStack {
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
                                MessageView(message: message)
                            }
                        }

                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                        }
                    }
                }

                if let errorMessage = chatManager.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                HStack {
                    Button(action: { showingDocumentPicker = true }) {
                        Image(systemName: "paperclip")
                            .foregroundColor(.blue)
                    }
                    .disabled(isLoading)
                    .padding(.trailing, 4)

                    TextField("Message", text: $messageText, axis: .vertical)
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
                .padding(.bottom, 20)
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
        // Only show popup if endpoint is not configured at all
        let secureStorage = SecureStorageService()
        if let endpoint = secureStorage.getEndpoint(), !endpoint.isEmpty {
            // Endpoint exists, don't show popup
            showingConfigAlert = false
        } else {
            // No endpoint configured, show popup instead of alert
            showingConfigAlert = false
            // Popup will be shown via ContentView
        }
    }

    private func sendMessage() {
        if !OllamaService.isConfigured() {
            showingConfigAlert = true
            return
        }

        guard let conversation = conversation else { return }

        lastMessageToSend = messageText
        messageText = ""

        // Explicitly dismiss keyboard when sending message
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

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

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            VStack(alignment: message.role == .user ? .trailing : .leading) {
                // Show document preview if attached
                if let attachment = message.documentAttachment {
                    DocumentAttachmentView(attachment: attachment)
                        .padding(.bottom, 4)
                }

                // Only show content if it has actual text (not just document marker)
                if message.role == .assistant || hasContentToShow(message.content) {
                    MarkdownText(markdown: getDisplayContent(message.content))
                        .padding()
                        .background(message.role == .user ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }

                Text(formatDate(message.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if message.role == .assistant { Spacer() }
        }
        .padding(.horizontal)
    }

    private func hasContentToShow(_ content: String) -> Bool {
        // Remove the document marker to check if there's actual content
        let markerStart = "--- Attached Document:"

        // If no marker, check if content is not empty
        guard content.contains(markerStart) else {
            return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        // Has marker - extract text before the marker
        if let markerRange = content.range(of: markerStart) {
            // Use ..< to exclude the marker start from the text
            let textBeforeMarker = String(content[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            // Show content only if there's actual text before the marker
            return !textBeforeMarker.isEmpty
        }

        return false
    }

    private func getDisplayContent(_ content: String) -> String {
        // If no document attachment, return as-is
        guard content.contains("--- Attached Document:") else {
            return content
        }

        // Extract text before the document marker
        if let markerRange = content.range(of: "--- Attached Document:") {
            // Get everything before the marker (use ..< to exclude the marker start)
            let textBeforeMarker = String(content[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            return textBeforeMarker
        }

        return content
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

struct MarkdownText: View {
    let markdown: String

    var body: some View {
        Text(markdown)
    }
}