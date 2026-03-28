import Foundation
import Combine
import open_chat

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
        let userMessage = Message(
            id: UUID(),
            role: .user,
            content: message,
            timestamp: Date()
        )
        updatedConversation.messages.append(userMessage)

        // Update timestamp
        updatedConversation.updatedAt = Date()

        // Update conversation in the list
        conversations[index] = updatedConversation

        // Save to local storage
        storageService.saveConversations(conversations)

        // Use regular flow
        return try await sendRegularMessage(conversation: updatedConversation, atIndex: index)
    }

    private func sendRegularMessage(conversation: Conversation, atIndex index: Int) async throws -> String {
        do {
            let response = try await OllamaService.shared.generateChatResponse(
                messages: conversation.messages,
                model: conversation.model.name
            )

            // Add assistant response to conversation
            let assistantMessage = Message(
                id: UUID(),
                role: .assistant,
                content: response,
                timestamp: Date()
            )
            var updatedConversation = conversation
            updatedConversation.messages.append(assistantMessage)
            updatedConversation.updatedAt = Date()
            conversations[index] = updatedConversation
            storageService.saveConversations(conversations)

            return response
        } catch {
            // Add error message to conversation
            let errorContent = "Error: \(error.localizedDescription)"
            let errorMessage = Message(
                id: UUID(),
                role: .assistant,
                content: errorContent,
                timestamp: Date()
            )
            var updatedConversation = conversation
            updatedConversation.messages.append(errorMessage)
            updatedConversation.updatedAt = Date()
            conversations[index] = updatedConversation
            storageService.saveConversations(conversations)

            // Set error message for UI
            self.errorMessage = error.localizedDescription

            throw error
        }
    }

}

enum ChatError: Error {
    case conversationNotFound
}