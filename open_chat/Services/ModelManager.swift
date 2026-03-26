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
            ModelInfo.default,
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
}