import Foundation
import Combine

class ModelManager: ObservableObject {
    @Published var models: [ModelInfo] = []
    @Published var isLoading = false

    init() {
        // Load models from local JSON as the source of truth
        loadModelsFromLocalJSON()
    }

    func loadModels() {
        guard !isLoading else { return }
        isLoading = true

        // Load models from Ollama API
        Task {
            do {
                let ollamaModels = try await OllamaService.shared.listModels()
                var detailedModels: [ModelInfo] = []

                // Load detailed information for each model from local JSON first
                for ollamaModel in ollamaModels {
                    // Start with basic model info from API
                    var modelInfo = ModelInfo(
                        name: ollamaModel.name,
                        displayName: ollamaModel.name.replacingOccurrences(of: ":", with: " "),
                        provider: "Ollama",
                        capabilities: ["text-generation"]
                    )

                    // Try to load detailed information from local JSON
                    if let detailedModel = loadModelDetailsFromLocalJSON(for: ollamaModel.name) {
                        modelInfo = detailedModel
                    }


                    detailedModels.append(modelInfo)
                }

                DispatchQueue.main.async {
                    self.models = detailedModels
                    self.isLoading = false
                }
            } catch {
                print("Error loading models from API: \(error)")
                // Keep using local JSON models if API fails
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }

    private func loadModelsFromLocalJSON() {
        guard let path = Bundle.main.path(forResource: "model_details", ofType: "json") else {
            print("Local model details JSON file not found")
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard let modelsArray = json?["models"] as? [[String: Any]] else {
                print("Invalid format in model details JSON")
                return
            }

            var localModels: [ModelInfo] = []
            for modelData in modelsArray {
                // Extract values with proper type checking
                let name = modelData["name"] as? String ?? "unknown"
                let displayName = modelData["displayName"] as? String ?? name.replacingOccurrences(of: ":", with: " ")
                let provider = modelData["provider"] as? String ?? "Unknown"
                let capabilities = modelData["capabilities"] as? [String] ?? ["text-generation"]
                let description = modelData["description"] as? String
                let parameterSize = modelData["parameterSize"] as? String
                let quantizationLevel = modelData["quantizationLevel"] as? String
                let family = modelData["family"] as? String
                let contextLength = modelData["contextLength"] as? Int
                let hasVision = modelData["hasVision"] as? Bool

                let modelInfo = ModelInfo(
                    name: name,
                    displayName: displayName,
                    provider: provider,
                    capabilities: capabilities,
                    description: description,
                    parameterSize: parameterSize,
                    quantizationLevel: quantizationLevel,
                    family: family,
                    contextLength: contextLength,
                    hasVision: hasVision
                )

                localModels.append(modelInfo)
            }

            print("Loaded \(localModels.count) models from local JSON")
            self.models = localModels
        } catch {
            print("Error reading or parsing local model details JSON: \(error)")
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
                hasVision: hasVision
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
                    hasVision: hasVision
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