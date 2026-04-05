import Foundation

class NameGenerationService {
    static let shared = NameGenerationService()
    private let ollamaService = OllamaService.shared

    private init() {}

    /// Generates a contextual title based on conversation messages using LLM.
    /// Routes to the correct backend based on the model's providerId.
    func generateTitleFromMessages(_ messages: [Message], model: ModelInfo) async -> String {
        guard messages.count >= 2 else {
            print("Not enough messages to generate title")
            return "New Chat"
        }

        // If the model belongs to a custom OpenAI-compatible endpoint, use that adapter.
        if let pid = model.providerId,
           let customProvider = ProviderManager.shared.customProvider(for: pid) {
            return await generateTitleViaOpenAI(messages: messages, modelName: model.name, provider: customProvider)
        }

        // Default: use Ollama
        do {
            let title = try await ollamaService.generateTitle(for: messages, model: model.name)
            print("Generated title: \(title)")
            return title
        } catch {
            print("Failed to generate title via Ollama: \(error)")
            return "New Chat"
        }
    }

    private func generateTitleViaOpenAI(messages: [Message], modelName: String, provider: APIProviderConfig) async -> String {
        let adapter = OpenAIBackendAdapter(providerConfig: provider)
        let prompt = """
        Based on this conversation, generate a short, descriptive title (max 6 words). \
        Respond with only the title, no punctuation or quotes.

        \(messages.prefix(4).map { "\($0.role.rawValue): \($0.content.prefix(200))" }.joined(separator: "\n"))
        """
        let titleRequest = [Message(role: .user, content: prompt)]
        do {
            let response = try await adapter.sendMessage(messages: titleRequest, model: modelName)
            let title = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Generated title (OpenAI): \(title)")
            return title.isEmpty ? "New Chat" : title
        } catch {
            print("Failed to generate title via OpenAI adapter: \(error)")
            return "New Chat"
        }
    }
}
