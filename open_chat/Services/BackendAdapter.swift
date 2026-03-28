import Foundation
import open_chat

/// A protocol that defines the interface for backend adapters
protocol BackendAdapter {
    /// The name of the backend adapter
    var name: String { get }

    /// Sends a message to the backend and returns a response
    /// - Parameters:
    ///   - messages: The conversation history
    ///   - model: The model to use for generation
    /// - Returns: The response message from the backend
    func sendMessage(messages: [Message], model: String) async throws -> Message
}