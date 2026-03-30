import Foundation
import Combine
import UniformTypeIdentifiers
import PDFKit

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

        // Clean up any PDF files that are no longer referenced by any conversation
        Task { [weak self] in
            await self?.cleanupUnusedPDFFiles()
        }
    }

    /// Clean up PDF files that are no longer referenced by any conversation
    private func cleanupUnusedPDFFiles() async {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        // Get all filenames from all conversations
        var usedFilenames = Set<String>()
        for conversation in conversations {
            for message in conversation.messages {
                if let filename = message.documentAttachment?.filename {
                    usedFilenames.insert(filename)
                }
            }
        }

        // Remove PDF files not in the used list
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: nil)
            for fileURL in files {
                if fileURL.pathExtension == "pdf" {
                    if !usedFilenames.contains(fileURL.lastPathComponent) {
                        print("Removing unused PDF: \(fileURL.lastPathComponent)")
                        try FileManager.default.removeItem(at: fileURL)
                    }
                }
            }
        } catch {
            print("Error cleaning up PDF files: \(error)")
        }
    }

    func renameConversation(_ conversation: Conversation, to newName: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            return
        }

        conversations[index].title = newName
        conversations[index].updatedAt = Date()
        storageService.saveConversations(conversations)
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
            // Handle all errors as PDF processing failures
            throw ChatError.pdfProcessingFailed(error)
        }
    }

    func sendMessage(_ message: String, in conversation: Conversation, with documentAttachment: DocumentAttachment? = nil) async throws -> String {
        // Clear any previous error message
        errorMessage = nil

        // Find the conversation in our list
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            throw ChatError.conversationNotFound
        }

        var updatedConversation = conversations[index]

        // If we have a document attachment, enrich the message content now
        // This ensures only one message is created with both text and document info
        var finalContent = message
        if let attachment = documentAttachment, !attachment.textContent.isEmpty {
            finalContent = message + "\n\n--- Attached Document: \(attachment.filename) ---\n\(attachment.textContent)\n--- End of Attachment ---"
        }

        let userMessage = Message(
            id: UUID(),
            role: .user,
            content: finalContent,
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
    case pdfProcessingFailed(Error)
    case documentTooLarge
    case noTextInDocument
    case invalidPDF
}
