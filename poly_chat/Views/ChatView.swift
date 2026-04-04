import SwiftUI
import Foundation
import PDFKit
import UniformTypeIdentifiers
import UIKit
import WebKit

struct ChatView: View {
    let conversationId: UUID
    @State private var messageText = ""
    @State private var showingConfigAlert = false
    @State private var showingUnauthorizedAlert = false
    @State private var showingUnsupportedURLAlert = false
    @State private var showingSettings = false
    @State private var lastMessageToSend = ""
    @State private var showingDocumentPicker = false
    @State private var showingDocumentPreview: (URL, String)? = nil
    @State private var showingDocumentErrorAlert = false
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage? = nil
    @State private var documentErrorMessage = ""
    @State private var editingMessage: Message? = nil
    @State private var showingNoToolsAlert = false
    @State private var showingNoAPIKeyAlert = false
    @State private var showingServerErrorAlert = false
    @State private var serverErrorMessage = ""
    @FocusState private var inputFocused: Bool
    @EnvironmentObject private var chatManager: ChatManager

    @AppStorage("darkMode") private var darkMode: Bool = false

    var conversation: Conversation? {
        chatManager.conversations.first { $0.id == conversationId }
    }

    private var webSearchOK: Bool {
        hasTavilyKey && !chatManager.tavilyKeyInvalid
    }

    private var hasTavilyKey: Bool {
        WebSearchService.shared.apiKey != nil
    }

    private var loadingBubble: some View {
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

    @ViewBuilder
    private func inputBar(for conversation: Conversation) -> some View {
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
                .disabled(chatManager.isLoading)
                .padding(.trailing, 4)

                if conversation.model.hasVision == true {
                    Button(action: { showingImagePicker = true }) {
                        Image(systemName: "photo")
                            .foregroundColor(.blue)
                    }
                    .disabled(chatManager.isLoading)
                    .padding(.trailing, 4)
                }

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
                    .disabled(chatManager.isLoading)

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
                .disabled((messageText.isEmpty && showingDocumentPreview == nil && selectedImage == nil) || chatManager.isLoading)
                .padding(.trailing, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    var body: some View {
        mainContent
            .alert("Configuration Required", isPresented: $showingConfigAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") { showingSettings = true }
            } message: {
                Text(getConfigAlertMessage())
            }
            .alert("Unauthorized - 401", isPresented: $showingUnauthorizedAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Check Settings") { showingSettings = true }
                Button("Retry") { retrySend() }
            } message: {
                Text("The server returned 401 Unauthorized. This usually means the API key is invalid or the endpoint URL is incorrect.")
            }
            .alert("Unsupported URL - 404", isPresented: $showingUnsupportedURLAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Check Settings") { showingSettings = true }
                Button("Retry") { retrySend() }
            } message: {
                Text("The URL is not supported. Please check if the endpoint URL is correct.")
            }
            .alert("Server Error", isPresented: $showingServerErrorAlert) {
                Button("Retry") { retrySend() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(serverErrorMessage)
            }
            .alert("Document Processing Error", isPresented: $showingDocumentErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(documentErrorMessage)
            }
            .alert("Web Search Unavailable", isPresented: $showingNoToolsAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This model doesn't support tool use. To search the web, switch to a model with the Tools capability.")
            }
            .alert(hasTavilyKey ? "Invalid API Key" : "Web Search API Key Missing", isPresented: $showingNoAPIKeyAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") { showingSettings = true }
            } message: {
                Text(hasTavilyKey
                    ? "The Tavily API key was rejected. Update it in Settings."
                    : "A Tavily API key is required for web search. Add one in Settings to enable this feature.")
            }
            .alert("Invalid Tavily API Key", isPresented: $chatManager.showInvalidKeyAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") { showingSettings = true }
            } message: {
                Text("Your Tavily API key was rejected. Please update it in Settings.")
            }
            .alert("Web Search Failed", isPresented: $chatManager.showWebSearchFailedAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") { showingSettings = true }
            } message: {
                Text("The web search request failed. Please check that your Tavily API key is valid in Settings.")
            }
            .alert("Web Search Credits Exhausted", isPresented: $chatManager.showOutOfCreditsAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your Tavily API credits have run out. Add more credits to your account to continue using web search.")
            }
    }

    private var mainContent: some View {
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
                        if chatManager.isLoading {
                            loadingBubble
                        }
                    }
                }

                if let errorMessage = chatManager.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                inputBar(for: conversation)

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

                if let image = selectedImage {
                    ImagePreviewView(image: image, onRemove: { selectedImage = nil })
                }
            } else {
                Text("Conversation not found")
                    .foregroundColor(.red)
            }
        }
        .navigationTitle(conversation?.title ?? "Chat")
        .onAppear {
            chatManager.errorMessage = nil
        }
        .onChange(of: chatManager.errorMessage) { newValue in
            guard newValue != nil else { return }
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await MainActor.run {
                    chatManager.errorMessage = nil
                }
            }
        }
        .onChange(of: chatManager.sendError) { error in
            guard let error else { return }
            switch error.domain {
            case "OllamaUnauthorizedError":
                showingUnauthorizedAlert = true
            case "OllamaUnsupportedURLError":
                showingUnsupportedURLAlert = true
            case "OllamaError" where error.code >= 500:
                serverErrorMessage = "The server returned an error (\(error.code)). This is likely a temporary issue — please try again."
                showingServerErrorAlert = true
            default:
                documentErrorMessage = error.localizedDescription
                showingDocumentErrorAlert = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if !webSearchOK { showingNoAPIKeyAlert = true }
                }) {
                    Image(systemName: "globe")
                        .foregroundStyle(webSearchOK ? Color.blue : Color.red)
                }
            }
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
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker { image in
                selectedImage = image
            }
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
        chatManager.startSendMessage(lastMessageToSend, in: conversation)
    }

    private func handleDocumentSelected(_ fileURL: URL) {
        Task {
            chatManager.isLoading = true
            defer { chatManager.isLoading = false }

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

    private func looksLikeWebSearch(_ text: String) -> Bool {
        let lower = text.lowercased()
        let keywords = ["search", "look up", "look it up", "google", "find online",
                        "browse", "search the web", "web search", "search online",
                        "search for", "find on the internet", "check online"]
        return keywords.contains { lower.contains($0) }
    }

    private func sendMessage() {
        if !OllamaService.isConfigured() {
            showingConfigAlert = true
            return
        }

        guard let conversation = conversation else { return }

        if looksLikeWebSearch(messageText) && conversation.model.hasTools != true {
            showingNoToolsAlert = true
            return
        }

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        if let msgToEdit = editingMessage {
            let content = messageText
            messageText = ""
            editingMessage = nil
            Task {
                do {
                    try await chatManager.updateMessage(msgToEdit.id, to: content, in: conversation)
                } catch let nsError as NSError where nsError.domain == "OllamaUnauthorizedError" {
                    showingUnauthorizedAlert = true
                } catch let nsError as NSError where nsError.domain == "OllamaUnsupportedURLError" {
                    showingUnsupportedURLAlert = true
                } catch let nsError as NSError where nsError.domain == "OllamaError" && nsError.code >= 500 {
                    serverErrorMessage = "The server returned an error (\(nsError.code)). This is likely a temporary issue — please try again."
                    showingServerErrorAlert = true
                } catch {
                    documentErrorMessage = error.localizedDescription
                    showingDocumentErrorAlert = true
                }
            }
            return
        }

        lastMessageToSend = messageText
        messageText = ""

        let fileURL = showingDocumentPreview?.0
        let image = selectedImage
        selectedImage = nil

        chatManager.startSendMessage(
            lastMessageToSend,
            in: conversation,
            fileURL: fileURL,
            image: image,
            onSuccess: {
                if let url = fileURL {
                    try? FileManager.default.removeItem(at: url)
                }
                showingDocumentPreview = nil
            }
        )
    }
}

struct ThinkingDisclosureView: View {
    let thinking: String
    @State private var isExpanded: Bool = false
    @State private var thinkingHeight: CGFloat = 1
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("showThinkingTraces") private var showThinkingTraces = true

    var body: some View {
        if showThinkingTraces {
            VStack(alignment: .leading, spacing: 4) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.purple)
                        Text(isExpanded ? "Hide thinking" : "Show thinking")
                            .font(.caption)
                            .foregroundColor(.purple)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.purple.opacity(0.7))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.purple.opacity(0.4))
                            .frame(width: 3)
                        MarkdownWebView(
                            markdown: thinking,
                            isDarkMode: colorScheme == .dark,
                            calculatedHeight: $thinkingHeight
                        )
                        .frame(height: max(thinkingHeight, 20))
                        .padding(.leading, 10)
                        .padding(.vertical, 6)
                    }
                    .background(Color.purple.opacity(0.05))
                    .cornerRadius(8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
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
                if let thinking = message.thinkingContent, message.role == .assistant {
                    ThinkingDisclosureView(thinking: thinking)
                        .frame(maxWidth: bubbleWidth(), alignment: .leading)
                }

                if let attachment = message.documentAttachment {
                    DocumentAttachmentView(attachment: attachment)
                        .padding(.bottom, 4)
                }

                if let imageAttachment = message.imageAttachment,
                   let imageData = Data(base64Encoded: imageAttachment.base64Data),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 180, height: 180)
                        .clipped()
                        .cornerRadius(10)
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

struct ImagePreviewView: View {
    let image: UIImage
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 10) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipped()
                    .cornerRadius(8)
                Text("Image attached")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
