import SwiftUI

struct ModelsView: View {
    @EnvironmentObject private var modelManager: ModelManager
    @Environment(\.presentationMode) var presentationMode
    @State private var navigationPath = NavigationPath()
    @Binding var selectedModel: ModelInfo?
    @State private var compareModel1: ModelInfo?
    @State private var compareModel2: ModelInfo?
    @State private var isComparing = false

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
                ToolbarItem(placement: .navigationBarLeading) {
                    if !modelManager.models.isEmpty {
                        Button(action: { isComparing = true }) {
                            Label("Compare", systemImage: "arrow.left.arrow.right")
                        }
                        .disabled(modelManager.models.count < 2)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $isComparing) {
                ModelComparisonView(
                    model1: $compareModel1,
                    model2: $compareModel2,
                    isPresented: $isComparing
                )
                .environmentObject(modelManager)
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

struct ModelComparisonView: View {
    @Binding var model1: ModelInfo?
    @Binding var model2: ModelInfo?
    @Binding var isPresented: Bool
    @EnvironmentObject private var modelManager: ModelManager

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Models to Compare")) {
                    Picker("First Model", selection: $model1) {
                        Text("None").tag(Optional<ModelInfo>.none)
                        ForEach(sortedModels, id: \.self) { model in
                            Text(model.displayName).tag(Optional(model))
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Picker("Second Model", selection: $model2) {
                        Text("None").tag(Optional<ModelInfo>.none)
                        ForEach(sortedModels, id: \.self) { model in
                            Text(model.displayName).tag(Optional(model))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                if let model1 = model1, let model2 = model2 {
                    Section(header: Text("Comparison")) {
                        ComparisonGridView(model1: model1, model2: model2)
                    }
                }
            }
            .navigationTitle("Compare Models")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                        model1 = nil
                        model2 = nil
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .disabled(model1 == nil || model2 == nil)
                }
            }
        }
    }

    private var sortedModels: [ModelInfo] {
        modelManager.models.sorted { $0.name < $1.name }
    }
}

struct ComparisonGridView: View {
    let model1: ModelInfo
    let model2: ModelInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Model Names Header
            HStack {
                VStack(alignment: .leading) {
                    Text(model1.displayName)
                        .font(.headline)
                    Text(model1.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(model2.displayName)
                        .font(.headline)
                    Text(model2.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Parameters
            DetailComparisonRow(
                label: "Parameters",
                value1: model1.parameterSize ?? "Unknown",
                value2: model2.parameterSize ?? "Unknown"
            )

            // Quantization
            DetailComparisonRow(
                label: "Quantization",
                value1: model1.quantizationLevel ?? "Unknown",
                value2: model2.quantizationLevel ?? "Unknown"
            )

            // Family
            DetailComparisonRow(
                label: "Family",
                value1: model1.family ?? "Unknown",
                value2: model2.family ?? "Unknown"
            )

            // Context Length
            DetailComparisonRow(
                label: "Context Length",
                value1: model1.contextLength != nil ? "\(model1.contextLength!) tokens" : "Unknown",
                value2: model2.contextLength != nil ? "\(model2.contextLength!) tokens" : "Unknown"
            )

            // Capabilities
            VStack(alignment: .leading, spacing: 8) {
                Text("Capabilities")
                    .font(.headline)

                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("Text Generation")
                            .font(.subheadline)
                        Image(systemName: model1.capabilities.contains("text-generation") ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(model1.capabilities.contains("text-generation") ? .green : .red)
                    }

                    VStack(alignment: .leading) {
                        Text("Text Generation")
                            .font(.subheadline)
                        Image(systemName: model2.capabilities.contains("text-generation") ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(model2.capabilities.contains("text-generation") ? .green : .red)
                    }
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("Vision/Multimodal")
                            .font(.subheadline)
                        Image(systemName: model1.hasVision == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(model1.hasVision == true ? .green : .red)
                    }

                    VStack(alignment: .leading) {
                        Text("Vision/Multimodal")
                            .font(.subheadline)
                        Image(systemName: model2.hasVision == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(model2.hasVision == true ? .green : .red)
                    }
                }
            }
        }
        .padding()
    }
}

struct DetailComparisonRow: View {
    let label: String
    let value1: String
    let value2: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)

                Text(value1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(value2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
