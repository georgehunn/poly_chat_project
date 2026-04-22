import SwiftUI

struct ModelDetailView: View {
    let model: ModelInfo
    let onDismiss: () -> Void
    @EnvironmentObject private var modelManager: ModelManager
    @State private var detailedModel: ModelInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.displayName)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(model.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)

                // Description
                let description = detailedModel?.description ?? model.description
                if let description = description, !description.isEmpty && description != "No description available" {
                    SectionView(title: "Description") {
                        Text(description)
                            .font(.body)
                    }
                } else if isLoading {
                    SectionView(title: "Description") {
                        Text("Loading description...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                } else {
                    SectionView(title: "Description") {
                        Text("No detailed description available for this model.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }

                // Provider
                SectionView(title: "Provider") {
                    DetailRow(label: "Provider", value: model.provider)
                }

                // Technical Specifications
                SectionView(title: "Technical Specifications") {
                    VStack(spacing: 12) {
                        if let parameterSize = detailedModel?.parameterSize ?? model.parameterSize {
                            DetailRow(label: "Parameters", value: parameterSize)
                        }

                        if let quantizationLevel = detailedModel?.quantizationLevel ?? model.quantizationLevel {
                            DetailRow(label: "Quantization", value: quantizationLevel)
                        }

                        if let family = detailedModel?.family ?? model.family {
                            DetailRow(label: "Family", value: family)
                        }

                        if let contextLength = detailedModel?.contextLength ?? model.contextLength {
                            DetailRow(label: "Context Length", value: formatContextLength(contextLength))
                        }
                    }
                }

                // Capabilities
                let caps = detailedModel?.capabilities ?? model.capabilities
                if !caps.isEmpty {
                    SectionView(title: "Capabilities") {
                        VStack(spacing: 10) {
                            ForEach(caps, id: \.self) { cap in
                                let info = ModelCapabilityInfo.from(cap)
                                HStack(spacing: 10) {
                                    Image(systemName: info.icon)
                                        .foregroundColor(info.color)
                                        .frame(width: 20)
                                    Text(info.label)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Model Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    onDismiss()
                }
            }
        }
        .onAppear {
            loadModelDetails()
        }
        .refreshable {
            loadModelDetails()
        }
    }

    private func formatContextLength(_ length: Int) -> String {
        if length >= 1_000_000 {
            let m = Double(length) / 1_000_000
            return m.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(m))M" : String(format: "%.1fM", m)
        }
        return "\(length / 1000)K"
    }

    private func loadModelDetails() {
        guard detailedModel == nil && !isLoading else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                print("Loading detailed information for model: \(model.name)")
                let detailed = try await modelManager.loadModelDetails(for: model)
                print("Successfully loaded detailed model info - Description length: \(detailed.description?.count ?? 0)")
                print("Description preview: \(String(describing: detailed.description?.prefix(200)))")

                DispatchQueue.main.async {
                    self.detailedModel = detailed
                    self.isLoading = false
                }
            } catch {
                print("Error loading model details for \(model.name): \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load model details: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

struct SectionView<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            content
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// Maps a raw capability string from `ModelInfo.capabilities` to display metadata.
struct ModelCapabilityInfo {
    let label: String
    let icon: String
    let color: Color

    static func from(_ key: String) -> ModelCapabilityInfo {
        switch key {
        case "text-generation":
            return .init(label: "Text Generation",     icon: "text.alignleft",                     color: .primary)
        case "vision":
            return .init(label: "Vision",              icon: "eye.fill",                            color: .purple)
        case "multimodal":
            return .init(label: "Multimodal",          icon: "rectangle.stack.fill",                color: .purple)
        case "tool-use", "function-calling":
            return .init(label: "Tool Use",            icon: "wrench.and.screwdriver.fill",         color: .orange)
        case "code":
            return .init(label: "Code Generation",     icon: "curlybraces",                         color: .blue)
        case "reasoning":
            return .init(label: "Reasoning",           icon: "brain",                               color: .indigo)
        case "audio":
            return .init(label: "Audio",               icon: "speaker.wave.2.fill",                 color: .teal)
        case "embedding":
            return .init(label: "Embeddings",          icon: "arrow.triangle.branch",               color: .gray)
        case "agentic":
            return .init(label: "Agentic Workflows",   icon: "arrow.triangle.2.circlepath",         color: .green)
        default:
            let label = key.replacingOccurrences(of: "-", with: " ").capitalized
            return .init(label: label, icon: "sparkles", color: .secondary)
        }
    }
}

struct TagView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

struct ModelDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ModelDetailView(
                model: ModelInfo(
                    name: "llama3:latest",
                    displayName: "Llama 3",
                    provider: "Ollama",
                    capabilities: ["text-generation"],
                    description: "A state-of-the-art language model developed by Meta.",
                    parameterSize: "8B",
                    quantizationLevel: "Q4_K_M",
                    family: "llama",
                    contextLength: 8192,
                ),
                onDismiss: {}
            )
            .environmentObject(ModelManager())
        }
    }
}
