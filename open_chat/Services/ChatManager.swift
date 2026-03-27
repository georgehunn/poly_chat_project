import Foundation
import Combine
@testable import open_chat

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

    func createNewConversation(model: ModelInfo) -> Conversation {
        let randomName = NameGenerationService.shared.generateRandomName()
        let newConversation = Conversation(title: randomName, model: model)
        conversations.insert(newConversation, at: 0)
        storageService.saveConversations(conversations)
        return newConversation
    }

    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        storageService.saveConversations(conversations)
    }

    func renameConversation(_ conversation: Conversation, to newName: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            return
        }

        conversations[index].title = newName
        conversations[index].updatedAt = Date()
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

        // Send to Ollama API with full conversation history
        do {
            let response = try await OllamaService.shared.generateChatResponse(
                messages: updatedConversation.messages,
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