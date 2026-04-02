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
        isLoading = true

        // Load models from Ollama API
        // JSON file is used only to enrich model details
        Task {
            do {
                let ollamaModels = try await OllamaService.shared.listModels()
                var enrichedModels: [ModelInfo] = []

                // For each API model, enrich with JSON details if available
                for ollamaModel in ollamaModels {
                    var modelInfo = ModelInfo(
                        name: ollamaModel.name,
                        displayName: ollamaModel.name.replacingOccurrences(of: ":", with: " "),
                        provider: "Ollama",
                        capabilities: ["text-generation"]
                    )

                    // Try to enrich with detailed information from local JSON
                    if let jsonDetails = loadModelDetailsFromLocalJSON(for: ollamaModel.name) {
                        // Use JSON details for displayName, provider, description, capabilities
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
            } catch {
                print("Error loading models from API: \(error)")
                // Clear models on error so user knows to check connection
                DispatchQueue.main.async {
                    self.models = []
                    self.isLoading = false
                }
            }
        }
    }

    func loadModelDetails(for model: ModelInfo) async throws -> ModelInfo {
        // Use local JSON as the source of truth first
        if let localModel = loadModelDetailsFromLocalJSON(for: model.name) {
            print("Loaded model details for \(model.name) from local JSON")
            return localModel
        }

        // Fallback to API if not found in local JSON
        do {
            let details = try await OllamaService.shared.getModelDetails(name: model.name)

            // Extract context length from model_info if available
            var contextLength: Int?
            if let modelInfo = details.model_info {
                // Look for context length in various possible keys
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

            // Extract parameter size
            let parameterSize = details.details?.parameter_size

            // Extract quantization level
            let quantizationLevel = details.details?.quantization_level

            // Extract family
            let family = details.details?.family

            // Extract capabilities
            let hasVision = details.capabilities?.vision
            let hasTools = (model.capabilities.contains("tool-use") || model.capabilities.contains("function-calling")) ?? false

            // Extract description/license - prioritize license, then parameters, then modelfile
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
            // Return original model if both local JSON and API fail
            return model
        }
    }

    /// Loads model details from local JSON file
    /// - Parameter modelName: The name of the model to look up
    /// - Returns: ModelInfo with details from local JSON, or nil if not found
    private func loadModelDetailsFromLocalJSON(for modelName: String) -> ModelInfo? {
        // Try to get the file from the bundle first
        if let path = Bundle.main.path(forResource: "model_details", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                guard let models = json?["models"] as? [[String: Any]] else {
                    print("Invalid format in model details JSON")
                    return nil
                }

                // Find the model in our JSON data
                guard let modelData = models.first(where: { ($0["name"] as? String) == modelName }) else {
                    print("Model \(modelName) not found in local JSON data")
                    return nil
                }

                // Extract values with proper type checking
                let name = modelData["name"] as? String ?? modelName
                let displayName = modelData["displayName"] as? String ?? modelName.replacingOccurrences(of: ":", with: " ")
                let provider = modelData["provider"] as? String ?? "Unknown"
                let capabilities = modelData["capabilities"] as? [String] ?? ["text-generation"]
                let description = modelData["description"] as? String
                let parameterSize = modelData["parameterSize"] as? String
                let quantizationLevel = modelData["quantizationLevel"] as? String
                let family = modelData["family"] as? String
                let contextLength = modelData["contextLength"] as? Int
                let hasVision = modelData["hasVision"] as? Bool
                let hasTools = modelData["hasTools"] as? Bool

                return ModelInfo(
                    name: name,
                    displayName: displayName,
                    provider: provider,
                    capabilities: capabilities,
                    description: description,
                    parameterSize: parameterSize,
                    quantizationLevel: quantizationLevel,
                    family: family,
                    contextLength: contextLength,
                    hasVision: hasVision,
                    hasTools: hasTools
                )
            } catch {
                print("Error reading or parsing local model details JSON: \(error)")
                return nil
            }
        } else {
            print("Local model details JSON file not found in bundle")
            return nil
        }
    }
}