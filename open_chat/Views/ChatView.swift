import SwiftUI
import Foundation

struct ChatView: View {
    let conversationId: UUID
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var showingConfigAlert = false
    @State private var showingUnauthorizedAlert = false
    @State private var showingUnsupportedURLAlert = false
    @State private var showingSettings = false
    @State private var lastMessageToSend = ""
    @EnvironmentObject private var chatManager: ChatManager

    var conversation: Conversation? {
        chatManager.conversations.first { $0.id == conversationId }
    }

    var body: some View {
        VStack {
            if let conversation = conversation {
                // Display model information
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

                Divider()

                if let errorMessage = chatManager.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                HStack {
                    TextField("Message", text: $messageText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isLoading)

                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.blue)
                    }
                    .disabled(messageText.isEmpty || isLoading)
                }
                .padding()
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
                if let conversation = conversation {
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
                if let conversation = conversation {
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
            }
        } message: {
            Text("The URL is not supported. Please check if the endpoint URL is correct and points to a valid Ollama server.")
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private func getConfigAlertMessage() -> String {
        return OllamaService.getConfigStatusMessage()
    }

    private func sendMessage() {
        // Check if URL is configured before sending message
        if !OllamaService.isConfigured() {
            showingConfigAlert = true
            return
        }

        guard !messageText.isEmpty, let conversation = conversation else { return }

        // Save the message for potential retries
        lastMessageToSend = messageText
        messageText = "" // Clear the text field immediately

        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                _ = try await chatManager.sendMessage(lastMessageToSend, in: conversation)
            } catch {
                print("Error sending message: \(error)")

                // Check for specific error types and show appropriate alerts
                let nsError = error as NSError
                let errorDomain = nsError.domain
                let errorCode = nsError.code

                print("Error domain: \(errorDomain), code: \(errorCode)")

                if errorDomain == "OllamaUnauthorizedError" && errorCode == 401 {
                    showingUnauthorizedAlert = true
                } else if errorDomain == "OllamaUnsupportedURLError" && errorCode == 404 {
                    showingUnsupportedURLAlert = true
                } else {
                    // Generic error - already handled by chatManager
                }
            }
        }
    }
}

struct MessageView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 0) {
                MarkdownText(markdown: message.content)
                    .padding()
                    .background(message.role == .user ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .foregroundColor(message.role == .user ? .primary : .primary)
                    .contextMenu {
                        Button(action: copyMessage) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }

                Text(formatDate(message.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            .transition(.opacity.combined(with: .scale))

            if message.role == .assistant {
                Spacer()
            }
        }
        .padding(.horizontal)
    }

    private func copyMessage() {
        UIPasteboard.general.string = message.content
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}


struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChatView(conversationId: UUID())
                .environmentObject(ChatManager())
        }
    }
}

struct MarkdownText: View {
    let markdown: String

    var body: some View {
        let lines = markdown.components(separatedBy: "\n")

        VStack(alignment: .leading, spacing: 4) {
            ForEach(lines, id: \.self) { line in
                if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if let attributed = try? AttributedString(markdown: line) {
                        Text(attributed)
                            .font(.body)
                    } else {
                        Text(line)
                            .font(.body)
                    }
                } else {
                    // Empty line - create spacing
                    Spacer(minLength: 4)
                }
            }
        }
    }
}
