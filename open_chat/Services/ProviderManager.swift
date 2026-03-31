import Foundation
import Combine

/// Manages the active API provider configuration
class ProviderManager: ObservableObject {
    static let shared = ProviderManager()

    @Published var activeProviderId: String?
    @Published var providers: [APIProviderConfig] = []

    private let storageService = SecureStorageService()

    private init() {
        loadProviders()
    }

    /// Load provider configuration from Keychain
    func loadProviders() {
        // Load from old single-provider storage
        if let endpoint = storageService.getEndpoint(), !endpoint.isEmpty {
            let config = APIProviderConfig(
                name: "Ollama",
                providerType: .ollama,
                endpoint: endpoint,
                apiKey: storageService.getAPIKey() ?? ""
            )
            providers = [config]
            activeProviderId = config.id
            saveActiveProviderId(config.id)
        }
    }

    /// Save provider to Keychain
    func saveProviders() {
        if let provider = providers.first {
            storageService.saveEndpoint(provider.endpoint)
            storageService.saveAPIKey(provider.apiKey)
        }
    }

    /// Add a new provider configuration
    func addProvider(name: String, providerType: ProviderType, endpoint: String, apiKey: String) -> APIProviderConfig {
        var config = APIProviderConfig(
            name: name,
            providerType: providerType,
            endpoint: endpoint,
            apiKey: apiKey
        )
        config.normalizeEndpoint()

        providers = [config]
        activeProviderId = config.id
        saveProviders()
        return config
    }

    /// Update an existing provider configuration
    func updateProvider(_ config: APIProviderConfig) {
        guard let index = providers.firstIndex(where: { $0.id == config.id }) else { return }
        providers[index] = config
        saveProviders()
    }

    /// Delete a provider configuration
    func deleteProvider(_ config: APIProviderConfig) {
        providers.removeAll { $0.id == config.id }
        saveProviders()
        activeProviderId = nil
    }

    /// Get the currently active adapter
    func getActiveAdapter() -> BackendAdapter? {
        guard let activeId = activeProviderId,
              let config = providers.first(where: { $0.id == activeId }) else {
            return nil
        }

        switch config.providerType {
        case .ollama:
            return OllamaBackendAdapter()
        case .grok, .openAI:
            return OpenAIBackendAdapter(providerConfig: config)
        }
    }

    /// Get the currently active provider configuration
    func getActiveProvider() -> APIProviderConfig? {
        guard let activeId = activeProviderId else { return nil }
        return providers.first(where: { $0.id == activeId })
    }

    /// Set the active provider by ID
    func setActiveProvider(_ config: APIProviderConfig) {
        activeProviderId = config.id
        saveActiveProviderId(config.id)
        objectWillChange.send()
    }

    /// Set the active provider by ID string
    func setActiveProviderById(_ id: String) {
        activeProviderId = id
        saveActiveProviderId(id)
        objectWillChange.send()
    }

    /// Check if any provider is configured
    func isConfigured() -> Bool {
        !providers.isEmpty
    }

    /// Get models from the active provider
    func loadModels() async throws -> [ModelInfo] {
        guard let adapter = getActiveAdapter() else {
            throw NSError(domain: "ProviderError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No provider configured"])
        }

        let ollamaService = OllamaService.shared
        let ollamaModels = try await ollamaService.listModels()

        var enrichedModels: [ModelInfo] = []
        for ollamaModel in ollamaModels {
            var modelInfo = ModelInfo(
                name: ollamaModel.name,
                displayName: ollamaModel.name.replacingOccurrences(of: ":", with: " "),
                provider: providers.first(where: { $0.id == activeProviderId })?.name ?? "Unknown",
                capabilities: ["text-generation"]
            )
            enrichedModels.append(modelInfo)
        }

        return enrichedModels
    }

    // MARK: - Private Helper Methods

    private func saveActiveProviderId(_ id: String) {
        UserDefaults.standard.set(id, forKey: "activeProviderId")
        UserDefaults.standard.synchronize()
    }

    private func deleteActiveProviderId() {
        UserDefaults.standard.removeObject(forKey: "activeProviderId")
        UserDefaults.standard.synchronize()
    }

    private func loadActiveProviderId() -> String? {
        UserDefaults.standard.string(forKey: "activeProviderId")
    }
}
