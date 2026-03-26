import SwiftUI

struct ModelsView: View {
    @EnvironmentObject private var modelManager: ModelManager
    @Binding var selectedModel: ModelInfo?

    var body: some View {
        List {
            Section(header: Text("Available Models")) {
                if modelManager.isLoading {
                    HStack {
                        Spacer()
                        VStack {
                            ProgressView()
                            Text("Loading models...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                } else if modelManager.models.isEmpty {
                    Text("No models available")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(modelManager.models, id: \.name) { model in
                        Button(action: {
                            selectedModel = model
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(model.displayName)
                                        .font(.headline)
                                    Text(model.provider)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedModel?.name == model.name {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }

            Section(header: Text("Model Information")) {
                if let model = selectedModel {
                    Text("Selected: \(model.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No model selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Models")
        .onAppear {
            if modelManager.models.isEmpty && !modelManager.isLoading {
                modelManager.loadModels()
            }
        }
    }
}