import SwiftUI

struct ModelsView: View {
    @EnvironmentObject private var modelManager: ModelManager
    @Environment(\.presentationMode) var presentationMode
    @State private var navigationPath = NavigationPath()
    @Binding var selectedModel: ModelInfo?

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                        ForEach(sortedModels, id: \.name) { model in
                            NavigationLink(value: model) {
                                ModelRowView(model: model)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Models")
            .navigationDestination(for: ModelInfo.self) { model in
                ModelDetailView(model: model, onDismiss: { presentationMode.wrappedValue.dismiss() })
                    .environmentObject(modelManager)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                if modelManager.models.isEmpty && !modelManager.isLoading {
                    modelManager.loadModels()
                }
            }
        }
    }

    private var sortedModels: [ModelInfo] {
        modelManager.models.sorted { $0.name < $1.name }
    }
}

struct ModelRowView: View {
    let model: ModelInfo

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.headline)

                // Provider and technical details
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

                    if let family = model.family, !family.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(family)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Short description preview
                if let description = model.description, !description.isEmpty {
                    Text(description.prefix(100) + (description.count > 100 ? "..." : ""))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Show capability badges
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    if model.hasVision == true {
                        Text("👁️")
                            .font(.caption)
                    }
                    if model.hasTools == true {
                        Text("🛠️")
                            .font(.caption)
                    }
                }

                // Context length indicator
                if let contextLength = model.contextLength {
                    Text("\(contextLength) tokens")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
