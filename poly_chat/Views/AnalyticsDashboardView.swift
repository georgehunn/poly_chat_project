import SwiftUI
import Charts

enum StatsMetric: String, CaseIterable {
    case chats = "Chats"
    case messages = "Messages"
}

enum StatsPeriod: String, CaseIterable {
    case day = "Last Day"
    case week = "Last Week"
    case month = "Last Month"

    var startDate: Date {
        let calendar = Calendar.current
        switch self {
        case .day:   return calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        case .week:  return calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .month: return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        }
    }
}

struct AnalyticsDashboardView: View {
    @AppStorage("analyticsEnabled") private var analyticsEnabled = true
    @Environment(\.dismiss) private var dismiss

    @State private var dailyStats: [DailyStat] = []
    @State private var isLoading = false
    @State private var selectedPeriod: StatsPeriod = .week
    @State private var selectedMetric: StatsMetric = .chats

    var body: some View {
        NavigationView {
            Group {
                if analyticsEnabled {
                    dashboardContent
                } else {
                    enablePrompt
                }
            }
            .navigationTitle("Usage Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { loadData() }
        }
    }

    // MARK: - Enable Prompt (shown when analytics is OFF)

    private var enablePrompt: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Community Usage Statistics")
                .font(.title2)
                .fontWeight(.bold)

            Text("See which AI models are most popular across the Poly Chat community. This anonymous data helps prioritize development and lets you discover trending models.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("No message content or personal data is ever collected. You can change this any time in Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Link(destination: URL(string: "https://github.com/georgehunn/poly_chat_project")!) {
                Label("Review the analytics code on GitHub", systemImage: "lock.shield")
                    .font(.caption)
            }

            Button(action: {
                analyticsEnabled = true
                loadData()
            }) {
                Text("Enable")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 48)

            Button("Not Now") { dismiss() }
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    // MARK: - Dashboard Content (shown when analytics is ON)

    private var dashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Period picker
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(StatsPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Picker("Metric", selection: $selectedMetric) {
                    ForEach(StatsMetric.allCases, id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if isLoading {
                    ProgressView("Loading statistics...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if filteredStats.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No data yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Statistics will appear here as the community uses Poly Chat.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    modelPopularityChart
                    modelUsageOverTimeChart
                }
            }
            .padding(.vertical)
        }
        .refreshable { await loadDataAsync() }
    }

    // MARK: - Chart 1: Most Used Models (Horizontal Bar)

    private var modelPopularityChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most Used Models")
                .font(.headline)
                .padding(.horizontal)

            Text("Percentage of total \(selectedMetric.rawValue.lowercased()) \u{2022} \(selectedPeriod.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            let modelPercentages = computeModelPercentages(from: filteredStats, metric: selectedMetric)

            Chart(modelPercentages, id: \.model) { item in
                BarMark(
                    x: .value("Percentage", item.percentage),
                    y: .value("Model", item.model)
                )
                .foregroundStyle(by: .value("Model", item.model))
                .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                    Text(String(format: "%.1f%%", item.percentage))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))%")
                        }
                    }
                }
            }
            .chartXScale(domain: 0...100)
            .frame(height: CGFloat(max(modelPercentages.count, 1)) * 36 + 40)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Chart 2: Model Usage Over Time (Line)

    private var modelUsageOverTimeChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model Usage Over Time")
                .font(.headline)
                .padding(.horizontal)

            Text("Share of daily \(selectedMetric.rawValue.lowercased()) (%) \u{2022} All time")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            let timeData = computeModelUsageOverTime(metric: selectedMetric)
            let uniqueDates = Set(timeData.map { Calendar.current.startOfDay(for: $0.date) })

            if timeData.isEmpty {
                Text("Not enough data for historical view")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Chart(timeData, id: \.id) { item in
                    if uniqueDates.count > 1 {
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Percentage", item.percentage)
                        )
                        .foregroundStyle(by: .value("Model", item.model))
                        .interpolationMethod(.catmullRom)
                    }
                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Percentage", item.percentage)
                    )
                    .foregroundStyle(by: .value("Model", item.model))
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))%")
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .frame(height: 220)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Data Computation

    private var filteredStats: [DailyStat] {
        let cutoff = selectedPeriod.startDate
        let result = dailyStats.filter { stat in
            guard let date = stat.date else {
                print("[Dashboard] filter — failed to parse date: '\(stat.statDate)'")
                return false
            }
            let pass = date >= cutoff
            print("[Dashboard] filter — statDate:'\(stat.statDate)' parsed:\(date) cutoff:\(cutoff) pass:\(pass)")
            return pass
        }
        print("[Dashboard] filteredStats: \(result.count) of \(dailyStats.count) rows pass filter")
        return result
    }

    private func metricValue(for stat: DailyStat, metric: StatsMetric) -> Int {
        switch metric {
        case .chats:    return stat.totalSessions
        case .messages: return stat.totalMessages
        }
    }

    private func computeModelPercentages(from stats: [DailyStat], metric: StatsMetric) -> [ModelPercentage] {
        var countByModel: [String: Int] = [:]
        var total = 0

        for stat in stats {
            let value = metricValue(for: stat, metric: metric)
            countByModel[stat.modelName, default: 0] += value
            total += value
        }

        guard total > 0 else { return [] }

        let sorted = countByModel.sorted { $0.value > $1.value }
        var results: [ModelPercentage] = []
        var otherCount = 0

        for (index, entry) in sorted.enumerated() {
            if index < 10 {
                let pct = Double(entry.value) / Double(total) * 100.0
                results.append(ModelPercentage(model: entry.key, percentage: pct))
            } else {
                otherCount += entry.value
            }
        }

        if otherCount > 0 {
            let pct = Double(otherCount) / Double(total) * 100.0
            results.append(ModelPercentage(model: "Other", percentage: pct))
        }

        return results
    }

    private func computeModelUsageOverTime(metric: StatsMetric) -> [ModelTimePoint] {
        var byDate: [String: [DailyStat]] = [:]
        for stat in dailyStats {
            byDate[stat.statDate, default: []].append(stat)
        }

        // Find top 5 models overall by selected metric
        var totalByModel: [String: Int] = [:]
        for stat in dailyStats {
            totalByModel[stat.modelName, default: 0] += metricValue(for: stat, metric: metric)
        }
        let topModels = Set(totalByModel.sorted { $0.value > $1.value }.prefix(5).map(\.key))

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        var results: [ModelTimePoint] = []

        for dateStr in byDate.keys.sorted() {
            guard let stats = byDate[dateStr],
                  let date = formatter.date(from: dateStr) else { continue }

            let totalForDay = stats.reduce(0) { $0 + metricValue(for: $1, metric: metric) }
            guard totalForDay > 0 else { continue }

            var otherCount = 0
            for stat in stats {
                let value = metricValue(for: stat, metric: metric)
                if topModels.contains(stat.modelName) {
                    let pct = Double(value) / Double(totalForDay) * 100.0
                    results.append(ModelTimePoint(date: date, model: stat.modelName, percentage: pct))
                } else {
                    otherCount += value
                }
            }
            if otherCount > 0 {
                let pct = Double(otherCount) / Double(totalForDay) * 100.0
                results.append(ModelTimePoint(date: date, model: "Other", percentage: pct))
            }
        }

        return results
    }

    // MARK: - Data Loading

    private func loadData() {
        print("[Dashboard] loadData called")
        isLoading = true
        Task {
            await loadDataAsync()
        }
    }

    private func loadDataAsync() async {
        let stats = await AnalyticsService.shared.fetchDailyStats()
        await MainActor.run {
            dailyStats = stats
            isLoading = false
        }
    }
}

// MARK: - Supporting Types

private struct ModelPercentage {
    let model: String
    let percentage: Double
}

private struct ModelTimePoint: Identifiable {
    let id = UUID()
    let date: Date
    let model: String
    let percentage: Double
}
