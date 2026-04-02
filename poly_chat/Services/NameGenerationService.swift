import Foundation

class NameGenerationService {
    static let shared = NameGenerationService()
    private let ollamaService = OllamaService.shared

    private init() {}

    /// Generates a contextual title based on conversation messages using LLM
    /// - Parameters:
    ///   - messages: The conversation messages (typically user + assistant exchange)
    ///   - model: The model name to use for title generation
    /// - Returns: A contextual title or "New Chat" if generation fails
    func generateTitleFromMessages(_ messages: [Message], model: String) async -> String {
        // Need at least user + assistant messages to generate a meaningful title
        guard messages.count >= 2 else {
            print("Not enough messages to generate title")
            return "New Chat"
        }

        do {
            let title = try await ollamaService.generateTitle(for: messages, model: model)
            print("Generated title: \(title)")
            return title
        } catch {
            print("Failed to generate title: \(error)")
            return "New Chat"
        }
    }
}
