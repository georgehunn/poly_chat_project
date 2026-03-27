import SwiftUI

struct ChatView: View {
    let conversationId: UUID
    @State private var messageText = ""
    @State private var isLoading = false
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
                            MessageView(message: message)
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
    }

    private func sendMessage() {
        guard !messageText.isEmpty, let conversation = conversation else { return }

        let messageToSend = messageText
        messageText = "" // Clear the text field immediately

        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                _ = try await chatManager.sendMessage(messageToSend, in: conversation)
            } catch {
                print("Error sending message: \(error)")
                // Error message will be displayed in the chat
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

            VStack(alignment: message.role == .user ? .trailing : .leading) {
                Text(message.content)
                    .padding()
                    .background(message.role == .user ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .foregroundColor(message.role == .user ? .primary : .primary)

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