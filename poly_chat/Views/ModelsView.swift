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
                if !modelManager.allModels.isEmpty {
                    Section(header: Text("Information")) {
                        Text("Tap on any model below to view detailed information including technical specifications, capabilities, and descriptions. Swipe right to star your favorite models for quick access later.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if modelManager.isLoading {
                    Section(header: Text("Available Models")) {
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
                    }
                } else if modelManager.allModels.isEmpty {
                    Section(header: Text("Available Models")) {
                        Text("No models available")
                            .foregroundColor(.secondary)
                    }
                } else {
                    let providers: [String] = {
                        var seen = Set<String>()
                        return sortedModels.map { $0.apiProviderName }.filter { seen.insert($0).inserted }
                    }()
                    ForEach(providers, id: \.self) { providerName in
                        Section(header: Text(providerName)) {
                            ForEach(sortedModels.filter { $0.apiProviderName == providerName }, id: \.name) { model in
                                NavigationLink(value: model) {
                                    ModelRowView(model: model, isStarred: modelManager.isStarred(model))
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        modelManager.toggleStar(for: model)
                                    } label: {
                                        Label(
                                            modelManager.isStarred(model) ? "Unstar" : "Star",
                                            systemImage: modelManager.isStarred(model) ? "star.slash.fill" : "star.fill"
                                        )
                                    }
                                    .tint(.yellow)
                                }
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
                    if !modelManager.allModels.isEmpty {
                        Button(action: { isComparing = true }) {
                            Label("Compare", systemImage: "arrow.left.arrow.right")
                        }
                        .disabled(modelManager.allModels.count < 2)
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
                if modelManager.allModels.isEmpty && !modelManager.isLoading {
                    modelManager.loadModels()
                    modelManager.loadCustomModels()
                }
            }
        }
    }

    private var sortedModels: [ModelInfo] {
        modelManager.allModels.sorted { $0.name < $1.name }
    }
}

struct ModelRowView: View {
    let model: ModelInfo
    var isStarred: Bool = false

    var body: some View {
        HStack {
            if isStarred {
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.yellow)
            }
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

            // Capability badges + context length
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 4) {
                    if model.hasVision == true {
                        CapabilityBadge(icon: "eye.fill", label: "Vision", color: .purple)
                    }
                    if model.hasTools == true {
                        CapabilityBadge(icon: "wrench.and.screwdriver.fill", label: "Tools", color: .orange)
                    }
                }
                if let contextLength = model.contextLength {
                    Text("\(contextLength / 1000)k ctx")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CapabilityBadge: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
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
        modelManager.allModels.sorted { $0.name < $1.name }
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
                        .fontWeight(.bold)
                    Text(model1.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(model2.displayName)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(model2.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Provider Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Provider")
                    .font(.headline)
                    .fontWeight(.semibold)
                HStack(alignment: .center, spacing: 12) {
                    Spacer()
                    Text(model1.provider)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Spacer()
                    Text(model2.provider)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // Description Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Description")
                    .font(.headline)
                    .fontWeight(.semibold)
                HStack(alignment: .center, spacing: 12) {
                    Spacer()
                    if let description = model1.description, !description.isEmpty {
                        Text(description.count > 50 ? String(description.prefix(50)) + "..." : description)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("N/A")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    Spacer()
                    if let description = model2.description, !description.isEmpty {
                        Text(description.count > 50 ? String(description.prefix(50)) + "..." : description)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("N/A")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .padding(.horizontal)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            Divider()

            // Technical Specifications Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Technical Specifications")
                    .font(.headline)
                    .fontWeight(.semibold)

                // Parameters
                HStack(alignment: .center, spacing: 12) {
                    Text("Parameters")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 100, alignment: .leading)
                    Spacer()
                    if let param1 = model1.parameterSize {
                        Text(param1)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("N/A")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    Spacer()
                    if let param2 = model2.parameterSize {
                        Text(param2)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("N/A")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                // Quantization
                HStack(alignment: .center, spacing: 12) {
                    Text("Quantization")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 100, alignment: .leading)
                    Spacer()
                    if let quant1 = model1.quantizationLevel {
                        Text(quant1)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("N/A")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    Spacer()
                    if let quant2 = model2.quantizationLevel {
                        Text(quant2)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("N/A")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                // Family
                HStack(alignment: .center, spacing: 12) {
                    Text("Family")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 100, alignment: .leading)
                    Spacer()
                    if let fam1 = model1.family {
                        Text(fam1)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("N/A")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    Spacer()
                    if let fam2 = model2.family {
                        Text(fam2)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("N/A")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                // Context Length
                HStack(alignment: .center, spacing: 12) {
                    Text("Context Length")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 100, alignment: .leading)
                    Spacer()
                    if let ctx1 = model1.contextLength {
                        Text("\(ctx1)")
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("N/A")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    Spacer()
                    if let ctx2 = model2.contextLength {
                        Text("\(ctx2)")
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("N/A")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .padding(.horizontal)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            Divider()

            // Capabilities Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Capabilities")
                    .font(.headline)
                    .fontWeight(.semibold)

                // Text Generation
                HStack(alignment: .center, spacing: 12) {
                    Text("Text Generation")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 120, alignment: .leading)
                    Spacer()
                    if (model1.capabilities.contains("text-generation")) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.body)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.body)
                    }
                    Spacer()
                    if (model2.capabilities.contains("text-generation")) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.body)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.body)
                    }
                }

                // Vision/Multimodal
                HStack(alignment: .center, spacing: 12) {
                    Text("Vision/Multimodal")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 120, alignment: .leading)
                    Spacer()
                    if model1.hasVision == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.body)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.body)
                    }
                    Spacer()
                    if model2.hasVision == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.body)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.body)
                    }
                }

                // Tool Use
                HStack(alignment: .center, spacing: 12) {
                    Text("Tool Use")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 120, alignment: .leading)
                    Spacer()
                    if model1.hasTools == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.body)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.body)
                    }
                    Spacer()
                    if model2.hasTools == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.body)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.body)
                    }
                }
            }
            .padding(.horizontal)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
