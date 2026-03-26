import Foundation
import Combine

class ChatManager: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let storageService = LocalStorageService()

    init() {
        loadConversations()
    }

    func loadConversations() {
        conversations = storageService.loadConversations()
    }

    func createNewConversation(title: String = "New Conversation", model: ModelInfo = ModelInfo.default) -> Conversation {
        let newConversation = Conversation(title: title, model: model)
        conversations.insert(newConversation, at: 0)
        storageService.saveConversations(conversations)
        return newConversation
    }

    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        storageService.saveConversations(conversations)
    }

    func sendMessage(_ message: String, in conversation: Conversation) async throws -> String {
        // Clear any previous error message
        errorMessage = nil

        // Find the conversation in our list
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            throw ChatError.conversationNotFound
        }

        // Add user message to conversation
        var updatedConversation = conversations[index]
        updatedConversation.messages.append(Message(
            id: UUID(),
            role: .user,
            content: message,
            timestamp: Date()
        ))

        // Update timestamp
        updatedConversation.updatedAt = Date()

        // Update conversation in the list
        conversations[index] = updatedConversation

        // Save to local storage
        storageService.saveConversations(conversations)

        // Send to Ollama API
        do {
            let response = try await OllamaService.shared.generateResponse(
                message: message,
                model: conversation.model.name
            )

            // Add assistant response to conversation
            updatedConversation.messages.append(Message(
                id: UUID(),
                role: .assistant,
                content: response,
                timestamp: Date()
            ))

            // Update timestamp
            updatedConversation.updatedAt = Date()

            // Update conversation in the list
            conversations[index] = updatedConversation

            // Save to local storage
            storageService.saveConversations(conversations)

            return response
        } catch {
            // Add error message to conversation
            let errorContent = "Error: \(error.localizedDescription)"
            updatedConversation.messages.append(Message(
                id: UUID(),
                role: .assistant,
                content: errorContent,
                timestamp: Date()
            ))

            // Update timestamp
            updatedConversation.updatedAt = Date()

            // Update conversation in the list
            conversations[index] = updatedConversation

            // Save to local storage
            storageService.saveConversations(conversations)

            // Set error message for UI
            errorMessage = error.localizedDescription

            throw error
        }
    }
}

enum ChatError: Error {
    case conversationNotFound
}