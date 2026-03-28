import Foundation
import open_chat

/// Backend adapter for Ollama API
class OllamaBackendAdapter: BackendAdapter {
    let name = "Ollama"

    private let ollamaService: OllamaService

    init(ollamaService: OllamaService = OllamaService.shared) {
        self.ollamaService = ollamaService
    }

    /// Sends a message to the Ollama API and returns a response
    /// - Parameters:
    ///   - messages: The conversation history
    ///   - model: The model to use for generation
    /// - Returns: The response message from the Ollama API
    func sendMessage(messages: [Message], model: String) async throws -> Message {
        // Send request to Ollama API using regular chat response
        let response = try await ollamaService.generateChatResponse(
            messages: messages,
            model: model
        )

        return Message(
            role: .assistant,
            content: response
        )
    }
}