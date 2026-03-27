import Foundation
@testable import open_chat

class OllamaService {
    static let shared = OllamaService()

    private init() {}

    private var baseURL: String {
        // Get from UserDefaults or use default
        if let savedEndpoint = UserDefaults.standard.string(forKey: "ollamaEndpoint"),
           !savedEndpoint.isEmpty {
            // Normalize the endpoint
            var endpoint = savedEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)

            // Remove trailing slashes
            while endpoint.hasSuffix("/") {
                endpoint.removeLast()
            }

            // Add /api if it's not already there
            if !endpoint.hasSuffix("/api") && !endpoint.contains("/api/") {
                endpoint += "/api"
            }

            print("Using Ollama endpoint: \(endpoint)")
            return endpoint
        }
        return "http://localhost:11434/api"
    }

    func generateChatResponse(messages: [Message], model: String) async throws -> String {
        let urlString = "\(baseURL)/chat"
        print("Attempting to connect to: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            throw URLError(.badURL)
        }

        // Convert messages to the format expected by Ollama chat API
        let ollamaMessages = messages.map { message -> [String: String] in
            return [
                "role": message.role.rawValue,
                "content": message.content
            ]
        }

        let requestBody: [String: Any] = [
            "model": model,
            "messages": ollamaMessages,
            "stream": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add API key if available
        if let apiKey = UserDefaults.standard.string(forKey: "apiKey"),
           !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            print("Using API key for authentication")
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("Failed to serialize request body")
            throw URLError(.cannotParseResponse)
        }

        request.httpBody = jsonData

        do {
            print("Sending request to Ollama...")
            let (data, response) = try await URLSession.shared.data(for: request)

            // Print response info for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status: \(httpResponse.statusCode)")
                print("Headers: \(httpResponse.allHeaderFields)")
            }

            // Print response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response data: \(responseString)")
            }

            let ollamaResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
            print("Successfully received response: \(ollamaResponse.message.content)")
            return ollamaResponse.message.content
        } catch {
            print("Error in generateChatResponse: \(error)")
            throw error
        }
    }

    func listModels() async throws -> [OllamaModel] {
        let urlString = "\(baseURL)/tags"
        print("Attempting to fetch models from: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("Invalid URL for models: \(urlString)")
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add API key if available
        if let apiKey = UserDefaults.standard.string(forKey: "apiKey"),
           !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        }

        do {
            print("Fetching models from Ollama...")
            let (data, response) = try await URLSession.shared.data(for: request)

            // Print response info for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("Models HTTP Status: \(httpResponse.statusCode)")
            }

            let modelsResponse = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
            print("Successfully fetched \(modelsResponse.models.count) models")
            return modelsResponse.models
        } catch {
            print("Error fetching models: \(error)")
            throw error
        }
    }
}

struct OllamaChatResponse: Codable {
    let model: String
    let message: OllamaMessage
    let done: Bool
}

struct OllamaMessage: Codable {
    let role: String
    let content: String
}

struct OllamaModel: Codable {
    let name: String
    let modified_at: String
    let size: Int
}

struct OllamaModelsResponse: Codable {
    let models: [OllamaModel]
}