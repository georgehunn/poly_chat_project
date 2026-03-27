import Foundation
import Combine

class ModelManager: ObservableObject {
    @Published var models: [ModelInfo] = []
    @Published var isLoading = false

    func loadModels() {
        guard !isLoading else { return }
        isLoading = true

        // Load models from Ollama API
        Task {
            do {
                let ollamaModels = try await OllamaService.shared.listModels()
                DispatchQueue.main.async {
                    self.models = ollamaModels.map { model in
                        ModelInfo(
                            name: model.name,
                            displayName: model.name.replacingOccurrences(of: ":", with: " "),
                            provider: "Ollama",
                            capabilities: ["text-generation"]
                        )
                    }
                    self.isLoading = false
                }
            } catch {
                print("Error loading models: \(error)")
                // Load default models if API fails
                DispatchQueue.main.async {
                    self.loadDefaultModels()
                    self.isLoading = false
                }
            }
        }
    }

    private func loadDefaultModels() {
        models = [
            ModelInfo(
                name: "llama3",
                displayName: "Llama 3",
                provider: "Ollama",
                capabilities: ["text-generation"]
            ),
            ModelInfo(
                name: "mistral",
                displayName: "Mistral",
                provider: "Ollama",
                capabilities: ["text-generation"]
            ),
            ModelInfo(
                name: "gemma",
                displayName: "Gemma",
                provider: "Ollama",
                capabilities: ["text-generation"]
            )
        ]
    }

    func loadModelDetails(for model: ModelInfo) async throws -> ModelInfo {
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
        let hasTools = details.capabilities?.tools

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
    }
}