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
        var newConversation = Conversation(title: randomName, model: model)

        // Add system prompt to new conversation if configured
        if let systemPrompt = UserDefaults.standard.string(forKey: "systemPrompt"),
           !systemPrompt.isEmpty {
            let systemMessage = Message(
                id: UUID(),
                role: .system,
                content: systemPrompt,
                timestamp: Date()
            )
            newConversation.messages.append(systemMessage)
        }

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

    func sendMessage(_ message: String, in conversation: Conversation, with documentAttachment: DocumentAttachment? = nil) async throws -> String {
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
            timestamp: Date(),
            documentAttachment: documentAttachment
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

    /// Send a message with PDF document attachment
    /// - Parameters:
    ///   - message: The text message to send
    ///   - conversation: The conversation to send to
    ///   - pdfFileURL: The URL of the PDF file to attach
    /// - Returns: The assistant's response
    /// - Throws: ChatError or PDFDocumentService.PDFError
    func sendMessage(_ message: String, in conversation: Conversation, withPDFAt pdfFileURL: URL) async throws -> String {
        do {
            let documentAttachment = try await PDFDocumentService.shared.processPDF(from: pdfFileURL)
            return try await sendMessage(message, in: conversation, with: documentAttachment)
        } catch {
            // Handle PDFDocumentService errors
            // Handle all errors as PDF processing failures
            throw ChatError.pdfProcessingFailed(error)
        }
    }

    private func sendRegularMessage(conversation: Conversation, atIndex index: Int) async throws -> String {
        do {
            // Create a copy of messages with document content enriched in the user message
            var enrichedMessages = conversation.messages

            // Find the most recent user message and enrich it with document content if present
            if let lastUserMessageIndex = enrichedMessages.indices.reversed().first(where: { enrichedMessages[$0].role == .user }) {
                let userMessage = enrichedMessages[lastUserMessageIndex]
                if let attachment = userMessage.documentAttachment, !attachment.textContent.isEmpty {
                    // Create a new message with document content appended
                    let enrichedMessage = Message(
                        id: userMessage.id,
                        role: userMessage.role,
                        content: userMessage.content + "\n\n--- Attached Document: \(attachment.filename) ---\n\(attachment.textContent)\n--- End of Attachment ---",
                        timestamp: userMessage.timestamp,
                        documentAttachment: userMessage.documentAttachment
                    )
                    enrichedMessages[lastUserMessageIndex] = enrichedMessage
                }
            }

            let response = try await OllamaService.shared.generateChatResponse(
                messages: enrichedMessages,
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
    case pdfProcessingFailed(Error)
    case documentTooLarge
    case noTextInDocument
    case invalidPDF
}