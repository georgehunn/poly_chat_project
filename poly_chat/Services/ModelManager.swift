import Foundation
import Combine

class ModelManager: ObservableObject {
    @Published var models: [ModelInfo] = []
    @Published var isLoading = false
    @Published var starredModelNames: Set<String> = {
        // Default star "nemotron-3-super" on first launch
        if UserDefaults.standard.object(forKey: "starredModelNames") == nil {
            UserDefaults.standard.set(["nemotron-3-super"], forKey: "starredModelNames")
        }
        let saved = UserDefaults.standard.stringArray(forKey: "starredModelNames") ?? []
        return Set(saved)
    }()

    // Parsed once on first access, then looked up by model name in O(1)
    private lazy var localModelDetailsCache: [String: ModelInfo] = buildLocalModelDetailsCache()

    private var modelCacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cached_models.json")
    }

    func toggleStar(for model: ModelInfo) {
        if starredModelNames.contains(model.name) {
            starredModelNames.remove(model.name)
        } else {
            starredModelNames.insert(model.name)
        }
        UserDefaults.standard.set(Array(starredModelNames), forKey: "starredModelNames")
    }

    func isStarred(_ model: ModelInfo) -> Bool {
        starredModelNames.contains(model.name)
    }

    init() {
        // Initialize with empty array - models will be loaded from API on demand
        // JSON file is used only for enriching model details, not as a model source
    }

    func loadModels() {
        guard !isLoading else { return }

        // Show cached models immediately while fetching fresh from API
        if models.isEmpty, let cached = loadModelCache() {
            models = cached
        }

        isLoading = true

        Task {
            do {
                let ollamaModels = try await OllamaService.shared.listModels()
                var enrichedModels: [ModelInfo] = []

                // For each API model, enrich with JSON details if available (O(1) lookup)
                for ollamaModel in ollamaModels {
                    var modelInfo = ModelInfo(
                        name: ollamaModel.name,
                        displayName: ollamaModel.name.replacingOccurrences(of: ":", with: " "),
                        provider: "Ollama",
                        capabilities: ["text-generation"]
                    )

                    if let jsonDetails = localModelDetailsCache[ollamaModel.name] {
                        modelInfo.displayName = jsonDetails.displayName
                        modelInfo.provider = jsonDetails.provider
                        modelInfo.description = jsonDetails.description
                        modelInfo.capabilities = jsonDetails.capabilities
                        modelInfo.parameterSize = jsonDetails.parameterSize
                        modelInfo.quantizationLevel = jsonDetails.quantizationLevel
                        modelInfo.family = jsonDetails.family
                        modelInfo.contextLength = jsonDetails.contextLength
                        modelInfo.hasVision = jsonDetails.hasVision
                        modelInfo.hasTools = jsonDetails.hasTools
                    }

                    enrichedModels.append(modelInfo)
                }

                DispatchQueue.main.async {
                    self.models = enrichedModels
                    self.isLoading = false
                }
                saveModelCache(enrichedModels)
            } catch {
                print("Error loading models from API: \(error)")
                // Keep cached/existing models visible — don't clear to empty on error
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }

    /// Clears current models and reloads from API. Use when user installs a new model.
    func refreshModels() {
        models = []
        loadModels()
    }

    func loadModelDetails(for model: ModelInfo) async throws -> ModelInfo {
        // Use local JSON cache as the source of truth first
        if let localModel = localModelDetailsCache[model.name] {
            print("Loaded model details for \(model.name) from local JSON")
            return localModel
        }

        // Fallback to API if not found in local JSON
        do {
            let details = try await OllamaService.shared.getModelDetails(name: model.name)

            var contextLength: Int?
            if let modelInfo = details.model_info {
                if let contextLengthValue = modelInfo["llm.context_length"] {
                    if case .int(let value) = contextLengthValue {
                        contextLength = value
                    }
                } else if let contextLengthValue = modelInfo["general.context_length"] {
                    if case .int(let value) = contextLengthValue {
                        contextLength = value
                    }
                }
            }

            let parameterSize = details.details?.parameter_size
            let quantizationLevel = details.details?.quantization_level
            let family = details.details?.family
            let hasVision = details.capabilities?.vision
            let hasTools = (model.capabilities.contains("tool-use") || model.capabilities.contains("function-calling")) ?? false
            let description = details.license ?? details.parameters ?? details.modelfile ?? "No description available"

            return ModelInfo(
                name: model.name,
                displayName: model.displayName,
                provider: model.provider,
                capabilities: model.capabilities,
                description: description,
                parameterSize: parameterSize,
                quantizationLevel: quantizationLevel,
                family: family,
                contextLength: contextLength,
                hasVision: hasVision,
                hasTools: hasTools
            )
        } catch {
            print("API call failed for model \(model.name): \(error)")
            return model
        }
    }

    // MARK: - Private helpers

    /// Reads and parses model_details.json once, building a name-keyed dictionary.
    /// Called lazily on first access to localModelDetailsCache.
    private func buildLocalModelDetailsCache() -> [String: ModelInfo] {
        guard let path = Bundle.main.path(forResource: "model_details", ofType: "json") else {
            print("Local model details JSON file not found in bundle")
            return [:]
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let modelsArray = json?["models"] as? [[String: Any]] else {
                print("Invalid format in model details JSON")
                return [:]
            }

            var cache: [String: ModelInfo] = [:]
            cache.reserveCapacity(modelsArray.count)

            for modelData in modelsArray {
                guard let name = modelData["name"] as? String else { continue }
                let modelInfo = ModelInfo(
                    name: name,
                    displayName: modelData["displayName"] as? String ?? name.replacingOccurrences(of: ":", with: " "),
                    provider: modelData["provider"] as? String ?? "Unknown",
                    capabilities: modelData["capabilities"] as? [String] ?? ["text-generation"],
                    description: modelData["description"] as? String,
                    parameterSize: modelData["parameterSize"] as? String,
                    quantizationLevel: modelData["quantizationLevel"] as? String,
                    family: modelData["family"] as? String,
                    contextLength: modelData["contextLength"] as? Int,
                    hasVision: modelData["hasVision"] as? Bool,
                    hasTools: modelData["hasTools"] as? Bool
                )
                cache[name] = modelInfo
            }
            return cache
        } catch {
            print("Error reading or parsing local model details JSON: \(error)")
            return [:]
        }
    }

    private func saveModelCache(_ models: [ModelInfo]) {
        let url = modelCacheURL
        DispatchQueue.global(qos: .utility).async {
            do {
                let data = try JSONEncoder().encode(models)
                try data.write(to: url, options: .atomic)
            } catch {
                print("Error saving model cache: \(error)")
            }
        }
    }

    private func loadModelCache() -> [ModelInfo]? {
        guard let data = try? Data(contentsOf: modelCacheURL) else { return nil }
        return try? JSONDecoder().decode([ModelInfo].self, from: data)
    }
}
