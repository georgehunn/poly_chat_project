import SwiftUI

struct ModelsView: View {
    @EnvironmentObject private var modelManager: ModelManager
    @Binding var selectedModel: ModelInfo?

    var body: some View {
        List {
            if !modelManager.models.isEmpty {
                Section(header: Text("Information")) {
                    Text("Tap on any model below to view detailed information including technical specifications, capabilities, and descriptions.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

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
                        NavigationLink(destination: ModelDetailView(model: model)) {
                            ModelRowView(model: model)
                        }
                    }
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

struct ModelRowView: View {
    let model: ModelInfo

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.headline)

                HStack(spacing: 6) {
                    Text(model.provider)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let parameterSize = model.parameterSize {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(parameterSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let quantization = model.quantizationLevel {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(quantization)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Show capability badges
            HStack(spacing: 4) {
                if model.hasVision == true {
                    Text("👁️")
                        .font(.caption)
                }
                if model.hasTools == true {
                    Text("🔧")
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 2)
    }
}