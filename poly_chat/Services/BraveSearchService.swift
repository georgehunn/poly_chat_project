import Foundation

class WebSearchService {
    static let shared = WebSearchService()

    private let secureStorage = SecureStorageService()

    private init() {}

    /// Returns the configured Tavily API key, or nil if not set.
    var apiKey: String? {
        guard let key = secureStorage.getBraveAPIKey(), !key.isEmpty else { return nil }
        return key
    }

    /// Searches the web using the Tavily API and returns formatted results.
    /// - Parameter query: The search query string
    /// - Returns: A short AI-generated answer followed by numbered source results
    func search(query: String) async throws -> String {
        print("[WebSearch] ── START ─────────────────────────────────")
        print("[WebSearch] Query: \"\(query)\"")

        guard let key = apiKey else {
            print("[WebSearch] ERROR — no Tavily API key configured")
            throw WebSearchError.noAPIKey
        }

        guard let url = URL(string: "https://api.tavily.com/search") else {
            throw URLError(.badURL)
        }

        let body: [String: Any] = [
            "api_key": key,
            "query": query,
            "max_results": 5,
            "search_depth": "basic"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("[WebSearch] Calling Tavily API...")
        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("[WebSearch] HTTP \(httpResponse.statusCode)")
            if httpResponse.statusCode == 402 {
                print("[WebSearch] ERROR — out of credits (402)")
                throw WebSearchError.outOfCredits
            }
            if httpResponse.statusCode >= 400 {
                let errorBody = String(data: data, encoding: .utf8) ?? ""
                print("[WebSearch] ERROR body: \(errorBody)")
                throw NSError(
                    domain: "WebSearchError",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Tavily error \(httpResponse.statusCode): \(errorBody)"]
                )
            }
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[WebSearch] ERROR — failed to parse JSON response")
            print("[WebSearch] Raw response: \(String(data: data, encoding: .utf8) ?? "<unreadable>")")
            return "No results found for: \(query)"
        }

        var output = ""

        if let answer = json["answer"] as? String, !answer.isEmpty {
            print("[WebSearch] Got AI answer (\(answer.count) chars)")
            output += "Summary: \(answer)\n\nSources:\n"
        }

        if let results = json["results"] as? [[String: Any]], !results.isEmpty {
            print("[WebSearch] Got \(results.count) result(s)")
            let sources = results.prefix(5).enumerated().map { (i, result) -> String in
                let title = result["title"] as? String ?? "Untitled"
                let urlStr = result["url"] as? String ?? ""
                let content = result["content"] as? String ?? ""
                return "[\(i + 1)] \(title)\n\(urlStr)\n\(content)"
            }.joined(separator: "\n\n")
            output += sources
        } else {
            print("[WebSearch] No results in response")
            return "No results found for: \(query)"
        }

        if output.count > 2000 {
            output = String(output.prefix(2000)) + "..."
        }
        print("[WebSearch] Returning \(output.count) chars to model")
        print("[WebSearch] ── END ───────────────────────────────────")
        return output
    }

    /// Validates the Tavily API key by performing a minimal test search.
    func validateAPIKey() async throws {
        _ = try await search(query: "test")
    }

    enum WebSearchError: LocalizedError {
        case noAPIKey
        case outOfCredits

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "Tavily API key is not configured."
            case .outOfCredits: return "Web search credits exhausted."
            }
        }
    }
}
